#!/usr/bin/env python3
# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   V M S                                                                  │
# │   virtual machines · quickemu and quickget                               │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Virtual machines, one quickemu configuration each, as JSON.

    list                          every machine: running, paused, since when,
                                  its resources and its snapshots
    catalog [--refresh]           what quickget can fetch, grouped by system
    create OS RELEASE [EDITION] [--cores N] [--ram G] [--disk G]
                                  fetch and configure one; prints a progress
                                  line per step and a last line with its name
    start NAME                    boot it without a window
    open NAME                     a SPICE window on a running machine
    pause NAME | resume NAME      freeze it in place, or carry on
    stop NAME                     ask it to shut down, as a power button does
    kill NAME                     end it at once
    snapshot NAME create|apply|delete TAG
    set NAME cores|ram VALUE
    delete NAME                   the machine, its disk and its download

A machine is `NAME.conf` beside a `NAME/` directory under
$XDG_DATA_HOME/impasto/machines, as quickget writes them; the system, release
and edition it came from are added to the configuration, where quickemu
ignores them. Machines always boot headless with SPICE on, so a window can be
opened, closed and opened again without stopping one. The QEMU monitor socket
quickemu leaves in the directory answers for pausing and status.
"""

import json
import os
import re
import shutil
import signal
import socket
import subprocess
import sys
import time
from typing import NoReturn

DATA = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
CACHE = os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache")
HOME = os.path.join(DATA, "impasto", "machines")
CATALOG = os.path.join(CACHE, "impasto", "vm-catalog.json")

# How old the cached catalogue may be before it is fetched again.
CATALOG_AGE = 7 * 24 * 3600

NAME = re.compile(r"[A-Za-z0-9._-]+")
# A catalogue word: a Windows edition is a language, with spaces and brackets.
WORD = re.compile(r"[A-Za-z0-9._() -]+")
LINE = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"?(.*?)"?\s*$')
PERCENT = re.compile(r"(\d{1,3}(?:\.\d+)?)\s*%")


def say(payload):
    print(json.dumps(payload), flush=True)


def fail(message) -> NoReturn:
    say({"error": message})
    sys.exit(1)


def tools():
    return {tool: shutil.which(tool) is not None
            for tool in ("quickemu", "quickget", "spicy", "qemu-img")}


# ── ONE MACHINE ─────────────────────────────────────────────────────────────


def conf_path(name):
    if not NAME.fullmatch(name or ""):
        fail(f"not a machine name: {name!r}")
    path = os.path.join(HOME, f"{name}.conf")
    if not os.path.isfile(path):
        fail(f"no machine called {name}")
    return path


def read_conf(path):
    values = {}
    try:
        with open(path, encoding="utf-8") as source:
            for line in source:
                match = LINE.match(line)
                if match:
                    values[match.group(1)] = match.group(2)
    except OSError:
        pass
    return values


def write_conf(path, changes):
    """Set keys in a configuration, replacing a line or adding one."""
    with open(path, encoding="utf-8") as source:
        lines = source.read().splitlines()
    for key, value in changes.items():
        line = f'{key}="{value}"'
        for index, existing in enumerate(lines):
            match = LINE.match(existing)
            if match and match.group(1) == key:
                lines[index] = line
                break
        else:
            lines.append(line)
    temporary = path + ".tmp"
    with open(temporary, "w", encoding="utf-8") as target:
        target.write("\n".join(lines) + "\n")
    os.chmod(temporary, 0o744)
    os.replace(temporary, path)


def pid_of(name):
    try:
        with open(os.path.join(HOME, name, f"{name}.pid"), encoding="utf-8") as source:
            pid = int(source.read().strip())
    except (OSError, ValueError):
        return 0
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as source:
            return pid if b"qemu" in source.read() else 0
    except OSError:
        return 0


def monitor(name, command):
    """One command to the QEMU monitor, and what it printed.

    Relative to the machines directory, where `main` runs: a socket's path
    is limited to about a hundred characters, as quickemu knows.
    """
    path = os.path.join(name, f"{name}-monitor.socket")
    try:
        with socket.socket(socket.AF_UNIX) as link:
            link.settimeout(1.5)
            link.connect(path)
            buffer = b""
            while b"(qemu)" not in buffer:
                chunk = link.recv(4096)
                if not chunk:
                    return ""
                buffer += chunk
            link.sendall(command.encode() + b"\n")
            reply = b""
            try:
                while not reply.rstrip().endswith(b"(qemu)"):
                    chunk = link.recv(4096)
                    if not chunk:
                        break
                    reply += chunk
            except socket.timeout:
                pass
    except OSError:
        return ""
    return re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", reply.decode(errors="replace"))


def ports_of(name):
    ports = {}
    try:
        with open(os.path.join(HOME, name, f"{name}.ports"), encoding="utf-8") as source:
            for line in source:
                key, _, value = line.strip().partition(",")
                if value.isdigit():
                    ports[key] = int(value)
    except OSError:
        pass
    return ports


def snapshots_of(disk):
    if not disk or not os.path.isfile(disk) or not shutil.which("qemu-img"):
        return []
    try:
        result = subprocess.run(["qemu-img", "info", "-U", "--output=json", disk],
                                capture_output=True, text=True, timeout=10)
        rows = json.loads(result.stdout or "{}").get("snapshots") or []
    except (OSError, subprocess.SubprocessError, ValueError):
        return []
    return [{"tag": row.get("name", ""), "date": row.get("date-sec", 0)} for row in rows]


def used_bytes(path):
    try:
        return os.stat(path).st_blocks * 512
    except OSError:
        return 0


def describe(name):
    path = os.path.join(HOME, f"{name}.conf")
    conf = read_conf(path)
    disk = os.path.join(HOME, conf.get("disk_img", f"{name}/disk.qcow2"))
    pid = pid_of(name)
    paused = False
    if pid:
        paused = "paused" in monitor(name, "info status")
    started = 0
    if pid:
        try:
            started = int(os.stat(os.path.join(HOME, name, f"{name}.pid")).st_mtime)
        except OSError:
            started = 0
    return {
        "name": name,
        "title": conf.get("impasto_title") or name,
        "os": conf.get("impasto_os") or "",
        "release": conf.get("impasto_release") or "",
        "edition": conf.get("impasto_edition") or "",
        "guest": conf.get("guest_os", "linux"),
        "cores": conf.get("cpu_cores", ""),
        "ram": conf.get("ram", ""),
        "disk": conf.get("disk_size", ""),
        "used": used_bytes(disk),
        "running": pid != 0,
        "paused": paused,
        "started": started,
        "spice": ports_of(name).get("spice", 0) if pid else 0,
        "snapshots": snapshots_of(disk),
    }


def names():
    try:
        files = os.listdir(HOME)
    except OSError:
        return []
    return sorted(entry[:-5] for entry in files
                  if entry.endswith(".conf") and NAME.fullmatch(entry[:-5]))


# ── COMMANDS ────────────────────────────────────────────────────────────────


def cmd_list(_args):
    say({"tools": tools(), "home": HOME, "cores": os.cpu_count() or 1,
         "memory": os.sysconf("SC_PAGE_SIZE") * os.sysconf("SC_PHYS_PAGES"),
         "machines": [describe(name) for name in names()]})


def cmd_catalog(args):
    fresh = os.path.isfile(CATALOG) and time.time() - os.path.getmtime(CATALOG) < CATALOG_AGE
    if "--refresh" in args or not fresh:
        try:
            result = subprocess.run(["quickget", "--list-json"], capture_output=True,
                                    text=True, timeout=120)
            rows = json.loads(result.stdout)
        except (OSError, subprocess.SubprocessError, ValueError):
            rows = None
        if rows:
            systems = {}
            for row in rows:
                system = systems.setdefault(row.get("OS", ""), {
                    "os": row.get("OS", ""), "name": row.get("Display Name", ""),
                    "releases": {}})
                editions = system["releases"].setdefault(row.get("Release", ""), [])
                if row.get("Option"):
                    editions.append(row["Option"])
            grouped = [{"os": system["os"], "name": system["name"],
                        "releases": [{"release": release, "editions": editions}
                                     for release, editions in system["releases"].items()]}
                       for system in systems.values() if system["os"]]
            grouped.sort(key=lambda system: system["name"].lower())
            os.makedirs(os.path.dirname(CATALOG), exist_ok=True)
            with open(CATALOG + ".tmp", "w", encoding="utf-8") as target:
                json.dump(grouped, target)
            os.replace(CATALOG + ".tmp", CATALOG)
    try:
        with open(CATALOG, encoding="utf-8") as source:
            print(source.read(), flush=True)
    except OSError:
        fail("could not read the catalogue")


def option(args, flag, default):
    if flag in args:
        index = args.index(flag)
        if index + 1 < len(args):
            value = args[index + 1]
            del args[index:index + 2]
            return value
    return default


def cmd_create(args):
    cores = option(args, "--cores", "")
    ram = option(args, "--ram", "")
    disk = option(args, "--disk", "")
    title = option(args, "--title", "")
    if len(args) < 2 or not all(WORD.fullmatch(part) for part in args[:3]):
        fail("create needs a system and a release")
    system, release = args[0], args[1]
    edition = args[2] if len(args) > 2 else ""
    os.makedirs(HOME, exist_ok=True)
    # quickget names the machine; the new configuration is the one that was
    # not there before. Until it writes one there is only a directory, so a
    # fetch stopped half way is cleared by what is new of either.
    before = set(names())
    present = set(os.listdir(HOME))

    def made():
        return sorted(set(names()) - before)

    child = subprocess.Popen(["quickget", system, release] + ([edition] if edition else []),
                             cwd=HOME, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, start_new_session=True)

    def clear():
        """Take away what an unfinished fetch left behind."""
        for entry in set(os.listdir(HOME)) - present:
            path = os.path.join(HOME, entry)
            if os.path.isdir(path) and not os.path.islink(path):
                shutil.rmtree(path, ignore_errors=True)
            else:
                try:
                    os.remove(path)
                except OSError:
                    pass

    def give_up(*_):
        """Stopped half way: end quickget and clear up after it."""
        try:
            os.killpg(child.pid, signal.SIGTERM)
        except OSError:
            pass
        child.wait()
        clear()
        sys.exit(1)

    signal.signal(signal.SIGTERM, give_up)
    signal.signal(signal.SIGINT, give_up)

    last = -1.0
    tail = []
    pending = b""
    while True:
        chunk = os.read(child.stdout.fileno(), 4096) if child.stdout else b""
        if not chunk:
            break
        pending += chunk
        parts = re.split(rb"[\r\n]", pending)
        pending = parts.pop()
        for part in parts:
            text = part.decode(errors="replace").strip()
            if not text:
                continue
            tail = (tail + [text])[-6:]
            found = PERCENT.findall(text)
            if found:
                value = min(100.0, float(found[-1])) / 100
                if abs(value - last) >= 0.005:
                    last = value
                    say({"progress": round(value, 3)})
    child.wait()

    new = made()
    if child.returncode != 0 or len(new) != 1:
        clear()
        fail(tail[-1] if tail else "quickget failed")
    name = new[0]
    path = os.path.join(HOME, f"{name}.conf")
    changes = {"impasto_os": system, "impasto_release": release,
               "impasto_edition": edition, "impasto_title": title or name}
    if cores.isdigit():
        changes["cpu_cores"] = cores
    if re.fullmatch(r"\d+", ram):
        changes["ram"] = f"{ram}G"
    if re.fullmatch(r"\d+", disk):
        changes["disk_size"] = f"{disk}G"
    write_conf(path, changes)
    say({"done": name})


def quickemu(name, *extra):
    conf = os.path.basename(conf_path(name))
    try:
        return subprocess.run(["quickemu", "--vm", conf, *extra], cwd=HOME,
                              stdin=subprocess.DEVNULL, capture_output=True,
                              text=True, timeout=120)
    except (OSError, subprocess.SubprocessError) as error:
        fail(str(error))


def cmd_start(args):
    name = args[0] if args else ""
    conf_path(name)
    if pid_of(name):
        say({"running": name})
        return
    result = quickemu(name, "--display", "none")
    if not pid_of(name):
        lines = [line for line in (result.stdout + result.stderr).splitlines() if line.strip()]
        fail(lines[-1] if lines else "quickemu did not start it")
    say({"running": name})


def cmd_open(args):
    name = args[0] if args else ""
    conf_path(name)
    port = ports_of(name).get("spice", 0) if pid_of(name) else 0
    if not port:
        fail(f"{name} is not running")
    if not shutil.which("spicy"):
        fail("spicy is not installed")
    subprocess.Popen(["spicy", "--title", describe(name)["title"], "-h", "localhost", "-p", str(port)],
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)
    say({"opened": name})


def running_or_fail(name):
    conf_path(name)
    if not pid_of(name):
        fail(f"{name} is not running")


def cmd_pause(args):
    running_or_fail(args[0] if args else "")
    monitor(args[0], "stop")
    say({"paused": args[0]})


def cmd_resume(args):
    running_or_fail(args[0] if args else "")
    monitor(args[0], "cont")
    say({"running": args[0]})


def cmd_stop(args):
    running_or_fail(args[0] if args else "")
    monitor(args[0], "cont")
    monitor(args[0], "system_powerdown")
    say({"stopping": args[0]})


def cmd_kill(args):
    running_or_fail(args[0] if args else "")
    quickemu(args[0], "--kill")
    say({"stopped": args[0]})


def cmd_snapshot(args):
    if len(args) < 2:
        fail("snapshot needs a machine and create, apply or delete")
    name, verb = args[0], args[1]
    conf_path(name)
    if verb not in ("create", "apply", "delete") or len(args) < 3 or not NAME.fullmatch(args[2]):
        fail("snapshot needs create, apply or delete and a tag")
    if pid_of(name):
        fail(f"{name} must be off for a snapshot")
    result = quickemu(name, "--snapshot", verb, args[2])
    if result.returncode != 0:
        lines = (result.stderr or result.stdout).strip().splitlines()
        fail(lines[-1] if lines else "snapshot failed")
    say({"snapshot": verb, "tag": args[2]})


def cmd_set(args):
    if len(args) < 3:
        fail("set needs a machine, cores or ram, and a value")
    name, key, value = args[0], args[1], args[2]
    path = conf_path(name)
    if key == "cores" and value.isdigit() and 0 < int(value) <= (os.cpu_count() or 1):
        write_conf(path, {"cpu_cores": value})
    elif key == "ram" and value.isdigit() and int(value) > 0:
        write_conf(path, {"ram": f"{value}G"})
    else:
        fail(f"cannot set {key} to {value}")
    say({"set": key, "value": value})


def cmd_delete(args):
    name = args[0] if args else ""
    path = conf_path(name)
    if pid_of(name):
        fail(f"{name} is running")
    shutil.rmtree(os.path.join(HOME, name), ignore_errors=True)
    os.remove(path)
    say({"deleted": name})


COMMANDS = {
    "list": cmd_list, "catalog": cmd_catalog, "create": cmd_create,
    "start": cmd_start, "open": cmd_open, "pause": cmd_pause,
    "resume": cmd_resume, "stop": cmd_stop, "kill": cmd_kill,
    "snapshot": cmd_snapshot, "set": cmd_set, "delete": cmd_delete,
}


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        fail("usage: vms.py " + "|".join(COMMANDS))
    os.makedirs(HOME, exist_ok=True)
    os.chdir(HOME)
    COMMANDS[sys.argv[1]](sys.argv[2:])


if __name__ == "__main__":
    main()

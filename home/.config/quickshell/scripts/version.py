#!/usr/bin/env python3
# ╭──────────────────────────────────────────────────────────────────────────╮
# │                                                                          │
# │   V E R S I O N                                                          │
# │   the checkout this desk was installed from · what it has waiting        │
# │                                                                          │
# │   github.com/andreumassanet/impasto                                      │
# │                                                                          │
# ╰──────────────────────────────────────────────────────────────────────────╯

"""Compare the checkout this desk was installed from with its remote.

The checkout is told, never looked for: `setup sync` records its path and the
shell passes it in. `check` fetches first and `status` answers from what was
fetched before. The fetch never asks for anything — no terminal prompt, no ssh
password — so a remote needing credentials is offline rather than a wait.

Nothing is pulled and nothing is installed: the update runs in a terminal the
shell opens.
"""

import json
import os
import subprocess
import sys

# Commits carried to the panel. The count is `behind`, whole.
LISTED = 12

FETCH_TIMEOUT = 25

ENV = dict(os.environ, LANG="C", LC_ALL="C",
           GIT_TERMINAL_PROMPT="0",
           GIT_SSH_COMMAND="ssh -oBatchMode=yes",
           GIT_OPTIONAL_LOCKS="0")


def git(repo, *args, timeout=15):
    try:
        return subprocess.run(["git", "-C", repo, *args], capture_output=True,
                              text=True, timeout=timeout, env=ENV)
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"git {args[0]} failed: {error}", file=sys.stderr)
        return None


def out(result):
    return result.stdout.strip() if result is not None and result.returncode == 0 else ""


def report(repo, fetch):
    if not repo or out(git(repo, "rev-parse", "--is-inside-work-tree")) != "true":
        return {"available": False}

    branch = out(git(repo, "rev-parse", "--abbrev-ref", "HEAD"))
    # Without an upstream there is nothing to compare against, and `setup
    # update` has nothing to pull: it installs what is already here.
    upstream = out(git(repo, "rev-parse", "--abbrev-ref",
                       "--symbolic-full-name", "@{upstream}"))
    answer = {"available": True, "branch": branch, "upstream": upstream,
              "behind": 0, "ahead": 0, "target": "", "commits": [],
              "offline": False}
    if not upstream:
        return answer

    if fetch:
        result = git(repo, "fetch", "--quiet", "--tags",
                     upstream.split("/", 1)[0], timeout=FETCH_TIMEOUT)
        if result is None or result.returncode != 0:
            if result is not None:
                print(result.stderr.strip(), file=sys.stderr)
            # The counts below still answer, from the last fetch.
            answer["offline"] = True

    # What each side has that the other does not. Commits of your own are
    # what stops `pull --ff-only`, so they are reported rather than counted
    # into the total.
    counts = out(git(repo, "rev-list", "--left-right", "--count",
                     f"HEAD...{upstream}")).split()
    if len(counts) == 2 and all(count.isdigit() for count in counts):
        answer["ahead"] = int(counts[0])
        answer["behind"] = int(counts[1])
    if answer["behind"] == 0:
        return answer

    answer["commits"] = [
        {"hash": line.split("\t", 1)[0], "subject": line.split("\t", 1)[1]}
        for line in out(git(repo, "log", f"--max-count={LISTED}",
                            "--pretty=%h\t%s", f"HEAD..{upstream}")).splitlines()
        if "\t" in line]
    # What the version figure would read after the update: the remote's own
    # describe, in the shape `setup` records this one in.
    answer["target"] = out(git(repo, "describe", "--tags", "--always",
                               "--abbrev=7", upstream))
    return answer


def main():
    verb = sys.argv[1] if len(sys.argv) > 1 else "status"
    repo = sys.argv[2] if len(sys.argv) > 2 else ""
    if verb not in ("status", "check"):
        print(f"Unknown verb: {verb}", file=sys.stderr)
        print(json.dumps({"available": False}))
        return
    print(json.dumps(report(repo, verb == "check")))


if __name__ == "__main__":
    main()

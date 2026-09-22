// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S P E C T R U M                                                        │
// │   sound bars along one edge, drawn in one pass                           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

// Compiled to spectrum.frag.qsb, which is what Qt loads:
//   /usr/lib/qt6/bin/qsb --qt6 -o spectrum.frag.qsb spectrum.frag
// and then `revision` in SpectrumBars.qml goes up by one, or a running shell
// keeps drawing the old one.
//
// Each pixel finds its bar, reads that bar's band between the two nearest,
// and is inside the bar's shape as long as the level. The sixty-four bands,
// and their peaks, arrive as sixteen vec4s each.

#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;
    float side;        // 0 the bottom, 1 the left, 2 the right
    float look;        // 0 rounded, 1 square, 2 segments, 3 dots, 4 wave
    float fill;        // 0 fade, 1 solid, 2 blend
    float lows;        // 0 at the corners, 1 along the edge
    float peaksOn;
    float pitch;
    float barWidth;
    float floorLength;
    float curve;
    float base;
    float tip;
    vec4 color;
    vec4 color2;
    vec4 b0; vec4 b1; vec4 b2; vec4 b3;
    vec4 b4; vec4 b5; vec4 b6; vec4 b7;
    vec4 b8; vec4 b9; vec4 b10; vec4 b11;
    vec4 b12; vec4 b13; vec4 b14; vec4 b15;
    vec4 p0; vec4 p1; vec4 p2; vec4 p3;
    vec4 p4; vec4 p5; vec4 p6; vec4 p7;
    vec4 p8; vec4 p9; vec4 p10; vec4 p11;
    vec4 p12; vec4 p13; vec4 p14; vec4 p15;
};

float band(int index) {
    vec4 group;
    int slot = index / 4;
    if (slot == 0) group = b0; else if (slot == 1) group = b1;
    else if (slot == 2) group = b2; else if (slot == 3) group = b3;
    else if (slot == 4) group = b4; else if (slot == 5) group = b5;
    else if (slot == 6) group = b6; else if (slot == 7) group = b7;
    else if (slot == 8) group = b8; else if (slot == 9) group = b9;
    else if (slot == 10) group = b10; else if (slot == 11) group = b11;
    else if (slot == 12) group = b12; else if (slot == 13) group = b13;
    else if (slot == 14) group = b14; else group = b15;
    return group[index - slot * 4];
}

float peak(int index) {
    vec4 group;
    int slot = index / 4;
    if (slot == 0) group = p0; else if (slot == 1) group = p1;
    else if (slot == 2) group = p2; else if (slot == 3) group = p3;
    else if (slot == 4) group = p4; else if (slot == 5) group = p5;
    else if (slot == 6) group = p6; else if (slot == 7) group = p7;
    else if (slot == 8) group = p8; else if (slot == 9) group = p9;
    else if (slot == 10) group = p10; else if (slot == 11) group = p11;
    else if (slot == 12) group = p12; else if (slot == 13) group = p13;
    else if (slot == 14) group = p14; else group = p15;
    return group[index - slot * 4];
}

// 0 the lowest band, 1 the highest, read between the two nearest.
float bandAt(float position) {
    float place = clamp(position, 0.0, 1.0) * 63.0;
    int below = int(floor(place));
    int above = below < 63 ? below + 1 : 63;
    return mix(band(below), band(above), place - float(below));
}

float peakAt(float position) {
    float place = clamp(position, 0.0, 1.0) * 63.0;
    int below = int(floor(place));
    int above = below < 63 ? below + 1 : 63;
    return mix(peak(below), peak(above), place - float(below));
}

// Which band a point `middle` of the way along the edge reads. At the
// corners, the bottom is mirrored with its lows at both ends and a side has
// its lows at the bottom, where it meets the bottom's.
float positionOf(float middle, bool across) {
    if (lows > 0.5)
        return middle;
    return across ? 1.0 - abs(2.0 * middle - 1.0) : 1.0 - middle;
}

float reachOf(float level, float depth) {
    return max(floorLength, depth * pow(max(level, 0.0), curve));
}

// A box of half-size `halfSize` with corners of radius `radius`, centred on 0.
float roundBox(vec2 point, vec2 halfSize, float radius) {
    vec2 outside = abs(point) - halfSize + radius;
    return length(max(outside, 0.0)) + min(max(outside.x, outside.y), 0.0) - radius;
}

float cover(float outline) {
    return 1.0 - smoothstep(-0.5, 0.5, outline);
}

// Premultiplied colour for a point `fromEdge` in, on a bar `reach` long. A
// cap and the wave's rim are drawn at full strength whatever the fill.
vec4 paint(float fromEdge, float reach, float depth, float coverage, bool full) {
    vec4 ink = color;
    float strength = base;
    if (fill > 1.5)
        ink = mix(color, color2, clamp(fromEdge / depth, 0.0, 1.0));
    else if (fill < 0.5 && !full)
        strength = mix(base, tip, clamp(fromEdge / reach, 0.0, 1.0));
    float alpha = ink.a * coverage * strength * qt_Opacity;
    return vec4(ink.rgb * alpha, alpha);
}

vec4 over(vec4 top, vec4 under) {
    return top + under * (1.0 - top.a);
}

void main() {
    bool across = side < 0.5;
    vec2 pixel = qt_TexCoord0 * area;
    float run = across ? area.x : area.y;
    float depth = across ? area.y : area.x;
    float along = across ? pixel.x : pixel.y;
    float fromEdge = across ? area.y - pixel.y : (side < 1.5 ? pixel.x : area.x - pixel.x);

    // The wave: one filled area along the whole edge, lit along its top.
    if (look > 3.5) {
        float reach = reachOf(bandAt(positionOf(clamp(along / run, 0.0, 1.0), across)), depth);
        vec4 body = paint(fromEdge, reach, depth, cover(fromEdge - reach), false);
        vec4 rim = paint(reach, reach, depth, cover(abs(fromEdge - reach) - 1.0), true);
        fragColor = over(rim, body);
        return;
    }

    float count = floor(run / pitch);
    float lead = (run - count * pitch) * 0.5;
    float slot = floor((along - lead) / pitch);
    if (count < 1.0 || slot < 0.0 || slot >= count) {
        fragColor = vec4(0.0);
        return;
    }

    float position = positionOf((slot + 0.5) / count, across);
    float reach = reachOf(bandAt(position), depth);
    float offset = along - (lead + (slot + 0.5) * pitch);
    float halfWidth = barWidth * 0.5;

    float coverage;
    if (look < 0.5) {
        coverage = cover(roundBox(vec2(offset, fromEdge - reach * 0.5),
            vec2(halfWidth, reach * 0.5), min(halfWidth, reach * 0.5)));
    } else if (look < 1.5) {
        coverage = cover(roundBox(vec2(offset, fromEdge - reach * 0.5),
            vec2(halfWidth, reach * 0.5), 0.0));
    } else if (look < 2.5) {
        // Cells as long as the bar is wide, as many as the level reaches.
        float cell = max(barWidth, 3.0);
        float cellGap = max(2.0, pitch - barWidth);
        float cellStep = cell + cellGap;
        float lit = max(1.0, floor((reach + cellGap) / cellStep));
        float index = floor(fromEdge / cellStep);
        float within = fromEdge - index * cellStep;
        coverage = index < lit ? cover(roundBox(vec2(offset, within - cell * 0.5),
            vec2(halfWidth, cell * 0.5), min(1.5, halfWidth))) : 0.0;
    } else {
        // A disc at the level, on a faint stem down to the edge.
        float centre = max(halfWidth, reach - halfWidth);
        float disc = cover(length(vec2(offset, fromEdge - centre)) - halfWidth);
        float stem = cover(abs(offset) - max(1.0, barWidth * 0.12))
            * (1.0 - step(centre, fromEdge)) * 0.35;
        coverage = max(disc, stem);
    }
    vec4 bar = paint(fromEdge, reach, depth, coverage, false);

    // A cap just above the highest the band has been lately.
    if (peaksOn > 0.5) {
        float capHeight = max(2.0, barWidth * 0.3);
        float capCentre = max(reachOf(peakAt(position), depth), reach) + 2.0 + capHeight * 0.5;
        float cap = cover(roundBox(vec2(offset, fromEdge - capCentre),
            vec2(halfWidth, capHeight * 0.5), look < 0.5 ? capHeight * 0.5 : 0.0));
        bar = over(paint(fromEdge, reach, depth, cap, true), bar);
    }

    fragColor = bar;
}

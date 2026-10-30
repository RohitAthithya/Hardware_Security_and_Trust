#!/usr/bin/env python3
"""Export report figures for the implemented, asynchronous four-bit RO PUF.

These are logical block diagrams, not Chip Planner or routing screenshots.
Run from any directory; only diagram artifacts under implementation/ are written.
"""

import os
from pathlib import Path

os.environ.setdefault("MPLCONFIGDIR", "/tmp/project3_diagram_matplotlib")

import matplotlib

matplotlib.use("Agg")
matplotlib.rcParams.update({
    "font.family": "DejaVu Sans",
    "svg.fonttype": "none",
    "pdf.fonttype": 42,
    "savefig.facecolor": "white",
})

import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
from matplotlib.patches import Circle, FancyArrowPatch, FancyBboxPatch, PathPatch
from matplotlib.path import Path as DrawPath


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "implementation"
INK = "#273c49"
MUTED = "#607481"
BLUE = "#476d88"
GREEN = "#5a8276"
CONTROL = "#7b8791"
EDGE = "#a9bdc8"
PALE_BLUE = "#eef5fa"
PALE_GREEN = "#edf5f1"
PALE_GRAY = "#f6f8fa"
PALE_SAND = "#fbf7ed"


class Diagram:
    def __init__(self, width, height, title, subtitle):
        self.width = width
        self.height = height
        self.fig = plt.figure(figsize=(width / 100, height / 100), facecolor="white")
        self.ax = self.fig.add_axes([0, 0, 1, 1])
        self.ax.set_xlim(0, width)
        self.ax.set_ylim(height, 0)
        self.ax.axis("off")
        self.text(60, 58, title, 35, weight="bold")
        self.text(60, 98, subtitle, 22, color=MUTED)
        self.line([(60, 123), (width - 60, 123)], color=EDGE, width=1)

    def text(self, x, y, value, size=22, align="left", color=INK,
             weight="normal", background=None):
        bbox = None
        if background:
            bbox = {"facecolor": background, "edgecolor": "none", "pad": 2}
        return self.ax.text(
            x, y, value, fontsize=size * 0.72, ha=align, va="center",
            color=color, fontweight=weight, linespacing=1.35, bbox=bbox, zorder=8,
        )

    def box(self, x, y, width, height, fill="white", edge=EDGE,
            radius=12, line_width=1.3):
        patch = FancyBboxPatch(
            (x, y), width, height,
            boxstyle=f"round,pad=0,rounding_size={radius}",
            linewidth=line_width, edgecolor=edge, facecolor=fill, zorder=2,
        )
        self.ax.add_patch(patch)
        return patch

    def line(self, points, color=BLUE, width=1.8, arrow=False,
             dashed=False, halo=False, zorder=4):
        xs, ys = zip(*points)
        if halo:
            self.ax.plot(xs, ys, color="white", lw=width + 4,
                         solid_capstyle="round", zorder=zorder)
        self.ax.plot(xs, ys, color=color, lw=width,
                     linestyle=(0, (4, 3)) if dashed else "-",
                     solid_capstyle="round", zorder=zorder + 0.1)
        if arrow:
            self.ax.add_patch(FancyArrowPatch(
                points[-2], points[-1], arrowstyle="-|>", mutation_scale=12,
                color=color, lw=width, shrinkA=0, shrinkB=0,
                zorder=zorder + 0.2,
            ))

    def dot(self, x, y, color=BLUE, radius=4):
        self.ax.add_patch(Circle((x, y), radius, color=color, zorder=7))

    def bus(self, x, y, bits, below=False):
        self.line([(x - 7, y + 7), (x + 7, y - 7)], width=1.4, zorder=6)
        self.text(x, y + 21 if below else y - 19, str(bits), 17,
                  align="center", color=MUTED,
                  background="white")

    def and_gate(self, x, y):
        # Two-input AND, with a circular right edge and an 80-unit height.
        vertices = [
            (x, y), (x + 50, y), (x + 105, y), (x + 105, y + 80),
            (x + 50, y + 80), (x, y + 80), (x, y),
        ]
        codes = [DrawPath.MOVETO, DrawPath.LINETO, DrawPath.CURVE4,
                 DrawPath.CURVE4, DrawPath.CURVE4, DrawPath.LINETO,
                 DrawPath.CLOSEPOLY]
        self.ax.add_patch(PathPatch(DrawPath(vertices, codes), facecolor=PALE_GREEN,
                                   edgecolor=GREEN, linewidth=1.5, zorder=5))
        self.text(x + 43, y + 40, "AND", 21, align="center")

    def mux(self, x, y, title):
        vertices = [(x, y), (x + 160, y + 30), (x + 160, y + 150),
                    (x, y + 180), (x, y)]
        self.ax.add_patch(PathPatch(
            DrawPath(vertices, [DrawPath.MOVETO] + [DrawPath.LINETO] * 3
                     + [DrawPath.CLOSEPOLY]),
            facecolor=PALE_BLUE, edgecolor=BLUE, linewidth=1.5, zorder=5,
        ))
        self.text(x + 76, y + 72, title, 25, align="center", weight="bold")
        self.text(x + 76, y + 108, "16 : 1", 23, align="center")

    def exports(self, stem):
        OUT.mkdir(exist_ok=True)
        for suffix in ["svg", "pdf", "png"]:
            self.fig.savefig(OUT / f"{stem}.{suffix}", dpi=180)
        print(f"Created {stem}.svg, .pdf, .png")


def overview():
    d = Diagram(
        2100, 1380, "Four-bit ring oscillator PUF",
        "PUF.v  |  64 oscillators  ·  4 independent races  ·  8 shared challenge bits  ·  4 response bits",
    )
    d.box(180, 165, 1630, 1115, edge=BLUE, line_width=1.7, radius=16)
    d.text(215, 194, "PUF", 27, weight="bold")
    d.text(1735, 194, "module boundary", 18, align="right", color=MUTED)

    # Shared inputs. The reset net also drives the Enable inversion below.
    for name, y, spine, bits in [
        ("reset", 240, 1000, None),
        ("Cha0[3:0]", 290, 850, 4),
        ("Cha1[3:0]", 340, 925, 4),
    ]:
        d.text(38, y - 20, name, 24, weight="bold")
        d.line([(38, y), (spine, y), (spine, 1080)],
               color=CONTROL, dashed=True)
        if bits:
            d.bus(650, y, bits)
    d.dot(300, 240, CONTROL)
    d.line([(300, 240), (300, 350), (340, 350), (340, 360)],
           color=CONTROL, dashed=True, arrow=True, halo=True)
    d.box(280, 360, 120, 58, PALE_SAND)
    d.text(340, 389, "NOT", 23, align="center", weight="bold")
    d.line([(340, 418), (340, 1080)], color=CONTROL, dashed=True)
    d.text(340, 450, "Enable", 21, align="center", color=MUTED, background="white")
    d.text(340, 477, "= ~reset", 20, align="center", color=MUTED, background="white")

    d.text(600, 390, "OSCILLATOR BANKS", 20, align="center", color=GREEN, weight="bold")
    d.text(1270, 390, "ONE RESPONSE BIT PER GROUP", 20, align="center", color=BLUE, weight="bold")
    d.text(1655, 390, "PUF.v OUTPUT WIRING", 18, align="center", color=MUTED, weight="bold")
    d.box(1550, 420, 210, 790, PALE_GRAY)

    for i in range(4):
        y = 420 + i * 170
        first, last = 16 * i, 16 * i + 15
        d.box(430, y, 340, 150, PALE_GREEN, GREEN)
        d.text(600, y + 30, "RO_basic × 16", 26, align="center", weight="bold")
        d.text(600, y + 63, f"gen_Ro[{first}] … gen_Ro[{last}]", 19, align="center", color=MUTED)
        d.text(445, y + 100, "Enable", 20, color=GREEN)
        d.text(753, y + 125, f"RO_out[{last}:{first}]", 21, align="right", color=GREEN)
        d.dot(340, y + 100, CONTROL)
        d.line([(340, y + 100), (430, y + 100)],
               color=CONTROL, dashed=True, arrow=True)

        d.box(1080, y, 380, 150, PALE_BLUE, BLUE)
        d.text(1270, y + 27, f"Counter_group  cg{i}", 25, align="center", weight="bold")
        for spine, pin_y, pin in [
            (850, y + 50, "Cha0[3:0]"),
            (925, y + 75, "Cha1[3:0]"),
            (1000, y + 100, "reset"),
        ]:
            d.dot(spine, pin_y, CONTROL)
            d.line([(spine, pin_y), (1080, pin_y)],
                   color=CONTROL, dashed=True, arrow=True, halo=True)
            d.text(1095, pin_y, pin, 19)
        d.line([(770, y + 125), (1080, y + 125)],
               width=2.8, arrow=True, halo=True, zorder=6)
        d.bus(810, y + 125, 16)
        d.text(1095, y + 125, "RO_out[15:0]", 19)

        for pin, delta, net in [
            ("Response", 60, f"Response[{i}]"),
            ("Done", 95, f"group_done[{i}]"),
            ("Invalid", 130, f"Invalid[{i}]"),
        ]:
            d.text(1445, y + delta, pin, 20, align="right")
            d.line([(1460, y + delta), (1550, y + delta)], arrow=True)
            d.text(1564, y + delta, net, 19)

    for name, y, bits in [("Response[3:0]", 605, 4), ("Invalid[3:0]", 775, 4)]:
        d.line([(1760, y), (2055, y)], width=2.8, arrow=True)
        d.bus(1880, y, bits)
        d.text(1830, y - 41, name, 24, weight="bold")
    d.box(1575, 1110, 160, 66, "white", EDGE, radius=8)
    d.text(1655, 1130, "4-input AND", 19, align="center", weight="bold")
    d.text(1655, 1156, "group_done", 18, align="center")
    d.line([(1735, 1143), (2055, 1143)], arrow=True)
    d.text(1840, 1119, "Done", 24, weight="bold")
    d.text(1655, 1193, "Done = &group_done", 18, align="center", color=MUTED)

    d.text(215, 1241, "All 64 ROs: Enable = ~reset.  All four groups: the same Cha0, Cha1 and reset.", 22)
    d.line([(65, 1320), (135, 1320)], width=2.5)
    d.text(150, 1320, "Oscillator / data / status", 20, color=MUTED)
    d.line([(580, 1320), (650, 1320)], color=CONTROL, dashed=True)
    d.text(665, 1320, "Shared control", 20, color=MUTED)
    d.text(1010, 1320, "Dots = branches; crossings without dots are separate nets.", 20, color=MUTED)
    d.text(60, 1355, "Logical hierarchy and exact bank slices; this figure does not depict physical placement or routing.", 19, color=MUTED)
    return d


def counter_group():
    d = Diagram(
        2100, 1390, "One counter group: selection, race and response",
        "Counter_group.v  |  Repeated as cg0, cg1, cg2 and cg3  |  Two instances of ro_counter.v per group",
    )
    d.box(160, 165, 1670, 1070, edge=BLUE, line_width=1.7, radius=16)
    d.text(195, 195, "Counter_group", 27, weight="bold")
    d.text(1790, 195, "module boundary", 18, align="right", color=MUTED)

    # All module inputs and the shared asynchronous reset distribution.
    d.text(38, 217, "reset", 24, weight="bold", background="white")
    d.line([(38, 240), (930, 240), (930, 955)], color=CONTROL, dashed=True)
    d.text(650, 217, "asynchronous, active high", 20, color=MUTED)
    d.text(38, 580, "RO_out[15:0]", 24, weight="bold", background="white")
    d.line([(38, 605), (285, 605)], width=2.8)
    d.line([(285, 460), (285, 890)], width=2.8)
    d.dot(285, 605)
    d.bus(125, 605, 16, below=True)
    for y in [460, 890]:
        d.dot(285, y)
        d.line([(285, y), (400, y)], width=2.8, arrow=True)
        d.bus(345, y, 16)

    for number, top in [(0, 370), (1, 800)]:
        d.mux(400, top, f"MUX {number}")
        label_y = top - 50
        d.text(38, label_y - 25, f"Cha{number}[3:0]", 24, weight="bold", background="white")
        d.line([(38, label_y), (480, label_y), (480, top + 15)],
               color=CONTROL, dashed=True, arrow=True, halo=True)
        d.bus(165, label_y, 4, below=True)
        center_y = top + 90
        d.line([(560, center_y), (620, center_y), (620, center_y - 15),
                (710, center_y - 15)], arrow=True)
        d.text(641, center_y - 52, f"RO_out[Cha{number}]", 20, align="center", background="white")
        d.and_gate(710, center_y - 40)
        d.line([(801, center_y), (1000, center_y)], arrow=True, halo=True, zorder=6)
        d.text(857, center_y - 24, f"clk{number}", 22, weight="bold")

        counter_top = 355 + number * 430
        d.box(1000, counter_top, 340, 210, PALE_BLUE, BLUE)
        d.text(1170, counter_top + 31, "ro_counter", 27, align="center", weight="bold")
        d.text(1170, counter_top + 65, f"counter{number}  ·  W = 16", 22, align="center", color=MUTED)
        d.text(1015, center_y, "ro_clk", 21)
        # A clock triangle identifies the edge-triggered clock input.
        d.line([(1000, center_y - 9), (1011, center_y), (1000, center_y + 9)], width=1.2)
        reset_y = counter_top + 170
        d.dot(930, reset_y, CONTROL)
        d.line([(930, reset_y), (1000, reset_y)],
               color=CONTROL, dashed=True, arrow=True, halo=True)
        d.text(1015, reset_y, "reset", 20)
        d.text(1186, counter_top + 184, "Saturates at 65,535", 20, align="center")
        d.text(1325, center_y - 10, "done", 21, align="right")
        d.text(1325, center_y + 50, "count[15:0]", 20, align="right")
        d.line([(1340, center_y - 10), (1480, center_y - 10)], arrow=True)
        d.line([(1340, center_y + 50), (1480, center_y + 50)], width=2.8, arrow=True)
        d.bus(1410, center_y + 50, 16)

    # Result wiring is exactly the three continuous assignments in the RTL.
    d.box(1480, 365, 300, 700, PALE_GRAY)
    d.text(1630, 403, "Result logic", 27, align="center", weight="bold")
    for name, y in [("done0", 450), ("count0[15:0]", 510),
                    ("done1", 880), ("count1[15:0]", 940)]:
        d.text(1495, y, name, 20)
    d.text(1630, 573, "Response = done1", 23, align="center")
    d.text(1630, 701, "Done = done0 | done1", 23, align="center")
    d.text(1630, 817, "Invalid = Done &&", 23, align="center")
    d.text(1630, 852, "(count0 == count1)", 23, align="center")
    d.text(1630, 1021, "Combinational outputs", 19, align="center", color=MUTED)
    for name, y in [("Response", 573), ("Done", 701), ("Invalid", 852)]:
        d.line([(1780, y), (2055, y)], arrow=True)
        d.text(1847, y - 26, name, 25, weight="bold")

    # Cross-gated clocks. An input bubble implements ~done on each AND gate.
    # White halos make crossings separate from the explicit branch dots.
    d.line([(1390, 450), (1390, 690), (650, 690), (650, 905), (698, 905)],
           color=GREEN, dashed=True, halo=True, zorder=6)
    d.line([(1425, 880), (1425, 650), (675, 650), (675, 475), (698, 475)],
           color=GREEN, dashed=True, halo=True, zorder=6)
    d.dot(1390, 450, GREEN)
    d.dot(1425, 880, GREEN)
    for y in [475, 905]:
        d.ax.add_patch(Circle((704, y), 6, facecolor="white", edgecolor=GREEN,
                              linewidth=1.4, zorder=7))
    d.text(680, 517, "~done1", 21, color=GREEN, align="center", background="white")
    d.text(657, 948, "~done0", 21, color=GREEN, align="center", background="white")
    d.text(1050, 626, "done1 stops counter0", 22, align="center", color=GREEN,
           background="white")
    d.text(1050, 721, "done0 stops counter1", 22, align="center", color=GREEN,
           background="white")

    d.box(205, 1095, 1140, 100, PALE_SAND, edge="#d4c8ad", radius=10)
    d.text(230, 1123, "clk0 = RO_out[Cha0] & ~done1", 24)
    d.text(230, 1164, "clk1 = RO_out[Cha1] & ~done0", 24)
    d.text(1418, 1121, "Winner 0 → Response 0", 22)
    d.text(1418, 1163, "Winner 1 → Response 1", 22)
    d.text(60, 1291, "Hold challenges constant during the race. Read after Done and settling; discard the result if Invalid = 1.", 23)
    d.text(60, 1332, "A saturated counter holds 65,535 until reset. No reference clock or synchronizer is used.", 21, color=MUTED)
    d.text(60, 1365, "The equality flag identifies equal final counts; it is not a general detector of metastability or measurement noise.", 19, color=MUTED)
    return d


def main():
    OUT.mkdir(exist_ok=True)
    figures = [
        ("ro_puf_block_diagram", overview()),
        ("counter_group_block_diagram", counter_group()),
    ]
    with PdfPages(OUT / "ro_puf_design_diagrams.pdf") as document:
        for stem, diagram in figures:
            diagram.exports(stem)
            document.savefig(diagram.fig)
            plt.close(diagram.fig)
    print("Created ro_puf_design_diagrams.pdf (two vector pages)")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Draw placement evidence from the fitted-node CSV, without inventing GUI captures."""

import csv
import re
from collections import defaultdict
from html import escape
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "implementation"
COLORS = ["#dbeafe", "#dcfce7", "#fef3c7", "#fce7f3"]


def text(x, y, content, size=14, anchor="middle"):
    return (f'<text x="{x}" y="{y}" font-size="{size}" text-anchor="{anchor}" '
            f'font-family="sans-serif" fill="#0f172a">{escape(str(content))}</text>')


def svg(width, height, elements):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
            f'viewBox="0 0 {width} {height}"><rect width="100%" height="100%" fill="white"/>'
            '<defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" '
            'markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
            '<path d="M 0 0 L 10 5 L 0 10 z" fill="#334155"/></marker></defs>'
            + "".join(elements) + '</svg>\n')


def main():
    rows = list(csv.DictReader((ROOT / "quartus/output_files/ro_fitted_nodes.csv").open()))
    groups = defaultdict(list)
    for row in rows:
        row["coordinates"] = tuple(map(int, re.search(r"X(\d+)_Y(\d+)_N(\d+)", row["location"]).groups()))
        groups[int(row["ro"])].append(row)
    if set(groups) != set(range(64)) or any(len(nodes) != 10 for nodes in groups.values()):
        raise RuntimeError("Require all 640 fitted nodes")
    locations = {}
    for ro, nodes in groups.items():
        cells = {row["coordinates"][:2] for row in nodes}
        if len(cells) != 1:
            raise RuntimeError(f"RO {ro} spans more than one LAB")
        locations[ro] = cells.pop()
    if len(set(locations.values())) != 64:
        raise RuntimeError("ROs share a LAB")
    OUT.mkdir(exist_ok=True)
    xs = sorted({xy[0] for xy in locations.values()})
    ys = sorted({xy[1] for xy in locations.values()}, reverse=True)
    elements = [text(410, 30, "Fitter-verified RO placement", 22),
                text(410, 55, "64 ROs; ten gate nodes within each assigned LAB", 14)]
    for ro, (x, y) in locations.items():
        px, py = 70 + xs.index(x) * 120, 90 + ys.index(y) * 46
        elements.append(f'<rect x="{px}" y="{py}" width="110" height="39" rx="4" '
                        f'fill="{COLORS[ro // 16]}" stroke="#64748b"/>')
        elements += [text(px + 55, py + 16, f"RO {ro:02d} / group {ro // 16}", 12),
                     text(px + 55, py + 31, f"X{x} Y{y}", 11)]
    elements.append(text(410, 625, "Coordinates from ro_fitted_nodes.csv; schematic view of the occupied LABs", 12))
    (OUT / "ro_placement.svg").write_text(svg(820, 650, elements))

    elements = [text(350, 30, "RO 00: logical chain at fitted locations", 20),
                text(350, 54, "NAND + eight inverters in feedback; ninth inverter drives RO_out", 12)]
    nodes = sorted(groups[0], key=lambda row: row["coordinates"][2])
    for i, row in enumerate(nodes):
        px, py = 250, 90 + i * 64
        elements.append(f'<rect x="{px}" y="{py}" width="230" height="44" rx="5" '
                        'fill="#dbeafe" stroke="#334155"/>')
        elements += [text(365, py + 17, row["gate"]),
                     text(365, py + 34, f'{row["location"]} / fanout {row["fanout"]}', 11)]
        if i < 9:
            elements.append(f'<path d="M365 {py + 44} V{py + 64}" stroke="#334155" '
                            'fill="none" marker-end="url(#arrow)"/>')
    elements.append('<path d="M250 624 H160 V112 H250" fill="none" stroke="#334155" '
                    'stroke-width="2" marker-end="url(#arrow)"/>')
    elements += [text(115, 370, "feedback", 12), text(560, 114, "Enable", 13),
                 '<path d="M530 112 H480" fill="none" stroke="#334155" marker-end="url(#arrow)"/>',
                 '<path d="M365 710 V740" fill="none" stroke="#334155" marker-end="url(#arrow)"/>',
                 text(365, 760, "RO_out", 14),
                 text(350, 797, "Physical node positions and fanout from Quartus; logical edges follow RO_basic.v", 11)]
    (OUT / "ro00_detail.svg").write_text(svg(700, 820, elements))
    print("PASS: placement and RO detail SVGs generated from fitted nodes")


if __name__ == "__main__":
    main()

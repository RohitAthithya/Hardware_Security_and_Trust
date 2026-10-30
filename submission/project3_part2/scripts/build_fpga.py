#!/usr/bin/env python3
"""Reproduce the placed Quartus build and record simulation/timing limitations."""

import csv
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
Q = ROOT / "quartus"
OUT = Q / "output_files"


def run(args, log_name):
    log = OUT / log_name
    print("Running " + " ".join(map(str, args)), flush=True)
    with log.open("w") as stream:
        result = subprocess.run(args, cwd=Q, stdout=stream, stderr=subprocess.STDOUT, timeout=900)
    text = log.read_text(errors="replace")
    if result.returncode or re.search(r"^Error(?: \(|:)", text, re.M):
        raise RuntimeError(f"Build step failed ({result.returncode}); see {log}")
    print(f"PASS: {log_name}", flush=True)


def validate_synthesis():
    report = (OUT / "Project3.map.rpt").read_text()
    rows = re.findall(r";\s*\|RO_basic:gen_Ro\[(\d+)\]\.ro_inst\|\s*;\s*10 \(10\)", report)
    if set(map(int, rows)) != set(range(64)):
        raise RuntimeError("Synthesis did not retain ten logic cells in every RO")
    if not re.search(r"Total registers\s*;\s*136\b", report):
        raise RuntimeError("Expected eight 16-bit counters plus eight completion registers")


def validate_locations():
    expected = list(csv.DictReader((Q / "ro_placement.csv").open()))
    actual = list(csv.DictReader((OUT / "ro_fitted_nodes.csv").open()))
    actual_map = {(int(row["ro"]), row["gate"]): row for row in actual}
    if len(actual) != 640 or len(actual_map) != 640:
        raise RuntimeError("Fitted RO node count is not 640")
    for row in expected:
        fitted = actual_map[(int(row["ro"]), row["gate"])]
        coordinates = re.search(r"X(\d+)_Y(\d+)_N(\d+)", fitted["location"])
        if not coordinates:
            raise RuntimeError(f"Cannot read fitted location: {fitted}")
        x, y, n = map(int, coordinates.groups())
        # A LABCELL constraint chooses an ALM; the placed LUT can use either half.
        if (x, y, n // 6) != (int(row["x"]), int(row["y"]), int(row["n"]) // 6):
            raise RuntimeError(f"Placement mismatch: expected {row}, fitted {fitted}")
    print("PASS: all 640 gates are in their assigned ALMs across 64 LABs", flush=True)


def main():
    OUT.mkdir(exist_ok=True)
    result = {"build_passed": False, "hardware_validated": False}
    try:
        subprocess.run([sys.executable, str(ROOT / "scripts" / "generate_placement.py")], check=True)
        run(["quartus_map", "Project3", "--read_settings_files=on", "--write_settings_files=off"], "map_console.log")
        validate_synthesis()
        run(["quartus_fit", "Project3", "--read_settings_files=on", "--write_settings_files=off"], "fit_console.log")
        run(["quartus_cdb", "-t", "../scripts/check_ro_nodes.tcl"], "ro_nodes_console.log")
        validate_locations()
        run(["quartus_asm", "Project3", "--read_settings_files=on", "--write_settings_files=off"], "asm_console.log")
        run(["quartus_sta", "Project3"], "sta_console.log")
        run(["quartus_sta", "-t", "../scripts/report_timing.tcl"], "timing_details_console.log")
        result["build_passed"] = True
        result["bitstream"] = "quartus/output_files/Project3.sof"
        result["bitstream_sha256"] = hashlib.sha256((OUT / "Project3.sof").read_bytes()).hexdigest()
        report = (OUT / "Project3.sta.rpt").read_text()
        corners = {}
        for title, body in re.findall(
                r"; ((?:Slow|Fast) [^\n]*?Model (?:Setup|Hold|Minimum Pulse Width) Summary)[^\n]*\n(.*?)(?=\n\n)",
                report, re.S):
            values = re.findall(r"; ro_cg\d_\d\s*;\s*(-?[\d.]+)", body)
            if len(values) != 8:
                raise RuntimeError(f"Expected eight clock results in {title}")
            corners[title.strip()] = min(map(float, values))
        if len(corners) != 12:
            raise RuntimeError("Expected setup/hold/pulse checks at all four operating corners")
        result["corner_worst_slack_ns"] = corners
        result["setup_hold_pulse_met_at_5ns"] = all(v >= 0 for v in corners.values())
        fit_summary = (OUT / "Project3.fit.summary").read_text()
        result["fitted_alms"] = int(re.search(r"Logic utilization \(in ALMs\) : (\d+)", fit_summary).group(1))
        result["fitted_registers"] = int(re.search(r"Total registers : (\d+)", fit_summary).group(1))
    except (RuntimeError, subprocess.SubprocessError, OSError) as error:
        result["build_passed"] = False
        result["error"] = str(error)
        print(str(error), file=sys.stderr)
    sources = sorted((ROOT / "sources").glob("*.v"))
    result["source_sha256"] = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in sources}
    result["build_inputs_sha256"] = {
        str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in [Q / "Project3.qsf", Q / "Project3.sdc", Q / "ro_placement.tcl"]
    }
    verification = ROOT / "tb" / "verification_status.json"
    result["simulation_verified"] = False
    if verification.exists():
        try:
            status = json.loads(verification.read_text())
        except (OSError, json.JSONDecodeError):
            status = {}
        tested = sources + sorted((ROOT / "tb").glob("*.sv")) + sorted((ROOT / "tb").glob("*.svh"))
        result["simulation_verified"] = bool(status.get("passed")) and all(
            status.get("source_sha256", {}).get(str(path.relative_to(ROOT)))
            == hashlib.sha256(path.read_bytes()).hexdigest() for path in tested)
    (OUT / "build_status.json").write_text(json.dumps(result, indent=4) + "\n")
    sys.exit(0 if result["build_passed"] else 1)


if __name__ == "__main__":
    main()

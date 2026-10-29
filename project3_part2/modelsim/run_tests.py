#!/usr/bin/env python3
"""Run isolated Part 2 ModelSim checks; simulation RO models never enter Quartus."""

import hashlib
import json
import re
import signal
import sys
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "modelsim" / "build"
TB = ROOT / "tb"
SRC = ROOT / "sources"


def run(args, log_path):
    result = subprocess.run(args, cwd=BUILD, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=180)
    diagnostic = result.stdout
    if result.returncode < 0:
        diagnostic += f"\nProcess terminated by {signal.Signals(-result.returncode).name}\n"
    log_path.write_text(diagnostic)
    if result.returncode or re.search(r"(?:\*\* (?:Error|Fatal)|^FAIL:)", result.stdout, re.M):
        raise RuntimeError(f"Command failed ({result.returncode}); see {log_path}:\n{diagnostic[-4000:]}")
    return result.stdout


def main():
    BUILD.mkdir(parents=True, exist_ok=True)
    source = (SRC / "RO_basic.v").read_text()
    delayed, replacements = re.subn(r"assign (nand_out|not_[1-9])\s*=",
                                    r"assign #1 \1 =", source)
    if replacements != 10:
        raise RuntimeError("RO topology changed: review the gate-delay model generator")
    delayed = delayed.replace("module RO_basic (", "module RO_basic_delayed (")
    model = BUILD / "RO_basic_delayed.v"
    model.write_text("`timescale 1ns/1ps\n// GENERATED SIMULATION MODEL ONLY\n" + delayed)
    if not (BUILD / "work").exists():
        run(["vlib", "work"], BUILD / "vlib_output.txt")
    sources = [SRC / "ro_counter.v", SRC / "Counter_group.v", SRC / "PUF.v",
               SRC / "cyclone_v_top.v", TB / "RO_basic_model.sv", model]
    benches = ["tb_ro_counter", "tb_counter_group", "tb_ro_basic", "tb_puf_top"]
    run(["vlog", "-sv", "-work", "work", "-timescale", "1ns/1ps",
         f"+incdir+{TB}", *map(str, sources),
         *[str(TB / f"{name}.sv") for name in benches]], BUILD / "compile_output.txt")
    for name in benches:
        commands = "onerror {quit -code 1}; "
        commands += f"log -r /{name}/*; run -all; quit -f"
        output = run(["vsim", "-voptargs=+acc", "-batch", "-quiet",
                      "-wlf", str(TB / f"{name}.wlf"), f"work.{name}",
                      "-do", commands, "-L", "220model_ver"], TB / f"{name}_output.txt")
        summary = re.search(r"PASS: " + name + r"[^\n]*", output)
        if not summary:
            raise RuntimeError(f"No passing completion marker in {name}")
        print(summary.group(), flush=True)


if __name__ == "__main__":
    tracked = sorted(SRC.glob("*.v")) + sorted(TB.glob("*.sv")) + sorted(TB.glob("*.svh"))
    status = {
        "passed": False,
        "source_sha256": {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                          for path in tracked},
    }
    try:
        main()
        status["passed"] = True
    except (RuntimeError, subprocess.TimeoutExpired, OSError) as error:
        status["error"] = str(error)
        print(str(error), file=sys.stderr)
    (TB / "verification_status.json").write_text(json.dumps(status, indent=4) + "\n")
    sys.exit(0 if status["passed"] else 1)

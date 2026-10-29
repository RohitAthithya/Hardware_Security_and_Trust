#!/usr/bin/env python3
"""Verify d_ff, capture missing supplied-bench evidence, and collect 16 PUFs.

Run from any directory with the ModelSim executables on PATH:
    python3 project3_part1/modelsim/verify_and_collect.py

The existing RTL, testbenches, delay.py, and baseline delay parameter are read
only. Temporary builds use staged copies; persistent results are under tb/.
"""

import csv
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import random
import re
import runpy
import shutil
import subprocess
import tempfile


PART1 = Path(__file__).resolve().parents[1]
TB = PART1 / "tb"
RESULTS = TB / "crp_results"
SEED = 598
SOURCE_NAMES = (
    "arbiter_puf.v", "puf_1r_bit.v", "d_ff.v", "mux.v", "process_delay_model.v"
)
SAMPLE_FIELDS = (
    "configuration", "challenge_dec", "challenge_bin", "repeat",
    "response_bin", "response_hex", "expected_pattern", "tie_mask_hex",
    "reference_match",
)
CANONICAL_FIELDS = (
    "configuration", "challenge_dec", "challenge_bin", "response_bin",
    "response_hex", "repeat_1_bin", "repeat_2_bin", "repeat_match",
    "expected_pattern", "tie_mask_hex", "reference_match",
)


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def write_json(path, data):
    path.write_text(json.dumps(data, indent=4) + "\n")


def command(arguments, cwd, log_path):
    completed = subprocess.run(
        [str(value) for value in arguments], cwd=cwd,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, errors="replace", timeout=180, check=False,
    )
    log_path.write_text(completed.stdout)
    require(completed.returncode == 0,
            f"Command failed ({completed.returncode}); see {log_path}")
    require(not re.search(r"\*\*\s+(?:Error|Fatal|Warning):|(?:Errors|Warnings):\s*[1-9]",
                          completed.stdout), f"ModelSim diagnostic; see {log_path}")
    return completed.stdout


def compile_bench(build, sources, bench_name, output):
    build.mkdir(parents=True, exist_ok=True)
    command(["vlib", "work"], build, output / "library.log")
    command(["vlog", "-work", "work", "-timescale", "1ps/1ps",
             *sources, build / f"{bench_name}.v"], build, output / "compile.log")


def simulate(build, bench_name, log_path, wave_path):
    invocation_output = log_path.with_suffix(".invocation.log")
    command([
        "vsim", "-voptargs=+acc", "-batch", "-quiet",
        "-l", log_path, "-wlf", wave_path, f"work.{bench_name}",
        "-do", "log -r /*; run -all; quit -f", "-L", "220model_ver",
    ], build, invocation_output)
    require(log_path.is_file(), f"Missing simulation transcript: {log_path}")
    transcript = log_path.read_text(errors="replace")
    require(re.search(r"Errors:\s*0,\s*Warnings:\s*0", transcript),
            f"Missing clean simulation summary: {log_path}")
    require(not re.search(r"\bFAIL\b|\*\*\s+(?:Error|Fatal|Warning):", transcript),
            f"Failed simulation: {log_path}")
    require(wave_path.is_file() and wave_path.stat().st_size > 0,
            f"Missing waveform recording: {wave_path}")
    return transcript


def stage_bench(build, bench_name, snapshots):
    build.mkdir(parents=True, exist_ok=True)
    (build / f"{bench_name}.v").write_bytes(snapshots[f"tb/{bench_name}.v"])


def verify_register(work, sources, snapshots, summary):
    output = RESULTS / "d_ff"
    output.mkdir(exist_ok=True)
    build = work / "d_ff"
    stage_bench(build, "tb_d_ff", snapshots)
    compile_bench(build, [sources / "d_ff.v"], "tb_d_ff", output)
    transcript = simulate(build, "tb_d_ff", TB / "tb_d_ff_output.txt", TB / "tb_d_ff.wlf")
    passed = re.search(r"PASS: all (\d+) checks passed; 0 failures\.", transcript)
    require(passed is not None, "Missing d_ff passing-check summary")
    rows = re.findall(r"\bPASS d=[01] clk=[01] reset=[01] expected=[01] actual=[01]", transcript)
    require(len(rows) == int(passed.group(1)), "d_ff check count does not match summary")
    summary["d_ff"] = {"status": "PASS", "checks": len(rows),
                       "log": "../tb_d_ff_output.txt", "waveform": "../tb_d_ff.wlf"}
    print(f"d_ff: {len(rows)} checks passed", flush=True)


def capture_supplied_evidence(work, sources, snapshots, summary):
    specifications = (
        ("tb_process_delay_model", ["process_delay_model.v"]),
        ("tb_mux", ["mux.v", "process_delay_model.v"]),
    )
    for name, dependencies in specifications:
        log_path = TB / f"{name}_output.txt"
        reused = log_path.exists()
        if reused:
            transcript = log_path.read_text(errors="replace")
        else:
            output = RESULTS / name
            output.mkdir(exist_ok=True)
            build = work / name
            stage_bench(build, name, snapshots)
            compile_bench(build, [sources / item for item in dependencies], name, output)
            transcript = simulate(build, name, log_path, TB / f"{name}.wlf")
        if name == "tb_mux":
            rows = re.findall(r"TIME\s+(\d+), A:\s*([01x]), B:\s*([01x]), SEL:\s*([01x]), OUT:\s*([01x])", transcript)
            stable = [(int(time), a, b, select, out) for time, a, b, select, out in rows
                      if 2 <= int(time) <= 18 or 22 <= int(time) <= 38]
            require(len(stable) == 34 and all(select == "1" and out == a
                                            for _, a, _, select, out in stable),
                    "Supplied mux bench output disagrees with its existing stimuli")
        else:
            rows = re.findall(r"TIME\s+(\d+), IN:\s*([01x]), OUT:\s*([01x])", transcript)
            stable = [(int(time), signal_in, signal_out) for time, signal_in, signal_out in rows
                      if 20 <= int(time) <= 25 or 38 <= int(time) <= 44 or 58 <= int(time) <= 64]
            require(len(stable) == 20 and all(signal_in == signal_out and signal_out in "01"
                                            for _, signal_in, signal_out in stable),
                    "Supplied delay bench output disagrees with its settled intervals")
        summary[name] = {"status": "PASS", "evidence": "existing supplied stimuli only",
                         "reused_saved_log": reused, "transcript_rows": len(rows),
                         "settled_samples_reviewed": len(stable), "log": f"../{name}_output.txt"}
        print(f"{name}: captured/reused original stimuli; settled output verified", flush=True)


def parse_delay(text):
    values = [int(value) for value in re.findall(r"4'd(\d+)", text)]
    require(len(values) == 256 and all(0 <= value <= 15 for value in values),
            "Expected 256 legal mux-delay nibbles for (4,32)")
    packed = 0
    for value in values:
        packed = (packed << 4) | value
    return packed


def profiles_from_existing_generator(snapshots):
    namespace = runpy.run_path(str(PART1 / "modelsim" / "delay.py"))
    random.seed(SEED)
    baseline_text = snapshots["tb/delay_params.v"].decode()
    baseline = parse_delay(baseline_text)
    configurations = [{
        "id": "PUF_00", "origin": "existing tb/delay_params.v", "seed": None,
        "draw_index": None, "delay_hex": f"{baseline:0256x}", "delay_width": 1024,
    }]
    headers = [baseline_text]
    seen = {baseline}
    draw_index = 0
    while len(configurations) < 16:
        draw_index += 1
        expression = namespace["gen_delay"](256)
        parameter = "parameter [2*4*C_BITS*R_BITS-1:0] DELAY = " + expression + ";\n"
        packed = parse_delay(parameter)
        if packed in seen:
            continue
        seen.add(packed)
        configurations.append({
            "id": f"PUF_{len(configurations):02d}", "origin": "modelsim/delay.py:gen_delay",
            "seed": SEED, "draw_index": draw_index, "delay_hex": f"{packed:0256x}",
            "delay_width": 1024,
        })
        headers.append(parameter)
    return configurations, headers


def reference(profile, challenge):
    expected = tied = 0
    for bit in range(32):
        delay_slice = (profile >> (32 * bit)) & 0xffffffff
        top = bottom = 0
        for stage in range(3, -1, -1):
            stage_byte = (delay_slice >> (8 * stage)) & 255
            top_mux, bottom_mux = stage_byte & 15, stage_byte >> 4
            if (challenge >> stage) & 1:
                top, bottom = top + (top_mux & 3), bottom + (bottom_mux & 3)
            else:
                top, bottom = bottom + (top_mux >> 2), top + (bottom_mux >> 2)
        if top == bottom:
            tied |= 1 << bit
        elif top < bottom:
            expected |= 1 << bit
    pattern = "".join("T" if (tied >> bit) & 1 else str((expected >> bit) & 1)
                      for bit in range(31, -1, -1))
    return expected, tied, pattern


def parse_crps(transcript):
    records = re.findall(r"Challenge:\s*([01xXzZ]+),\s*Response:\s*([01xXzZ]+)", transcript)
    require(len(records) == 16, "Expected exactly 16 CRP records in a harvest sweep")
    require(all(re.fullmatch("[01]{4}", challenge) and re.fullmatch("[01]{32}", response)
                for challenge, response in records), "Invalid width or X/Z in a harvested CRP")
    require([int(challenge, 2) for challenge, _ in records] == list(range(16)),
            "Harvest sweep must contain challenges 0000 through 1111 exactly once")
    return {int(challenge, 2): response for challenge, response in records}


def write_csv(path, fields, rows):
    with path.open("w", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def retain_previous_puf_results(summary):
    for name, expected in (("tb_arbiter_puf", 215), ("tb_puf_1rbit_4_16", 252)):
        log = (TB / f"{name}_output.txt").read_text()
        require(f"PASS: all {expected} checks passed; 0 failures." in log,
                f"Expected retained verification evidence is absent: {name}")
        require(re.search(r"Errors:\s*0,\s*Warnings:\s*0", log),
                f"Retained verification log is not clean: {name}")
        summary[name] = {"status": "PASS", "checks": expected, "reused_saved_log": True,
                         "log": f"../{name}_output.txt"}


def collect(work, sources, snapshots, summary):
    configurations, headers = profiles_from_existing_generator(snapshots)
    manifest = {
        "schema_version": 1, "c_bits": 4, "r_bits": 32, "repetitions": 2,
        "generated_seed": SEED, "configuration_count": 16,
        "generator": "modelsim/delay.py:gen_delay (unchanged)",
        "generator_sampling": "int(random.uniform(0,15)); normally yields nibble values 0..14",
        "time_unit": "1ps/1ps", "settle_ps": 64, "reset_release_interval_ps": 10,
        "source_sha256": {name: digest(data) for name, data in snapshots.items()},
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "tie_policy": "T marks equal analytical arrival times; compare only untied reference bits; retain all actual responses",
        "configurations": configurations,
    }
    write_json(RESULTS / "configurations.json", manifest)
    pilot = PART1 / "modelsim" / "tb_harvest_crp_output.txt"
    if pilot.exists():
        shutil.copy2(pilot, RESULTS / "baseline_pilot_output.txt")
    samples = []
    canonical = []
    for configuration, header in zip(configurations, headers):
        identity = configuration["id"]
        output = RESULTS / identity
        output.mkdir(exist_ok=True)
        (output / "delay_params.v").write_text(header)
        build = work / identity
        stage_bench(build, "tb_harvest_crp", snapshots)
        (build / "delay_params.v").write_text(header)
        compile_bench(build, [sources / name for name in SOURCE_NAMES], "tb_harvest_crp", output)
        profile = int(configuration["delay_hex"], 16)
        repetitions = []
        for repeat in (1, 2):
            transcript = simulate(build, "tb_harvest_crp", output / f"run_{repeat}_output.txt",
                                  output / f"run_{repeat}.wlf")
            records = parse_crps(transcript)
            repetitions.append(records)
            for challenge, response_text in records.items():
                expected, tied, pattern = reference(profile, challenge)
                actual = int(response_text, 2)
                require(((actual ^ expected) & (0xffffffff ^ tied)) == 0,
                        f"Reference mismatch: {identity}, repeat {repeat}, challenge {challenge:04b}")
                samples.append({
                    "configuration": identity, "challenge_dec": challenge,
                    "challenge_bin": f"{challenge:04b}", "repeat": repeat,
                    "response_bin": response_text, "response_hex": f"{actual:08X}",
                    "expected_pattern": pattern, "tie_mask_hex": f"{tied:08X}",
                    "reference_match": "PASS",
                })
        require(repetitions[0] == repetitions[1], f"Repeatability failure: {identity}")
        for challenge in range(16):
            _, tied, pattern = reference(profile, challenge)
            response_text = repetitions[0][challenge]
            canonical.append({
                "configuration": identity, "challenge_dec": challenge,
                "challenge_bin": f"{challenge:04b}", "response_bin": response_text,
                "response_hex": f"{int(response_text, 2):08X}",
                "repeat_1_bin": response_text, "repeat_2_bin": repetitions[1][challenge],
                "repeat_match": "PASS", "expected_pattern": pattern,
                "tie_mask_hex": f"{tied:08X}", "reference_match": "PASS",
            })
        print(f"{identity}: 16 challenges x 2 repeats; reference and repeatability PASS", flush=True)
    require(len(samples) == 512 and len(canonical) == 256, "Unexpected CRP dataset size")
    write_csv(RESULTS / "crp_samples.csv", SAMPLE_FIELDS, samples)
    write_csv(RESULTS / "crp_canonical.csv", CANONICAL_FIELDS, canonical)
    tied_bits = sum(int(row["tie_mask_hex"], 16).bit_count() for row in canonical)
    summary["collection"] = {
        "status": "PASS", "configurations": 16, "unique_crps": 256, "samples": 512,
        "repetitions": 2, "repeat_matches": 256,
        "untied_bit_comparisons_per_sweep": 8192 - tied_bits,
        "untied_bit_comparisons_total": 2 * (8192 - tied_bits),
        "tied_bits_per_sweep": tied_bits, "reference_mismatches": 0,
        "xz_responses": 0, "simulation_errors": 0, "simulation_warnings": 0,
    }


def main():
    for executable in ("vlib", "vlog", "vsim"):
        require(shutil.which(executable), f"ModelSim executable is missing: {executable}")
    RESULTS.mkdir(parents=True, exist_ok=True)
    paths = [PART1 / "src" / name for name in SOURCE_NAMES]
    paths += [TB / f"{name}.v" for name in (
        "tb_d_ff", "tb_mux", "tb_process_delay_model", "tb_harvest_crp"
    )]
    paths += [TB / "delay_params.v", PART1 / "modelsim" / "delay.py"]
    snapshots = {str(path.relative_to(PART1)): path.read_bytes() for path in paths}
    summary = {"status": "RUNNING", "indentation": "four spaces in new/edited source files"}
    summary_path = RESULTS / "verification_summary.json"
    write_json(summary_path, summary)
    try:
        retain_previous_puf_results(summary)
        with tempfile.TemporaryDirectory(prefix="project3_verification_") as temporary:
            work = Path(temporary)
            sources = work / "src"
            sources.mkdir()
            for name in SOURCE_NAMES:
                (sources / name).write_bytes(snapshots[f"src/{name}"])
            verify_register(work, sources, snapshots, summary)
            capture_supplied_evidence(work, sources, snapshots, summary)
            collect(work, sources, snapshots, summary)
        for relative, original in snapshots.items():
            require((PART1 / relative).read_bytes() == original,
                    f"Source changed during collection: {relative}")
        summary["status"] = "PASS"
        write_json(summary_path, summary)
        print("PASS: register verification and complete 16-configuration collection", flush=True)
        print(summary_path, flush=True)
    except Exception as error:
        summary["status"] = "FAIL"
        summary["failure"] = str(error)
        write_json(summary_path, summary)
        raise


if __name__ == "__main__":
    main()

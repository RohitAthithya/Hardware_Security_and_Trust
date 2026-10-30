#!/usr/bin/env python3
"""Analyze measured four-bit hardware CRPs; never generate substitute measurements."""

import argparse
import csv
import itertools
import json
import re
from collections import defaultdict
from pathlib import Path


def analyze(path):
    devices = defaultdict(lambda: defaultdict(list))
    excluded = defaultdict(int)
    seen = set()
    unmeasured = 0
    with path.open(newline="") as stream:
        for line, row in enumerate(csv.DictReader(stream), 2):
            response = row["response_bin"].strip()
            invalid = row["invalid_bin"].strip()
            done = row["done"].strip()
            if not (response or invalid or done):
                unmeasured += 1
                continue
            device = row["device_id"].strip()
            challenges = tuple(row[key].strip() for key in ("cha0_bin", "cha1_bin"))
            repeat = int(row["repeat"])
            if not device or repeat < 1 or not all(re.fullmatch("[01]{4}", c) for c in challenges):
                raise ValueError(f"Line {line}: device, challenge, or repeat is invalid")
            key = (device, *challenges, repeat)
            if key in seen:
                raise ValueError(f"Line {line}: duplicate measurement identity {key}")
            seen.add(key)
            if done not in {"0", "1"}:
                raise ValueError(f"Line {line}: done must be 0 or 1")
            if done == "0":
                excluded[device] += 1
                continue
            if not all(re.fullmatch("[01]{4}", value) for value in (response, invalid)):
                raise ValueError(f"Line {line}: completed response/invalid fields need four binary bits")
            if invalid != "0000":
                excluded[device] += 1
                continue
            devices[device][challenges].append((repeat, int(response, 2)))
    summaries = []
    for device in sorted(set(devices) | set(excluded)):
        groups = devices[device]
        canonical = [sorted(samples)[0][1] for _, samples in sorted(groups.items())]
        variation = [(a ^ b).bit_count() for a, b in itertools.combinations(canonical, 2)]
        repeats = [(a[1] ^ b[1]).bit_count() for samples in groups.values()
                   for a, b in itertools.combinations(sorted(samples), 2)]
        mean = lambda values: sum(values) / len(values) if values else None
        variation_mean, repeat_mean = mean(variation), mean(repeats)
        summaries.append({
            "device_id": device,
            "valid_challenges": len(groups),
            "valid_measurements": sum(map(len, groups.values())),
            "excluded_attempts": excluded[device],
            "variation_comparisons": len(variation),
            "variation_mean_bits": variation_mean,
            "variation_percent": None if variation_mean is None else variation_mean * 25,
            "repeatability_comparisons": len(repeats),
            "repeatability_mean_bits": repeat_mean,
            "repeatability_percent": None if repeat_mean is None else repeat_mean * 25,
            "has_16_valid_crps": len(groups) >= 16,
            "has_16_repeated_crps": sum(len(samples) >= 2 for samples in groups.values()) >= 16,
        })
    return {"response_width": 4, "unmeasured_template_rows": unmeasured,
            "canonical_rule": "earliest valid repeat per device/challenge",
            "variation_benchmark_percent": 50, "repeatability_ideal_percent": 0,
            "devices": summaries}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = analyze(args.csv)
    text = json.dumps(result, indent=4) + "\n"
    if args.output:
        args.output.write_text(text)
    print(text, end="")


if __name__ == "__main__":
    main()

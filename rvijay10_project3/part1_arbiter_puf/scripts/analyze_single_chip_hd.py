#!/usr/bin/env python3
"""Compute single-chip HD using the existing Task 3 responses, without simulation.

Different-challenge variation uses all 120 unordered challenge pairs per PUF.
Same-challenge repeatability compares the two recorded runs separately.
Every comparison includes all 32 actual response bits, including tied bits.

Run from any directory:
    python3 project3_part1/modelsim/analyze_single_chip_hd.py
"""

import csv
import hashlib
from itertools import combinations
from pathlib import Path
import re
from statistics import mean


PART1 = Path(__file__).resolve().parents[1]
INPUT = PART1 / "tb" / "crp_results"
OUTPUT = PART1 / "tb" / "task4_results"
SUMMARY_FIELDS = (
    "configuration", "challenge_pairs", "mean_hd_bits", "mean_hd_pct",
    "min_hd_bits", "max_hd_bits", "repeat_comparisons",
    "repeat_mean_hd_bits", "repeat_mean_hd_pct",
)
DETAIL_FIELDS = (
    "configuration", "metric", "challenge_a", "challenge_b", "run_a", "run_b",
    "response_a_bin", "response_b_bin", "hd_bits", "hd_pct",
)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def hd(a, b):
    return (a ^ b).bit_count()


def load_csv(path):
    with path.open(newline="") as source:
        return list(csv.DictReader(source))


def write_csv(path, fields, rows):
    with path.open("w", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def comparison(configuration, metric, a, b, run_a, run_b, response_a, response_b):
    distance = hd(int(response_a, 2), int(response_b, 2))
    # Independently check XOR/popcount using the original bit strings.
    require(distance == sum(left != right for left, right in zip(response_a, response_b)),
            "Bit-string and XOR distances disagree")
    return {
        "configuration": configuration, "metric": metric,
        "challenge_a": f"{a:04b}", "challenge_b": f"{b:04b}",
        "run_a": run_a, "run_b": run_b,
        "response_a_bin": response_a, "response_b_bin": response_b,
        "hd_bits": distance, "hd_pct": distance / 32 * 100,
    }


def main():
    require(hd(0, 0) == 0 and hd(0, 0xffffffff) == 32 and hd(0, 1) == 1,
            "Known-distance checks failed")
    paths = [INPUT / "crp_canonical.csv", INPUT / "crp_samples.csv"]
    original_hashes = {path: hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}
    canonical = load_csv(paths[0])
    samples = load_csv(paths[1])
    require(len(canonical) == 256 and len(samples) == 512, "Unexpected dataset size")
    identities = [f"PUF_{index:02d}" for index in range(16)]
    require({row["configuration"] for row in canonical} == set(identities),
            "Expected exactly PUF_00 through PUF_15")
    by_key = {}
    for row in samples:
        key = (row["configuration"], int(row["challenge_bin"], 2), int(row["repeat"]))
        require(key not in by_key, f"Duplicate measurement: {key}")
        require(re.fullmatch("[01]{4}", row["challenge_bin"]) is not None and
                re.fullmatch("[01]{32}", row["response_bin"]) is not None,
                f"Invalid binary width or X/Z: {key}")
        require(int(row["response_bin"], 2) == int(row["response_hex"], 16),
                f"Hex and binary responses disagree: {key}")
        by_key[key] = row["response_bin"]
    summaries = []
    details = []
    for identity in identities:
        rows = [row for row in canonical if row["configuration"] == identity]
        require(len(rows) == 16 and {int(row["challenge_bin"], 2) for row in rows} == set(range(16)),
                f"Incomplete challenge set: {identity}")
        responses = {}
        for row in rows:
            challenge = int(row["challenge_bin"], 2)
            require(row["response_bin"] == row["repeat_1_bin"] == by_key[(identity, challenge, 1)],
                    f"Canonical response does not match the recorded first run: {identity}")
            require(row["repeat_2_bin"] == by_key[(identity, challenge, 2)],
                    f"Second-run data disagree: {identity}")
            responses[challenge] = row["response_bin"]
        variation = [comparison(identity, "different_challenges", a, b, 1, 1,
                                responses[a], responses[b])
                     for a, b in combinations(range(16), 2)]
        repeats = [comparison(identity, "same_challenge_repeats", challenge, challenge, 1, 2,
                              by_key[(identity, challenge, 1)], by_key[(identity, challenge, 2)])
                   for challenge in range(16)]
        require(len(variation) == 120 and len(repeats) == 16, "Unexpected comparison count")
        variation_mean = mean(row["hd_bits"] for row in variation)
        repeat_mean = mean(row["hd_bits"] for row in repeats)
        summaries.append({
            "configuration": identity, "challenge_pairs": 120,
            "mean_hd_bits": variation_mean, "mean_hd_pct": variation_mean / 32 * 100,
            "min_hd_bits": min(row["hd_bits"] for row in variation),
            "max_hd_bits": max(row["hd_bits"] for row in variation),
            "repeat_comparisons": 16, "repeat_mean_hd_bits": repeat_mean,
            "repeat_mean_hd_pct": repeat_mean / 32 * 100,
        })
        details.extend(variation)
        details.extend(repeats)
    require(len(details) == 2176, "Expected 1,920 variation and 256 repeatability comparisons")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    write_csv(OUTPUT / "single_chip_hd.csv", SUMMARY_FIELDS, summaries)
    write_csv(OUTPUT / "single_chip_hd_comparisons.csv", DETAIL_FIELDS, details)
    (OUTPUT / "single_chip_hd_notes.txt").write_text(
        "Single-chip HD from the existing 16 PUF configurations, using all 32 response bits.\n"
        "Different-challenge variation: all C(16,2)=120 unordered pairs per PUF.\n"
        "Mean HD in bits = sum(popcount(response_a XOR response_b)) / 120.\n"
        "Normalized mean HD (%) = mean HD in bits / 32 * 100.\n"
        "The independent, unbiased-response benchmark is approximately 16 bits (50%).\n"
        "Same-challenge repeatability: run 1 versus run 2, averaged over 16 challenges per PUF.\n"
        "Its ideal HD is 0 bits (0%); measurements here use fixed RTL simulation conditions.\n"
        "Tied bits are retained. Tie sensitivity, multi-chip HD, and other Task 4 analyses are deferred.\n"
        "Reproduce: python3 project3_part1/modelsim/analyze_single_chip_hd.py\n"
    )
    for path, original_hash in original_hashes.items():
        require(hashlib.sha256(path.read_bytes()).hexdigest() == original_hash,
                f"Input changed during analysis: {path}")
    print("PUF       Mean HD (bits)   Mean HD (%)   Min   Max   Repeat HD (%)")
    for row in summaries:
        print(f"{row['configuration']}    {row['mean_hd_bits']:10.6f}    "
              f"{row['mean_hd_pct']:10.6f}   {row['min_hd_bits']:3d}   "
              f"{row['max_hd_bits']:3d}   {row['repeat_mean_hd_pct']:10.6f}")
    print("Validated: 1,920 challenge-pair comparisons and 256 repeat comparisons; input data unchanged.")
    print(OUTPUT / "single_chip_hd.csv")


if __name__ == "__main__":
    main()

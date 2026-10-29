#!/usr/bin/env python3
"""Compute multi-chip HD from Task 3: different PUFs, identical challenges.

Run from any directory:
    python3 project3_part1/modelsim/analyze_multi_chip_hd.py

All 32 actual response bits are retained. No simulations or input edits occur.
"""

import hashlib
from itertools import combinations
from math import isclose
from pathlib import Path
import re
from statistics import mean

from analyze_single_chip_hd import hd, load_csv, require, write_csv


PART1 = Path(__file__).resolve().parents[1]
INPUT = PART1 / "tb" / "crp_results" / "crp_canonical.csv"
OUTPUT = PART1 / "tb" / "task4_results"
SUMMARY_FIELDS = (
    "challenge_bin", "device_pairs", "mean_hd_bits", "mean_hd_pct",
    "min_hd_bits", "max_hd_bits",
)
PAIR_FIELDS = (
    "device_a", "device_b", "challenges", "mean_hd_bits", "mean_hd_pct",
    "min_hd_bits", "max_hd_bits", "signature_hd_bits", "signature_bits",
)
DETAIL_FIELDS = (
    "device_a", "device_b", "challenge_bin", "response_a_bin",
    "response_b_bin", "hd_bits", "hd_pct",
)


def summarize(challenge, rows):
    average = mean(row["hd_bits"] for row in rows)
    return {
        "challenge_bin": challenge, "device_pairs": len(rows),
        "mean_hd_bits": average, "mean_hd_pct": average / 32 * 100,
        "min_hd_bits": min(row["hd_bits"] for row in rows),
        "max_hd_bits": max(row["hd_bits"] for row in rows),
    }


def main():
    original_hash = hashlib.sha256(INPUT.read_bytes()).hexdigest()
    rows = load_csv(INPUT)
    identities = [f"PUF_{index:02d}" for index in range(16)]
    expected_keys = {(identity, challenge) for identity in identities for challenge in range(16)}
    responses = {}
    for row in rows:
        require(re.fullmatch("[01]{4}", row["challenge_bin"]) is not None,
                "Invalid challenge width")
        require(re.fullmatch("[01]{32}", row["response_bin"]) is not None,
                "Invalid response width or X/Z")
        key = row["configuration"], int(row["challenge_bin"], 2)
        require(key not in responses, f"Duplicate CRP: {key}")
        require(int(row["response_bin"], 2) == int(row["response_hex"], 16),
                f"Binary/hex mismatch: {key}")
        responses[key] = row["response_bin"]
    require(set(responses) == expected_keys, "Expected the complete 16-by-16 CRP dataset")
    require(hd(0, 0) == 0 and hd(0, 0xffffffff) == 32 and hd(0, 1) == 1,
            "Known HD checks failed")
    details = []
    pairs = []
    matrix = {identity: {other: 0.0 for other in identities} for identity in identities}
    for a, b in combinations(identities, 2):
        compared = []
        for challenge in range(16):
            response_a = responses[a, challenge]
            response_b = responses[b, challenge]
            distance = hd(int(response_a, 2), int(response_b, 2))
            require(distance == sum(left != right for left, right in zip(response_a, response_b)),
                    "XOR and bit-string comparisons disagree")
            require(0 <= distance <= 32, "HD outside 0..32")
            compared.append({
                "device_a": a, "device_b": b, "challenge_bin": f"{challenge:04b}",
                "response_a_bin": response_a, "response_b_bin": response_b,
                "hd_bits": distance, "hd_pct": distance / 32 * 100,
            })
        average = mean(row["hd_bits"] for row in compared)
        signature_a = int("".join(responses[a, challenge] for challenge in range(16)), 2)
        signature_b = int("".join(responses[b, challenge] for challenge in range(16)), 2)
        signature_distance = hd(signature_a, signature_b)
        require(signature_distance == sum(row["hd_bits"] for row in compared),
                "Concatenated-signature HD disagrees with matched-challenge distances")
        pairs.append({
            "device_a": a, "device_b": b, "challenges": 16,
            "mean_hd_bits": average, "mean_hd_pct": average / 32 * 100,
            "min_hd_bits": min(row["hd_bits"] for row in compared),
            "max_hd_bits": max(row["hd_bits"] for row in compared),
            "signature_hd_bits": signature_distance, "signature_bits": 512,
        })
        matrix[a][b] = matrix[b][a] = average / 32 * 100
        details.extend(compared)
    require(len(pairs) == 120 and len(details) == 1920, "Unexpected pair-comparison counts")
    summaries = []
    for challenge in range(16):
        compared = [row for row in details if row["challenge_bin"] == f"{challenge:04b}"]
        require(len(compared) == 120, "Each challenge must have all 120 device pairs")
        row = summarize(f"{challenge:04b}", compared)
        # Independent aggregate: a bit with w ones contributes w*(16-w) differences.
        values = [int(responses[identity, challenge], 2) for identity in identities]
        population_sum = 0
        for bit in range(32):
            ones = sum((value >> bit) & 1 for value in values)
            population_sum += ones * (16 - ones)
        require(isclose(population_sum / 120, row["mean_hd_bits"], abs_tol=1e-12),
                "Per-bit population calculation disagrees with pairwise mean")
        summaries.append(row)
    overall = summarize("ALL", details)
    require(isclose(overall["mean_hd_pct"], mean(row["mean_hd_pct"] for row in pairs), abs_tol=1e-12),
            "Overall device-pair and challenge means disagree")
    summaries.append(overall)
    for a in identities:
        require(matrix[a][a] == 0, "Matrix diagonal must be zero")
        for b in identities:
            require(matrix[a][b] == matrix[b][a], "Matrix must be symmetric")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    write_csv(OUTPUT / "multi_chip_hd.csv", SUMMARY_FIELDS, summaries)
    write_csv(OUTPUT / "multi_chip_device_pairs.csv", PAIR_FIELDS, pairs)
    write_csv(OUTPUT / "multi_chip_hd_comparisons.csv", DETAIL_FIELDS, details)
    write_csv(OUTPUT / "multi_chip_hd_matrix.csv", ("configuration", *identities), [
        {"configuration": identity, **matrix[identity]} for identity in identities
    ])
    (OUTPUT / "multi_chip_hd_notes.txt").write_text(
        "Multi-chip HD compares different PUF configurations under the SAME challenge.\n"
        "There are C(16,2)=120 unordered device pairs and 16 challenges: 1,920 comparisons.\n"
        "Each distance is popcount(response_a XOR response_b), using all 32 actual bits.\n"
        "The overall mean averages all 1,920 distances; normalized HD (%) = mean / 32 * 100.\n"
        "Each device-pair mean averages its 16 matched-challenge distances.\n"
        "The matrix contains these pair means in percent, with a zero diagonal.\n"
        "All tied bits are retained; no CRPs were filtered.\n"
        "The independent unbiased-device benchmark is 16 bits (50%).\n"
        f"Measured overall mean: {overall['mean_hd_bits']:.10f} bits; {overall['mean_hd_pct']:.10f}%.\n"
        "These are simulated process-delay configurations, not physical chip measurements.\n"
        "Reproduce: python3 project3_part1/modelsim/analyze_multi_chip_hd.py\n"
    )
    require(hashlib.sha256(INPUT.read_bytes()).hexdigest() == original_hash, "Input data changed")
    print("Challenge  Mean HD (bits)   Mean HD (%)   Min  Max")
    for row in summaries:
        print(f"{row['challenge_bin']:>7}     {row['mean_hd_bits']:10.6f}     "
              f"{row['mean_hd_pct']:10.6f}  {row['min_hd_bits']:4d} {row['max_hd_bits']:4d}")
    print("Validated: 120 device pairs, 1,920 comparisons, independent mean checks, symmetric matrix; input unchanged.")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
make_samplesheet.py — generate a UltraQC samplesheet from a folder of FASTQs.

Usage:
    python scripts/make_samplesheet.py data/
    python scripts/make_samplesheet.py data/ --output my_samples.csv

Detects paired-end files by common naming conventions:
    sample_R1.fastq.gz / sample_R2.fastq.gz
    sample_R1_001.fastq.gz / sample_R2_001.fastq.gz   (Illumina bcl2fastq)
    sample_1.fastq.gz / sample_2.fastq.gz
    sample.R1.fastq.gz / sample.R2.fastq.gz

Single-end files (no matching R2) are included with an empty fastq_2 column.
"""

import argparse
import csv
import re
import sys
from pathlib import Path

# Each entry: (r1_regex, r2_replacement_on_full_name)
# The regex captures the full filename as R1; replacement produces the R2 name.
R1_PATTERNS = [
    (r"^(.+?)(_R1)(_001)?(\.fastq\.gz|\.fq\.gz)$",  lambda m: m.group(1) + "_R2" + (m.group(3) or "") + m.group(4)),
    (r"^(.+?)(_1)(\.fastq\.gz|\.fq\.gz)$",           lambda m: m.group(1) + "_2" + m.group(3)),
    (r"^(.+?)(\.R1)(\.fastq\.gz|\.fq\.gz)$",         lambda m: m.group(1) + ".R2" + m.group(3)),
]


def parse_samples(folder: Path) -> list[dict]:
    all_files = {p.name: p for p in folder.rglob("*.fastq.gz")}
    all_files.update({p.name: p for p in folder.rglob("*.fq.gz")})

    used = set()
    samples = []

    for name, path in sorted(all_files.items()):
        if name in used:
            continue

        matched = False
        for pattern, r2_builder in R1_PATTERNS:
            m = re.match(pattern, name, re.IGNORECASE)
            if m:
                sample_id = m.group(1)
                r2_name   = r2_builder(m)
                r2_path   = all_files.get(r2_name)

                samples.append({
                    "sample":  sample_id,
                    "fastq_1": str(path),
                    "fastq_2": str(r2_path) if r2_path else "",
                })
                used.add(name)
                if r2_path:
                    used.add(r2_name)
                matched = True
                break

        # Not an R1 and not already consumed as R2 — treat as single-end
        if not matched and name not in used:
            stem = re.sub(r"\.(fastq|fq)(\.gz)?$", "", name, flags=re.IGNORECASE)
            samples.append({
                "sample":  stem,
                "fastq_1": str(path),
                "fastq_2": "",
            })
            used.add(name)

    return samples


def main():
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("folder", help="Folder containing FASTQ files")
    parser.add_argument("--output", "-o", default="samplesheet.csv",
                        help="Output CSV path (default: samplesheet.csv)")
    args = parser.parse_args()

    folder = Path(args.folder)
    if not folder.is_dir():
        sys.exit(f"Error: '{folder}' is not a directory")

    samples = parse_samples(folder)
    if not samples:
        sys.exit(f"Error: no FASTQ files found in '{folder}'")

    with open(args.output, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f, fieldnames=["sample", "fastq_1", "fastq_2"]
        )
        writer.writeheader()
        writer.writerows(samples)

    pe = sum(1 for s in samples if s["fastq_2"])
    se = len(samples) - pe
    print(f"✓ Found {len(samples)} samples ({pe} paired-end, {se} single-end)")
    print(f"✓ Samplesheet written to: {args.output}")


if __name__ == "__main__":
    main()

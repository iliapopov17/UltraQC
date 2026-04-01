# UltraQC

A reproducible NGS read quality control pipeline built with [Nextflow](https://www.nextflow.io/) DSL2 and Docker.

Runs **FastQC** and **MultiQC** on single-end or paired-end FASTQ files, with optional adapter trimming via **fastp**.
Produces aggregated and per-sample QC reports for easy before/after comparison.

---

## Requirements

| Tool | Install |
| ---- | ------- |
| Java ≥ 11 | `brew install openjdk@21` |
| Nextflow | `brew install nextflow` |
| Docker Desktop | [Download](https://www.docker.com/products/docker-desktop/) |

> All QC tools (FastQC, fastp, MultiQC) run inside Docker automatically — nothing else to install.

---

## Quick Start

### 1. Prepare a samplesheet

Download the helper script and point it at your data folder:

```bash
curl -O https://raw.githubusercontent.com/iliapopov17/UltraQC/main/scripts/make_samplesheet.py
python make_samplesheet.py /path/to/your/data/ --output samplesheet.csv
```

It auto-detects paired-end (`_R1`/`_R2`, `_1`/`_2`, `.R1`/`.R2`) and single-end files:

```text
✓ Found 24 samples (24 paired-end, 0 single-end)
✓ Samplesheet written to: samplesheet.csv
```

### 2. Run

```bash
# QC only (raw reads)
nextflow run iliapopov17/UltraQC -profile docker \
  --input samplesheet.csv \
  --outdir results

# QC + trimming + QC again — see before/after in separate reports
nextflow run iliapopov17/UltraQC -profile docker \
  --input samplesheet.csv \
  --outdir results \
  --use_fastp true
```

Nextflow pulls the pipeline and all Docker images automatically on first run.

### 3. Open the reports

```bash
open results/multiqc/raw/multiqc_report.html
open results/multiqc/trimmed/multiqc_report.html   # if --use_fastp true
```

---

## Pipeline Overview

```text
                ┌─────────────┐
                │ Samplesheet │  (CSV: sample, fastq_1, fastq_2)
                └──────┬──────┘
                       │
                       ▼
                 ┌──────────┐
                 │ FastQC   │  raw reads
                 └──────┬───┘
                        │
          ┌─────────────┴──────────────┐
          │ --use_fastp false          │ --use_fastp true
          │                            ▼
          │                       ┌─────────┐
          │                       │  fastp  │  trim adapters + low quality
          │                       └────┬────┘
          │                            ▼
          │                       ┌──────────┐
          │                       │ FastQC   │  trimmed reads
          │                       └────┬─────┘
          │                            │
          └─────────────┬──────────────┘
                        ▼
              ┌──────────────────┐
              │     MultiQC      │  aggregated — all samples
              │     MultiQC      │  per-sample — one report each
              └──────────────────┘
```

---

## Parameters

| Parameter     | Default   | Description                        |
|---------------|-----------|------------------------------------|
| `--input`     | required  | Path to samplesheet CSV            |
| `--outdir`    | `results` | Output directory                   |
| `--use_fastp` | `false`   | Enable fastp trimming              |
| `--threads`   | `2`       | CPU threads per process            |

---

## Output Structure

```text
results/
├── fastqc/
│   ├── raw/              # FastQC HTML + ZIP — raw reads
│   └── trimmed/          # FastQC HTML + ZIP — trimmed reads (--use_fastp true)
├── fastp/                # fastp HTML + JSON reports (--use_fastp true)
└── multiqc/
    ├── raw/              # Aggregated MultiQC — all samples, raw
    ├── trimmed/          # Aggregated MultiQC — all samples, trimmed (--use_fastp true)
    └── per_sample/
        └── <sample_id>/
            ├── raw/
            └── trimmed/
```

---

## Resume a Run

```bash
nextflow run iliapopov17/UltraQC -profile docker \
  --input samplesheet.csv \
  --outdir results \
  --use_fastp true \
  -resume
```

Nextflow caches every completed process — only changed steps re-run.

---

## Update the Pipeline

```bash
nextflow pull iliapopov17/UltraQC
```

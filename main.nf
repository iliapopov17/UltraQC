#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

include { INPUT_CHECK                    } from './subworkflows/local/input_check'
include { FASTP                          } from './modules/local/fastp'
include { FASTQC as FASTQC_RAW           } from './modules/local/fastqc'
include { FASTQC as FASTQC_TRIM          } from './modules/local/fastqc'
include { MULTIQC as MULTIQC_RAW         } from './modules/local/multiqc'
include { MULTIQC as MULTIQC_TRIM        } from './modules/local/multiqc'
include { MULTIQC as MULTIQC_SAMPLE_RAW  } from './modules/local/multiqc'
include { MULTIQC as MULTIQC_SAMPLE_TRIM } from './modules/local/multiqc'

log.info """\
    U L T R A Q C
    =============
    input    : ${params.input}
    outdir   : ${params.outdir}
    use_fastp: ${params.use_fastp}
    """.stripIndent()

workflow ULTRAQC {
    INPUT_CHECK(params.input)
    reads_ch = INPUT_CHECK.out.reads

    // Always run FastQC on raw reads
    FASTQC_RAW('raw', reads_ch)

    // Per-sample raw MultiQC: split tuple channel into two parallel channels
    FASTQC_RAW.out.zip
        .map { meta, zips ->
            def z = zips instanceof List ? zips : [zips]
            tuple("per_sample/${meta.id}/raw", z)
        }
        .multiMap { name, zips -> names: name; reports: zips }
        .set { per_sample_raw }
    MULTIQC_SAMPLE_RAW(per_sample_raw.names, per_sample_raw.reports)

    if (params.use_fastp) {
        FASTP(reads_ch)
        FASTQC_TRIM('trimmed', FASTP.out.reads)

        // Aggregated reports
        MULTIQC_RAW(
            'raw',
            FASTQC_RAW.out.zip.map { meta, zip -> zip }.collect()
        )
        MULTIQC_TRIM(
            'trimmed',
            FASTQC_TRIM.out.zip.map { meta, zip -> zip }
                .mix(FASTP.out.json.map { meta, json -> json })
                .collect()
        )

        // Per-sample trimmed: join FastQC trim ZIPs with fastp JSON by sample
        FASTQC_TRIM.out.zip
            .join(FASTP.out.json)
            .map { meta, zips, json ->
                def z = zips instanceof List ? zips : [zips]
                tuple("per_sample/${meta.id}/trimmed", z + [json])
            }
            .multiMap { name, files -> names: name; reports: files }
            .set { per_sample_trim }
        MULTIQC_SAMPLE_TRIM(per_sample_trim.names, per_sample_trim.reports)

    } else {
        MULTIQC_RAW(
            'raw',
            FASTQC_RAW.out.zip.map { meta, zip -> zip }.collect()
        )
    }
}

workflow {
    ULTRAQC()
}

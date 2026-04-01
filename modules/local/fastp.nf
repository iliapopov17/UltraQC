process FASTP {
    tag "${meta.id}"
    label 'process_low'

    container 'quay.io/biocontainers/fastp:0.23.4--hadf994f_2'

    publishDir "${params.outdir}/fastp", mode: 'copy'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("${meta.id}.trimmed*.fastq.gz"), emit: reads
    tuple val(meta), path("${meta.id}.fastp.html"),        emit: html
    tuple val(meta), path("${meta.id}.fastp.json"),        emit: json

    script:
    def (r1, r2) = meta.single_end ? [ reads, null ] : reads
    def input_args  = meta.single_end ? "--in1 ${r1}" : "--in1 ${r1} --in2 ${r2}"
    def output_args = meta.single_end
        ? "--out1 ${meta.id}.trimmed.fastq.gz"
        : "--out1 ${meta.id}.trimmed_R1.fastq.gz --out2 ${meta.id}.trimmed_R2.fastq.gz"
    """
    fastp \
        ${input_args} \
        ${output_args} \
        --html ${meta.id}.fastp.html \
        --json ${meta.id}.fastp.json \
        --thread ${params.threads}
    """
}

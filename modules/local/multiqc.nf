process MULTIQC {
    label 'process_low'

    container 'quay.io/biocontainers/multiqc:1.21--pyhdfd78af_0'

    publishDir "${params.outdir}/multiqc/${name}", mode: 'copy'

    input:
    val(name)       // label for output subdirectory, e.g. 'raw' or 'trimmed'
    path(reports)   // collected list of FastQC ZIPs / fastp JSONs

    output:
    path("multiqc_report.html"), emit: report
    path("multiqc_data"),        emit: data

    script:
    """
    multiqc .
    """
}

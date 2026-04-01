workflow INPUT_CHECK {
    take:
    samplesheet   // path: CSV file with columns sample, fastq_1, fastq_2

    main:
    reads = Channel
        .fromPath(samplesheet)
        .splitCsv(header: true, strip: true)
        .map { row -> parse_row(row) }

    emit:
    reads   // channel: [ meta, [ reads ] ]
}

def parse_row(row) {
    def meta = [
        id        : row.sample,
        single_end: !row.fastq_2   // empty string / null → single-end
    ]

    // Resolve relative paths against projectDir so the samplesheet stays portable
    def r1 = file("${projectDir}/${row.fastq_1}", checkIfExists: true)
    def reads = meta.single_end
        ? [ r1 ]
        : [ r1, file("${projectDir}/${row.fastq_2}", checkIfExists: true) ]

    return [ meta, reads ]
}

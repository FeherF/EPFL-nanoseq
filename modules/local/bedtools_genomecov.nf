process BEDTOOLS_GENOMECOV {
    tag "$meta.id"
    label 'process_high'

    container 'docker.io/ff1997/bedtools-sort:latest'

    input:
    tuple val(meta), path(sizes), val(is_transcripts), path(bam), path(bai)

    output:
    tuple val(meta), path(sizes), path("*.bedGraph"), emit: bedgraph
    path "versions.yml"                             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    split = (params.protocol == 'DNA' || is_transcripts) ? "" : "-split"
    mem_size = task.memory.toString().replaceAll(/\s*B$/, '').replaceAll(/\s+/, '')

    """
    bedtools \\
        genomecov \\
        -split \\
        -ibam ${bam[0]} \\
        -bg \\
        > tmp.bg

    sort -k1,1 -k2,2n --parallel=${task.cpus} --buffer-size=${mem_size} tmp.bg > ${meta.id}.bedGraph

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bedtools: \$(bedtools --version | sed -e "s/bedtools v//g")
    END_VERSIONS
    """
}

process SAMTOOLS_SORT_INDEX {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::samtools=1.14"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.15.1--h1170115_0' :
        'quay.io/biocontainers/samtools:1.15.1--h1170115_0' }"

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("*sorted.bam"), path("*.bai"), optional:true, emit: bam_bai
    tuple val(meta), path("*sorted.bam"), path("*.csi"), optional:true, emit: bam_csi
    path  "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = meta.prefix ?: meta.id

    """
    samtools sort -@ $task.cpus -o "${prefix}.sorted.bam" -T "${prefix}" "$bam"
    samtools index "${prefix}.sorted.bam"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """
}

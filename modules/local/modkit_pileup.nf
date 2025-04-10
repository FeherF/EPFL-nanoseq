process MODKIT_PILEUP {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::modkit=0.4.3"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ont-modkit:0.4.3--hcdda2d0_0' :
        'quay.io/biocontainers/ont-modkit:0.4.3--hcdda2d0_0' }"

    input:
    tuple val(meta), path(bam), path(index)

    output:
    tuple val(meta), path("*_mc.bed"), emit: mc_calls
    path "versions.yml"                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    modkit pileup \\
    ${bam} \\
    ${meta.id}_mc.bed


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        modkit: \$(modkit -V | sed 's/^[^ ]* //')
    END_VERSIONS
    """
}

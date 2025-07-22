process MODKIT_PILEUP {
    tag "$meta.id"
    label 'process_high'

    conda "bioconda::ont-modkit=0.5.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ont-modkit:0.4.3--hcdda2d0_0' :
        'quay.io/biocontainers/ont-modkit:0.4.3--hcdda2d0_0' }"

    input:
    tuple val(meta), path(bam), path(index)
    path(fasta)
    path(fai)

    output:
    tuple val(meta), path("*.bed"), emit: mc_calls
    path("*.bedgraph")               , emit: mc_bedgraph
    path "versions.yml"              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    modkit pileup \\
    ${bam} \\
    ${meta.id}.cpg.5mc.modkit.bed \\
    --ref ${fasta} \\
    --preset traditional \\
    --threads ${task.cpus}

    modkit pileup \\
    ${bam} \\
    ./${meta.id}.cpg.5mc.modkit.bedgraph \\
    --bedgraph \\
    --ref ${fasta} \\
    --preset traditional \\
    --threads ${task.cpus}

    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        modkit: \$(modkit -V | sed 's/^[^ ]* //')
    END_VERSIONS
    """
}

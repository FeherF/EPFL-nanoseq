process MODKIT_PILEUP_HAPLOTAGGED {
    tag "$meta.id"
    label 'process_high'

    container 'docker.io/ff1997/modkit-samtools-bedgraphtobigwig:latest'

    input:
    tuple val(meta), path(sizes)
    path(first_bam)
    path(second_bam)
    path(fasta)
    path(fai)

    output:
    tuple val(meta), path("*.modkit.bed")   , emit: mc_calls
    path("*.bedgraph")                      , emit: mc_bedgraph
    path("*.bw")                            , emit: mc_bw
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    samtools index ${first_bam}
    samtools index ${second_bam}

    modkit pileup \\
    ${first_bam} \\
    ${meta.id}.h1.cpg.5mc.modkit.bed \\
    --ref ${fasta} \\
    --preset traditional \\
    --threads ${task.cpus}

    modkit pileup \\
    ${first_bam} \\
    . \\
    --prefix ${meta.id}.h1.cpg.5mc.modkit \\
    --bedgraph \\
    --ref ${fasta} \\
    --preset traditional \\
    --threads ${task.cpus}

    modkit pileup \\
    ${second_bam} \\
    ${meta.id}.h2.cpg.5mc.modkit.bed \\
    --ref ${fasta} \\
    --preset traditional \\
    --threads ${task.cpus}

    modkit pileup \\
    ${second_bam} \\
    . \\
    --prefix ${meta.id}.h2.cpg.5mc.modkit \\
    --bedgraph \\
    --ref ${fasta} \\
    --preset traditional \\
    --threads ${task.cpus}

    for file in *.bedgraph; do
        base=\${file%.bedgraph}
        awk '{ print \$1, \$2, \$3, \$4 }' "\$file" > "\${base}.filtered.bedgraph"
        bedGraphToBigWig "\${base}.filtered.bedgraph" "${sizes.getName()}" "\${base}.bw"
        rm "\${base}.filtered.bedgraph"
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        modkit: \$(modkit -V | sed 's/^[^ ]* //')
    """
}

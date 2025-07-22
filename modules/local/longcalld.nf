process LONGCALLD {
    tag "$meta.id"
    label 'process_high'

    container 'quay.io/biocontainers/longcalld:0.0.4--h7d57edc_1'

    input:
    tuple val(meta), path(sizes), val(is_transcripts), path(input), path(index)
    path(fasta)

    output:
    tuple val(meta), path("*.longcallD.vcf"), emit: sv_calls
    path "versions.yml"                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    longcallD call -t${task.cpus} ${fasta} ${input} --ont > ${meta.id}.longcallD.vcf
    
    cat ${meta.id}.longcallD.vcf | grep -E '^#|SVTYPE' > ${meta.id}.longcallD.svtype.vcf

    rm ${meta.id}.longcallD.vcf
    mv ${meta.id}.longcallD.svtype.vcf ${meta.id}.longcallD.vcf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        longcalld: \$(longcallD 2>&1 | grep 'Version:' | sed 's/^Version: \\([0-9.]*\\).*/\\1/')
    END_VERSIONS
    """
}


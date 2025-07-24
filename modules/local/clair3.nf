process CLAIR3 {
    tag "$meta.id"
    label 'process_high'

    container 'hkubal/clair3:v1.1.2'

    input:
    tuple val(meta), path(sizes), val(is_transcripts), path(input), path(index)
    path(fasta)
    path(fai)
    val model

    output:
    tuple val(meta), path("*clair3.vcf.gz")    ,  emit: vcf
    tuple val(meta), path("*clair3.vcf.gz.tbi"),  emit: tbi
    path "versions.yml"                        ,  emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    model_orig="${model}"

    model_conv=\$(echo "\$model_orig" | \
    sed -E 's/^dna_//' | \
    sed -E 's/@v([0-9.]+)/_v\\1/' | \
    sed 's/\\.//g')

    /opt/bin/run_clair3.sh \\
      --bam_fn=${input} \\
      --ref_fn=${fasta} \\
      --threads=${task.cpus} \\
      --platform=ont \\
      --model_path="/opt/models/\$model_conv"	 \\
      --output=.

    mv merge_output.vcf.gz ${meta.id}.clair3.vcf.gz
    mv merge_output.vcf.gz.tbi ${meta.id}.clair3.vcf.gz.tbi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
      clair3: \$(/opt/bin/run_clair3.sh --version 2>&1 | sed -n 's/.*v\\([0-9.]*\\).*/\\1/p')
    END_VERSIONS
    """
}

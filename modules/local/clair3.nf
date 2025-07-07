process CLAIR3 {
    tag "$meta.id"
    label 'process_high'

    container 'hkubal/clair3:latest'

    input:
    tuple val(meta), path(sizes), val(is_transcripts), path(input), path(index)
    path(fasta)
    path(fai)

    output:
    tuple val(meta), path("*output.vcf.gz")    ,  emit: vcf
    tuple val(meta), path("*output.vcf.gz.tbi"),  emit: tbi
    path "versions.yml"                 ,  emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    /opt/bin/run_clair3.sh \\
      --bam_fn=${input} \\
      --ref_fn=${fasta} \\
      --threads=${task.cpus} \\
      --platform=ont \\
      --model_path="/opt/models/r1041_e82_400bps_sup_v410"	 \\
      --output=.


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
      clair3: \$(
        /opt/bin/run_clair3.sh --version 2>&1 | sed -n 's/.*v\\([0-9.]*\\).*/\\1/p'
      )
    END_VERSIONS
    """
}

 
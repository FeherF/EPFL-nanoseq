process VCF2MAF {
    tag "$meta.id"
    label 'process_high'
    container 'docker.io/ff1997/vcf2maf-vep:latest'

    input:
    tuple val(meta), path(vcf)
    path(fasta)
    path(fai)
    path(vep_data)

    output:
    path("*.vcf2maf.maf")     , emit: annotated_maf
    path "versions.yml"       , emit: versions

    script:
    """
    source /opt/conda/etc/profile.d/conda.sh
    conda activate vep

    ncbi_build=\$(basename "$fasta" | cut -d'_' -f1)
    
    gzip -d -c ${vcf} > ${meta.prefix}.vcf
   
    vcf2maf \\
    --input-vcf=${meta.prefix}.vcf \\
    --output-maf=${meta.prefix}.vcf2maf.maf \\
    --ref-fasta=${fasta} \\
    --vep-path=/opt/conda/envs/vep/bin \\
    --vep-data=${vep_data} \\
    --ncbi-build=\$ncbi_build \\
    --vep-forks ${task.cpus} \\


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        vcf2maf: 1.6.22
    END_VERSIONS
    """
}
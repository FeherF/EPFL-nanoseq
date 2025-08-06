process WHATSHAP_PHASE {
    tag "$meta.id"
    label 'process_high'
    container 'docker.io/ff1997/whatshap-bcftools:latest'

    input:
    tuple path(bam), path(bai)   
    path(fasta)
    path(fai)
    tuple val(meta), path(vcf)
    
    output:
    path("*.whatshap.vcf")                   , emit: phased_vcf
    path("*.tsv"), optional:true             , emit: haplotag_list
    path("*.h1.whatshap.bam")                , emit: first_haplotagged_bam
    path("*.h2.whatshap.bam")                , emit: second_haplotagged_bam
    path("*.haplotagged.whatshap.bam")       , emit: haplotagged_bam
    path "versions.yml"                      , emit: versions

    script:
    """
    source /opt/conda/etc/profile.d/conda.sh
    conda activate bioenv

    if samtools view -H $bam | grep -q '^@RG'; then
        whatshap phase \\
          -o ${meta.id}.phased.whatshap.vcf \\
          --reference=$fasta \\
          $vcf \\
          $bam

        bgzip -c ${meta.id}.phased.whatshap.vcf > ${meta.id}.phased.whatshap.vcf.gz
        tabix -p vcf ${meta.id}.phased.whatshap.vcf.gz

        whatshap haplotag \\
          --output-threads=${task.cpus} \\
          -o ${meta.id}.haplotagged.bam \\
          --reference $fasta \\
          --output-haplotag-list ${meta.id}.haplotag.list.whatshap.tsv \\
          ${meta.id}.phased.whatshap.vcf.gz \\
          $bam
    else
        whatshap phase \\
          --ignore-read-groups \\
          -o ${meta.id}.phased.whatshap.vcf \\
          --reference=$fasta \\
          $vcf \\
          $bam
        
        bgzip -c ${meta.id}.phased.whatshap.vcf > ${meta.id}.phased.whatshap.vcf.gz
        tabix -p vcf ${meta.id}.phased.whatshap.vcf.gz

        whatshap haplotag \\
          --ignore-read-groups \\
          --output-threads=${task.cpus} \\
          -o ${meta.id}.haplotagged.whatshap.bam \\
          --reference $fasta \\
          --output-haplotag-list ${meta.id}.haplotag.list.whatshap.tsv \\
          ${meta.id}.phased.whatshap.vcf.gz \\
          $bam
    fi


    whatshap split \\
    --output-h1 ${meta.id}.h1.whatshap.bam \\
    --output-h2 ${meta.id}.h2.whatshap.bam \\
    $bam \\
    ${meta.id}.haplotag.list.whatshap.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
      whatshap: \$(echo \$(whatshap --version 2>&1) | sed -r 's/.{81}//')
    END_VERSIONS
    """
}
//TODO: we can have multiple read groups in the bam file, here we assume only one read group is present and we use --ingore-read-groups
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
    path("*_phased.vcf")                 , emit: phased_vcf
    path("*.tsv"), optional:true                 , emit: haplotag_list
    path("*h1.bam")                 , emit: first_haplotagged_bam
    path("*h2.bam")                 , emit: second_haplotagged_bam
    path "versions.yml"                  , emit: versions

    script:
    """
    source /opt/conda/etc/profile.d/conda.sh
    conda activate bioenv

    bcftools view -f PASS $vcf -Oz -o pass.vcf.gz

    if samtools view -H $bam | grep -q '^@RG'; then
        whatshap phase \\
          -o ${meta.id}_phased.vcf \\
          --reference=$fasta \\
          pass.vcf.gz \\
          $bam

        bgzip -c ${meta.id}_phased.vcf > ${meta.id}_phased.vcf.gz
        tabix -p vcf ${meta.id}_phased.vcf.gz

        whatshap haplotag \\
          -o ${meta.id}_haplotagged.bam \\
          --reference $fasta \\
          --output-haplotag-list ${meta.id}_haplotag_list.tsv \\
          ${meta.id}_phased.vcf.gz \\
          $bam
    else
        whatshap phase \\
          --ignore-read-groups \\
          -o ${meta.id}_phased.vcf \\
          --reference=$fasta \\
          pass.vcf.gz \\
          $bam
        
        bgzip -c ${meta.id}_phased.vcf > ${meta.id}_phased.vcf.gz
        tabix -p vcf ${meta.id}_phased.vcf.gz

        whatshap haplotag \\
          --ignore-read-groups \\
          -o ${meta.id}_haplotagged.bam \\
          --reference $fasta \\
          --output-haplotag-list ${meta.id}_haplotag_list.tsv \\
          ${meta.id}_phased.vcf.gz \\
          $bam
    fi


    whatshap split \\
      --output-h1 ${meta.id}_h1.bam \\
      --output-h2 ${meta.id}_h2.bam \\
      $bam \\
      ${meta.id}_haplotag_list.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        whatshap: \$(echo \$(whatshap --version 2>&1) | sed -r 's/.{81}//')
    END_VERSIONS
    """
}
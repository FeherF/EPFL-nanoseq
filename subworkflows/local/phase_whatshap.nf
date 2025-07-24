/*
 * Phasing with WhatsHap
 */
include { WHATSHAP_PHASE } from '../../modules/local/whatshap_phase'

workflow PHASE_WHATSHAP {
    take:
    ch_view_sortbam
    ch_fasta
    ch_fai
    ch_vcf

    main:
    ch_phased_vcf = Channel.empty()
    ch_versions = Channel.empty()
    ch_first_haplotagged_bam = Channel.empty()
    ch_second_haplotagged_bam = Channel.empty()

    /*
     * Phase with WhatsHap
     * This will produce a phased VCF file
     */
    WHATSHAP_PHASE( ch_view_sortbam, ch_fasta, ch_fai, ch_vcf ) 


    ch_phased_vcf = WHATSHAP_PHASE.out.phased_vcf
    ch_first_haplotagged_bam = WHATSHAP_PHASE.out.first_haplotagged_bam
    ch_second_haplotagged_bam = WHATSHAP_PHASE.out.second_haplotagged_bam
    ch_versions = WHATSHAP_PHASE.out.versions

    emit:
    ch_phased_vcf
    ch_first_haplotagged_bam
    ch_second_haplotagged_bam
    ch_versions
}

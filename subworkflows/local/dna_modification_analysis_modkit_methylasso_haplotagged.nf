/*
 * DNA MODIFICATION ANALYSIS WITH MODKIT
 */

include { MODKIT_PILEUP_HAPLOTAGGED } from '../../modules/local/modkit_pileup_haplotagged'
include { METHYLASSO_ANALYSE_HAPLOTAGGED } from '../../modules/local/methylasso_analyse_haplotagged'

workflow DNA_MODIFICATION_ANALYSIS_MODKIT_METHYLASSO_HAPLOTAGGED {
    take:
    ch_meta
    ch_first_haplotype
    ch_second_haplotype
    ch_fasta
    ch_fai

    main:
    ch_mc_bed = Channel.empty()
    modkit_versions = Channel.empty()
    methylasso_versions = Channel.empty()

    /*
     * Analyze DNA modifications with modkit
     * This will produce a bed file with the modification calls
     */
    MODKIT_PILEUP_HAPLOTAGGED( ch_meta, ch_first_haplotype, ch_second_haplotype, ch_fasta, ch_fai )
    mc_bed = MODKIT_PILEUP_HAPLOTAGGED.out.mc_calls
   
    /*
     * Run methylasso
     */
    METHYLASSO_ANALYSE_HAPLOTAGGED( mc_bed )    
    
    modkit_versions = modkit_versions.mix(MODKIT_PILEUP_HAPLOTAGGED.out.versions)
    methylasso_versions = methylasso_versions.mix(METHYLASSO_ANALYSE_HAPLOTAGGED.out.versions)

    emit:
    ch_mc_bed
    modkit_versions
    methylasso_versions
}
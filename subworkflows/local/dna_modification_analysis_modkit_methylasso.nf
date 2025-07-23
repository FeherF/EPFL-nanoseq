/*
 * DNA MODIFICATION ANALYSIS WITH MODKIT
 */

include { MODKIT_PILEUP } from '../../modules/local/modkit_pileup'
include { METHYLASSO_ANALYSE } from '../../modules/local/methylasso_analyse'

workflow DNA_MODIFICATION_ANALYSIS_MODKIT_METHYLASSO {
    take:
    ch_view_sortbam
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
    MODKIT_PILEUP( ch_view_sortbam, ch_fasta, ch_fai )
    mc_bed = MODKIT_PILEUP.out.mc_calls
    
    /*
     * Run methylasso
     */
    METHYLASSO_ANALYSE( mc_bed )    
    
    modkit_versions = modkit_versions.mix(MODKIT_PILEUP.out.versions)
    methylasso_versions = methylasso_versions.mix(METHYLASSO_ANALYSE.out.versions)

    emit:
    ch_mc_bed
    modkit_versions
    methylasso_versions
}

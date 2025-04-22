/*
 * DNA MODIFICATION ANALYSIS WITH MODKIT
 */

include { MODKIT_PILEUP } from '../../modules/local/modkit_pileup'
include { MODKIT_PILEUP_BEDGRAPH } from '../../modules/local/modkit_pileup_bedgraph'
include { METHYLASSO_ANALYSE } from '../../modules/local/methylasso_analyse'

workflow DNA_MODIFICATION_ANALYSIS_MODKIT_METHYLASSO {
    take:
    ch_view_sortbam

    main:
    ch_mc_bed = Channel.empty()
    ch_mc_bedgraph = Channel.empty()
    modkit_versions = Channel.empty()
    methylasso_versions = Channel.empty()

    /*
     * Analyze DNA modifications with modkit
     * This will produce a bed file with the modification calls
     */
    MODKIT_PILEUP( ch_view_sortbam )
    mc_bed = MODKIT_PILEUP.out.mc_calls
    /*
     * Produce bedgraph files
     */
    MODKIT_PILEUP_BEDGRAPH( ch_view_sortbam )
    /*
     * Run methylasso
     */
    METHYLASSO_ANALYSE( mc_bed )

    modkit_versions = modkit_versions.mix(MODKIT_PILEUP.out.versions)
    methylasso_versions = methylasso_versions.mix(METHYLASSO_ANALYSE.out.versions)

    // Emit also methylasso version
    // No need to emit other things, no ch_mc_bed
    emit:
    ch_mc_bed
    ch_mc_bedgraph
    modkit_versions
}

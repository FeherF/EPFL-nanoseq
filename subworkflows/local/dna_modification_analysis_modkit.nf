/*
 * DNA MODIFICATION DETECTION WITH MODKIT
 */

include { MODKIT_PILEUP } from '../../modules/local/modkit_pileup'
include { MODKIT_PILEUP_BEDGRAPH } from '../../modules/local/modkit_pileup_bedgraph'

workflow DNA_MODIFICATION_CALLING_MODKIT {
    take:
    ch_view_sortbam

    main:
    ch_mc_bed = Channel.empty()
    ch_mc_bedgraph = Channel.empty()
    modkit_versions = Channel.empty()

    /*
     * Call DNA modification with modkit
     */
    MODKIT_PILEUP( ch_view_sortbam )
    /*
     * Produce bedgraph files
     */
    MODKIT_PILEUP_BEDGRAPH( ch_view_sortbam )

    modkit_versions = modkit_versions.mix(MODKIT_PILEUP.out.versions)

    emit:
    ch_mc_bed
    ch_mc_bedgraph
    modkit_versions
}

/*
 * Basecalling with dorado
 */

include { DORADO_BASECALL } from '../../modules/local/dorado_basecall'

workflow BASECALL_DORADO {
    take:
    ch_pod5

    main:
    ch_basecalled_fastq = Channel.empty()
    dorado_version = Channel.empty()

    /*
     * Basecall with dorado
     * This will produce a a .bam file that will be converted to fastq.gz for downstream analysis
     */
    DORADO_BASECALL( ch_pod5 ) 

    ch_basecalled_fastq = DORADO_BASECALL.out.dorado_out
    dorado_version = DORADO_BASECALL.out.versions

    emit:
    ch_basecalled_fastq
    dorado_version
}

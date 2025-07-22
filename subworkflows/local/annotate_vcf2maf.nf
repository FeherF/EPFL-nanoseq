/*
 * Annotate .vcf files to .maf files
 */
include { VCF2MAF } from '../../modules/local/vcf2maf'

workflow ANNOTATE_VCF2MAF {
    take:
    ch_vcf
    ch_fasta
    ch_fai
    ch_vep_data

    main:
    ch_annotated_maf = Channel.empty()
    ch_versions = Channel.empty()

    /*
     * Annotate VCF to MAF
     * This will produce a phased MAF file
     */
    VCF2MAF( ch_vcf, ch_fasta, ch_fai, ch_vep_data ) 


    ch_annotated_maf = VCF2MAF.out.annotated_maf
    ch_versions = VCF2MAF.out.versions

    emit:
    ch_annotated_maf
    ch_versions
}

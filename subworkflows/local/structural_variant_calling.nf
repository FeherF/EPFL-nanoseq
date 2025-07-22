/*
 * Structural variant calling
 */

include { SNIFFLES                              } from '../../modules/local/sniffles'
include { BCFTOOLS_SORT as SNIFFLES_SORT_VCF    } from '../../modules/nf-core/bcftools/sort/main'
include { TABIX_BGZIP as SNIFFLES_BGZIP_VCF     } from '../../modules/nf-core/tabix/bgzip/main'
include { TABIX_TABIX as SNIFFLES_TABIX_VCF     } from '../../modules/nf-core/tabix/tabix/main'
include { CUTESV                                } from '../../modules/local/cutesv'
include { BCFTOOLS_SORT as CUTESV_SORT_VCF      } from '../../modules/nf-core/bcftools/sort/main'
include { TABIX_BGZIP as CUTESV_BGZIP_VCF       } from '../../modules/nf-core/tabix/bgzip/main'
include { TABIX_TABIX as CUTESV_TABIX_VCF       } from '../../modules/nf-core/tabix/tabix/main'
include { LONGCALLD                             } from '../../modules/local/longcalld'
include { BCFTOOLS_SORT as LONGCALLD_SORT_VCF   } from '../../modules/nf-core/bcftools/sort/main'
include { TABIX_BGZIP as LONGCALLD_BGZIP_VCF    } from '../../modules/nf-core/tabix/bgzip/main'
include { TABIX_TABIX as LONGCALLD_TABIX_VCF    } from '../../modules/nf-core/tabix/tabix/main'

workflow STRUCTURAL_VARIANT_CALLING {

    take:
    ch_view_sortbam
    ch_fasta
    ch_fai

    main:
    ch_sv_calls_vcf     = Channel.empty()
    ch_sv_calls_vcf_tbi = Channel.empty()

    ch_versions         = Channel.empty()

    /*
     * Call structural variants with sniffles
     */
    if (params.structural_variant_caller == 'sniffles') {

        /*
         * Call structural variants with sniffles
         */
        SNIFFLES( ch_view_sortbam )
        ch_versions = ch_versions.mix(SNIFFLES.out.versions)

        /*
         * Sort structural variants with bcftools
         */
        SNIFFLES_SORT_VCF( SNIFFLES.out.sv_calls )
        ch_sv_calls_vcf = SNIFFLES_SORT_VCF.out.vcf
        ch_versions = ch_versions.mix(SNIFFLES_SORT_VCF.out.versions)

        /*
         * Index sniffles vcf.gz
         */
        SNIFFLES_TABIX_VCF( ch_sv_calls_vcf )
        ch_sv_calls_tbi  = SNIFFLES_TABIX_VCF.out.tbi
        ch_versions = ch_versions.mix(SNIFFLES_TABIX_VCF.out.versions)

    } else if (params.structural_variant_caller == 'cutesv') {

        /*
        * Call structural variants with cutesv
        */
        CUTESV( ch_view_sortbam, ch_fasta )
        ch_versions = ch_versions.mix(CUTESV.out.versions)

        /*
         * Sort structural variants with bcftools
         */
        CUTESV_SORT_VCF( CUTESV.out.sv_calls )
        ch_sv_calls_vcf = CUTESV_SORT_VCF.out.vcf
        ch_versions = ch_versions.mix(CUTESV_SORT_VCF.out.versions)

        /*
         * Zip cutesv vcf.gz
         */
        CUTESV_TABIX_VCF( ch_sv_calls_vcf )
        ch_sv_calls_tbi  = CUTESV_TABIX_VCF.out.tbi
        ch_versions = ch_versions.mix(CUTESV_TABIX_VCF.out.versions)

    } else if (params.structural_variant_caller == 'longcalld') {

        /*
        * Call structural variants with longcallD
        */
        LONGCALLD( ch_view_sortbam, ch_fasta )
        ch_versions = ch_versions.mix(LONGCALLD.out.versions)

        /*
         * Zip longcallD vcf.gz
         */
        def ch_bgzip_input = LONGCALLD.out.sv_calls.map { meta, file ->
        def filename = file.getBaseName()    
        def newMeta = meta + [prefix: filename]
            tuple(newMeta, file)
        }
        LONGCALLD_BGZIP_VCF(ch_bgzip_input)
        ch_sv_calls_vcf = LONGCALLD_BGZIP_VCF.out.output
        ch_versions = ch_versions.mix(LONGCALLD_BGZIP_VCF.out.versions)

        /*
         * Index longcallD vcf.gz
         */
        LONGCALLD_TABIX_VCF( ch_sv_calls_vcf )
        ch_sv_calls_vcf_tbi  = LONGCALLD_TABIX_VCF.out.tbi
        ch_versions = ch_versions.mix(LONGCALLD_TABIX_VCF.out.versions)

    }

    emit:
    ch_sv_calls_vcf
    ch_sv_calls_vcf_tbi
    ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

////////////////////////////////////////////////////
/* --          VALIDATE INPUTS                 -- */
////////////////////////////////////////////////////

// Check input path parameters to see if they exist
checkPathParamList = [ params.input, params.multiqc_config ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters (missing protocol or profile will exit the run.)
if (params.input) {
    ch_input = file(params.input)
} else {
    exit 1, 'Input samplesheet not specified!'
}

// Function to check if running offline
def isOffline() {
    try {
        return NXF_OFFLINE as Boolean
    }
    catch( Exception e ) {
        return false
    }
}

if (params.protocol != 'DNA' && params.protocol != 'cDNA' && params.protocol != 'directRNA') {
    exit 1, "Invalid protocol option: ${params.protocol}. Valid options: 'DNA', 'cDNA', 'directRNA'"
}

if (!params.skip_demultiplexing) {
    if (!params.barcode_kit) {
        params.barcode_kit = 'Auto'
    }

    def qcatBarcodeKitList = ['Auto', 'RBK001', 'RBK004', 'NBD103/NBD104',
                            'NBD114', 'NBD104/NBD114', 'PBC001', 'PBC096',
                            'RPB004/RLB001', 'PBK004/LWB001', 'RAB204', 'VMK001', 'DUAL']

    if (params.barcode_kit && qcatBarcodeKitList.contains(params.barcode_kit)) {
        if (params.input_path) {
            ch_input_path = Channel.fromPath(params.input_path, checkIfExists: true)
        } else {
            exit 1, "Please specify a valid input fastq file to perform demultiplexing!"
        }
    } else {
        exit 1, "Please provide a barcode kit to demultiplex with qcat. Valid options: ${qcatBarcodeKitList}"
    }
}


if (!params.skip_alignment) {
    if (params.aligner != 'minimap2' && params.aligner != 'graphmap2') {
        exit 1, "Invalid aligner option: ${params.aligner}. Valid options: 'minimap2', 'graphmap2'"
    }
    if (params.protocol != 'DNA' && params.protocol != 'cDNA' && params.protocol != 'directRNA') {
        exit 1, "Invalid protocol option: ${params.protocol}. Valid options: 'DNA', 'cDNA', 'directRNA'"
    }
}

if (params.call_variants) {
    if (params.protocol != 'DNA') {
        exit 1, "Invalid protocol option: ${params.protocol}. Valid options: 'DNA'"
    }
    if (!params.skip_vc && params.variant_caller != 'medaka' && params.variant_caller != 'deepvariant' && params.variant_caller != 'pepper_margin_deepvariant' && params.variant_caller != 'clair3') {
        exit 1, "Invalid variant caller option: ${params.variant_caller}. Valid options: 'medaka', 'deepvariant' or 'pepper_margin_deepvariant'"
    }
    if (!params.skip_sv && params.structural_variant_caller != 'sniffles' && params.structural_variant_caller != 'cutesv' && params.structural_variant_caller != 'longcalld') {
        exit 1, "Invalid structural variant caller option: ${params.structural_variant_caller}. Valid options: 'sniffles', 'cutesv', 'longcalld'"
    }
}

if (!params.skip_quantification) {
    if (params.quantification_method != 'bambu' && params.quantification_method != 'stringtie2') {
        exit 1, "Invalid transcript quantification option: ${params.quantification_method}. Valid options: 'bambu', 'stringtie2'"
    }
    if (params.protocol != 'cDNA' && params.protocol != 'directRNA') {
        exit 1, "Invalid protocol option if performing quantification: ${params.protocol}. Valid options: 'cDNA', 'directRNA'"
    }
}

////////////////////////////////////////////////////
/* --          CONFIG FILES                    -- */
////////////////////////////////////////////////////

ch_multiqc_config        = file("$baseDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config) : Channel.empty()

////////////////////////////////////////////////////
/* --    IMPORT LOCAL MODULES/SUBWORKFLOWS     -- */
////////////////////////////////////////////////////

include { GET_TEST_DATA         } from '../modules/local/get_test_data'
include { GET_NANOLYSE_FASTA    } from '../modules/local/get_nanolyse_fasta'
include { QCAT                  } from '../modules/local/qcat'
include { BAM_RENAME            } from '../modules/local/bam_rename'
include { BAMBU                 } from '../modules/local/bambu'
include { MULTIQC               } from '../modules/local/multiqc'

/*
 * SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
 */

include { INPUT_CHECK                                               } from '../subworkflows/local/input_check'
include { BASECALL_DORADO                                           } from '../subworkflows/local/basecall_dorado'
include { PREPARE_GENOME                                            } from '../subworkflows/local/prepare_genome'
include { QCFASTQ_NANOPLOT_FASTQC                                   } from '../subworkflows/local/qcfastq_nanoplot_fastqc'
include { ALIGN_GRAPHMAP2                                           } from '../subworkflows/local/align_graphmap2'
include { ALIGN_MINIMAP2                                            } from '../subworkflows/local/align_minimap2'
include { BAM_SORT_INDEX_SAMTOOLS                                   } from '../subworkflows/local/bam_sort_index_samtools'
include { DNA_MODIFICATION_ANALYSIS_MODKIT_METHYLASSO               } from '../subworkflows/local/dna_modification_analysis_modkit_methylasso'
include { DNA_MODIFICATION_ANALYSIS_MODKIT_METHYLASSO_HAPLOTAGGED   } from '../subworkflows/local/dna_modification_analysis_modkit_methylasso_haplotagged'
include { SHORT_VARIANT_CALLING                                     } from '../subworkflows/local/short_variant_calling'
include { STRUCTURAL_VARIANT_CALLING                                } from '../subworkflows/local/structural_variant_calling'
include { PHASE_WHATSHAP                                            } from '../subworkflows/local/phase_whatshap'
include { ANNOTATE_VCF2MAF as ANNOTATE_SHORT_VARIANT_VCF2MAF        } from '../subworkflows/local/annotate_vcf2maf'
include { ANNOTATE_VCF2MAF as ANNOTATE_STRUCTURAL_VARIANT_VCF2MAF   } from '../subworkflows/local/annotate_vcf2maf'
include { BEDTOOLS_UCSC_BIGWIG                                      } from '../subworkflows/local/bedtools_ucsc_bigwig'
include { BEDTOOLS_UCSC_BIGBED                                      } from '../subworkflows/local/bedtools_ucsc_bigbed'
include { QUANTIFY_STRINGTIE_FEATURECOUNTS                          } from '../subworkflows/local/quantify_stringtie_featurecounts'
include { DIFFERENTIAL_DESEQ2_DEXSEQ                                } from '../subworkflows/local/differential_deseq2_dexseq'
include { RNA_MODIFICATION_XPORE_M6ANET                             } from '../subworkflows/local/rna_modifications_xpore_m6anet'
include { RNA_FUSIONS_JAFFAL                                        } from '../subworkflows/local/rna_fusions_jaffal'

////////////////////////////////////////////////////
/* --    IMPORT NF-CORE MODULES/SUBWORKFLOWS   -- */
////////////////////////////////////////////////////

/*
 * MODULE: Installed directly from nf-core/modules
 */
include { NANOLYSE                    } from '../modules/nf-core/nanolyse/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

/*
 * SUBWORKFLOW: Consisting entirely of nf-core/modules
 */

////////////////////////////////////////////////////
/* --           RUN MAIN WORKFLOW              -- */
////////////////////////////////////////////////////

// Info required for completion email and summary
def multiqc_report      = []

workflow NANOSEQ{

    // Pre-download test-dataset to get files for '--input_path' parameter
    // Nextflow is unable to recursively download directories via HTTPS
    if (workflow.profile.contains('test') && !workflow.profile.contains('vc')) {
        if (!params.skip_modification_analysis) {
            if (!isOffline()) {
                GET_TEST_DATA ()
                GET_TEST_DATA.out.ch_input_dir_path
                    .set { ch_input_path }
            } else {
                exit 1, "NXF_OFFLINE=true or -offline has been set so cannot download and run any test dataset!"
            }
        } else {
            if (params.input_path) {
                ch_input_path = Channel.fromPath(params.input_path, checkIfExists: true)
            } else {
                ch_input_path = 'not_changed'
            }
        }
    } else {
        if (params.input_path) {
            ch_input_path = Channel.fromPath(params.input_path, checkIfExists: true)
        } else {
            ch_input_path = 'not_changed'
        }
    }

    /*
     * Create empty software versions channel to mix
     */
    ch_software_versions = Channel.empty()
    /*
     * SUBWORKFLOW: Read in samplesheet, validate and stage input files
     */
    INPUT_CHECK ( ch_input, ch_input_path )
        .set { ch_sample }

    if (!params.skip_basecalling) {
        // Get .pod5 files (from --input_path or sample sheet)
        if (params.skip_demultiplexing) {
            ch_pod5 = ch_sample.map { [ it[0], file(it[-2]) ] }
        } else {
            ch_pod5 = ch_input_path.map { 
                def filePath = it.toString() 
                def fileName = filePath.tokenize('/').last().replaceAll(/\.pod5$/, '') 
                def meta = [ id: fileName ]
                tuple(meta, file(filePath)) 
            }
        }

        // Validate .pod5 files
        ch_pod5 = ch_pod5.map { tuple ->
            def pod5 = tuple[-1]
            if (!pod5.name.endsWith('.pod5')) exit 1, "Input must be .pod5 if basecalling is enabled: $pod5"
            if (!pod5.exists()) exit 1, "Missing file: $pod5"
            return tuple
        }

        BASECALL_DORADO(ch_pod5)
        ch_software_versions = BASECALL_DORADO.out.dorado_version.first().ifEmpty(null)
        def ch_basecalled_fastq = BASECALL_DORADO.out.ch_basecalled_fastq

        if (!params.skip_demultiplexing) {
            ch_input_path = ch_basecalled_fastq.map { it[1] }
            QCAT(ch_input_path)
            ch_fastq = QCAT.out.fastq
                .flatten()
                .map { [ it, it.baseName.substring(0,it.baseName.lastIndexOf('.'))] }
                .join(ch_sample, by: 1)
                .map { it -> [ it[2], it[1], it[3], it[4], it[5], it[6] ] }
            ch_software_versions = ch_software_versions.mix(QCAT.out.versions.ifEmpty(null))
        } else {
            // Replace input path with basecalled .fastq path
            ch_sample = ch_sample
                .map { row -> [ row[0], row ] }
                .join(ch_basecalled_fastq, by: 0)
                .map { [ it[1][0], it[1][1], it[1][2], it[1][3], it[1][4], it[1][5], it[2] ] }

            if (!params.skip_alignment) {
                ch_fastq = ch_sample.map { it -> it[6].toString().endsWith('.gz') ? [ it[0], it[6], it[2], it[1], it[4], it[5] ] : null }
            } else {
                ch_fastq = Channel.empty()
            }
        }

        if (params.only_basecalling) { return } // Exit workflow if only basecalling is requested
        
    } else {
        // basecalling is skipped
        if (!params.skip_demultiplexing) {
            QCAT(ch_input_path)
            ch_fastq = QCAT.out.fastq
                .flatten()
                .map { [ it, it.baseName.substring(0,it.baseName.lastIndexOf('.'))] }
                .join(ch_sample, by: 1)
                .map { it -> [ it[2], it[1], it[3], it[4], it[5], it[6] ] }
            ch_software_versions = ch_software_versions.mix(QCAT.out.versions.ifEmpty(null))
        } else {
            ch_fastq = !params.skip_alignment
                ? ch_sample.map { it -> it[6].toString().endsWith('.gz') ? [ it[0], it[6], it[2], it[1], it[4], it[5] ] : null }
                : Channel.empty()
        }
    }

    if (params.run_nanolyse) {
        ch_fastq
            .map { it -> [ it[0], it[1] ] }
            .set { ch_fastq_nanolyse }

        if (!params.nanolyse_fasta) {
            if (!isOffline()) {
                GET_NANOLYSE_FASTA()
                GET_NANOLYSE_FASTA.out.ch_nanolyse_fasta
                    .set{ ch_nanolyse_fasta }
            } else {
                exit 1, "NXF_OFFLINE=true or -offline has been set so cannot download lambda.fasta.gz file for running NanoLyse! Please explicitly specify --nanolyse_fasta."
            }
        } else {
            ch_nanolyse_fasta = file(params.nanolyse_fasta, checkIfExists: true)
        }
        /*
         * MODULE: DNA contaminant removal using NanoLyse
         */
        NANOLYSE ( ch_fastq_nanolyse, ch_nanolyse_fasta )
        NANOLYSE.out.fastq
            .join( ch_sample )
            .map { it -> [ it[0], it[1], it[3], it[4], it[5], it[6] ]}
            .set { ch_fastq }
        ch_software_versions = ch_software_versions.mix(NANOLYSE.out.versions.first().ifEmpty(null))
    }

    ch_fastqc_multiqc = Channel.empty()
    if (!params.skip_qc) {

        /*
         * SUBWORKFLOW: Fastq QC with Nanoplot and fastqc
         */
        QCFASTQ_NANOPLOT_FASTQC ( ch_fastq, params.skip_nanoplot, params.skip_fastqc)
        ch_software_versions = ch_software_versions.mix(QCFASTQ_NANOPLOT_FASTQC.out.fastqc_version.first().ifEmpty(null))
        ch_fastqc_multiqc    = QCFASTQ_NANOPLOT_FASTQC.out.fastqc_multiqc.ifEmpty([])
    }

    ch_samtools_multiqc = Channel.empty()
    if (!params.skip_alignment) {

        /*
         * SUBWORKFLOW: Make chromosome size file and covert GTF to BED12
         */
        PREPARE_GENOME ( ch_fastq )
        ch_fasta_index = PREPARE_GENOME.out.ch_fasta_index
        ch_gtf_bed     = PREPARE_GENOME.out.ch_gtf_bed
        ch_fasta       = PREPARE_GENOME.out.ch_fasta
        ch_fai         = PREPARE_GENOME.out.ch_fai
        ch_software_versions = ch_software_versions.mix(PREPARE_GENOME.out.samtools_version.first().ifEmpty(null))
        ch_software_versions = ch_software_versions.mix(PREPARE_GENOME.out.gtf2bed_version.first().ifEmpty(null))
        if (params.aligner == 'minimap2') {

            /*
            * SUBWORKFLOW: Align fastq files with minimap2 and sort bam files
            */
            ALIGN_MINIMAP2 ( ch_fasta_index, ch_fastq )
            ch_align_sam = ALIGN_MINIMAP2.out.ch_align_sam
                .map { meta, sizes, is_transcripts, sam_file -> 
                    def new_meta = meta + [prefix: "${meta.id}.minimap2"]
                    [ new_meta, sizes, is_transcripts, sam_file ]
                }
            ch_index = ALIGN_MINIMAP2.out.ch_index
            ch_software_versions = ch_software_versions.mix(ALIGN_MINIMAP2.out.minimap2_version.first().ifEmpty(null))
        } else {

            /*
             * SUBWORKFLOW: Align fastq files with graphmap2 and sort bam files
             */
            ALIGN_GRAPHMAP2 ( ch_fasta_index, ch_fastq )
            ch_align_sam = ALIGN_GRAPHMAP2.out.ch_align_sam
                .map { meta, sizes, is_transcripts, sam_file -> 
                    def new_meta = meta + [prefix: "${meta.id}.graphmap"]
                    [ new_meta, sizes, is_transcripts, sam_file ]
                }            
            ch_index = ALIGN_GRAPHMAP2.out.ch_index
            ch_software_versions = ch_software_versions.mix(ALIGN_GRAPHMAP2.out.graphmap2_version.first().ifEmpty(null))
        }

        /*
        * SUBWORKFLOW: View, then  sort, and index bam files
        */
        BAM_SORT_INDEX_SAMTOOLS ( ch_align_sam, params.call_variants, ch_fasta )
        ch_view_sortbam = BAM_SORT_INDEX_SAMTOOLS.out.sortbam
        ch_software_versions = ch_software_versions.mix(BAM_SORT_INDEX_SAMTOOLS.out.samtools_versions.first().ifEmpty(null))
        ch_samtools_multiqc  = BAM_SORT_INDEX_SAMTOOLS.out.sortbam_stats_multiqc.ifEmpty([])
       
        /*
         * SUBWORKFLOW: DNA modification analysis with modkit
         */

        if (params.protocol == 'DNA') {
            ch_view_sortbam
                .map { it -> [ it[0], it[3], it[4] ] } // meta.id, bam, bam index
                .set { ch_modkit_input } 
            DNA_MODIFICATION_ANALYSIS_MODKIT_METHYLASSO ( ch_modkit_input, ch_fasta.map{ it [1] }, ch_fai.map{ it [1] }  )
            ch_software_versions = ch_software_versions.mix(DNA_MODIFICATION_ANALYSIS_MODKIT_METHYLASSO.out.modkit_versions.first().ifEmpty(null))
        }


        if (params.call_variants && params.protocol == 'DNA') {
            /*
            * SUBWORKFLOW: Short variant calling
            */
            if (!params.skip_vc) {
                def ch_clair3_model

                if (!params.skip_basecalling) {
                    // We match the model used during basecalling
                    if (params.clair_model == "dorado_model" || params.clair_model == null) {
                        ch_clair3_model = BASECALL_DORADO.out.ch_used_model.map { file -> file.text }
                    } else {
                        ch_clair3_model = params.clair_model
                    }
                }
                else {
                    if (params.clair_model == "dorado_model" || params.clair_model == null) {
                        exit 1, "Please specify a valid model for clair3 variant calling, e.g. '--clair_model = r1041_e82_400bps_sup_v410'. Check https://github.com/nanoporetech/rerio/tree/master/clair3_models."
                    }
                    ch_clair3_model = params.clair_model
                }
                SHORT_VARIANT_CALLING ( ch_view_sortbam, ch_fasta.map{ it [1] }, ch_fai.map{ it [1] }, ch_clair3_model )
                ch_vcf = SHORT_VARIANT_CALLING.out.ch_short_calls_vcf
                ch_software_versions = ch_software_versions.mix(SHORT_VARIANT_CALLING.out.ch_versions.first().ifEmpty(null))
            }

            /*
            * SUBWORKFLOW: Structural variant calling
            */
            if (!params.skip_sv) {
                STRUCTURAL_VARIANT_CALLING ( ch_view_sortbam, ch_fasta.map{ it [1] }, ch_fai.map{ it [1] } )
                ch_sv_vcf = STRUCTURAL_VARIANT_CALLING.out.ch_sv_calls_vcf
                ch_software_versions = ch_software_versions.mix(STRUCTURAL_VARIANT_CALLING.out.ch_versions.first().ifEmpty(null))
            }


            /*
            * SUBWORKFLOW: Annotate variants with vcf2maf
            */
            if (!params.skip_vc && params.annotate_vcf) {
                
                def ch_vep_data = nextflow.Channel.value(params.vep_data_path)
                ANNOTATE_SHORT_VARIANT_VCF2MAF(ch_vcf, ch_fasta.map { it[1] }, ch_fai.map { it[1] }, ch_vep_data)
                ANNOTATE_STRUCTURAL_VARIANT_VCF2MAF(ch_sv_vcf, ch_fasta.map { it[1] }, ch_fai.map { it[1] }, ch_vep_data)
            }


            /*
            * SUBWORKFLOW: Phasing with WhatsHap
            */
            if (params.phase_whatshap && params.call_variants && !params.skip_vc) {
                ch_view_sortbam_cleaned = ch_view_sortbam.map { it -> [ it[3], it[4] ] }
                PHASE_WHATSHAP( ch_view_sortbam_cleaned, ch_fasta.map{ it [1] }, ch_fai.map{ it [1] }, ch_vcf )
                ch_first_haplotype = PHASE_WHATSHAP.out.ch_first_haplotagged_bam
                ch_second_haplotype = PHASE_WHATSHAP.out.ch_second_haplotagged_bam
                ch_software_versions = ch_software_versions.mix(PHASE_WHATSHAP.out.ch_versions.first().ifEmpty(null))

                /*
                * Call haplotype-specific modifications with modkit
                */
                // Extract meta from ch_view_sortbam
                ch_meta = ch_view_sortbam.map{ it [0] }

                DNA_MODIFICATION_ANALYSIS_MODKIT_METHYLASSO_HAPLOTAGGED ( ch_meta, ch_first_haplotype, ch_second_haplotype, ch_fasta.map{ it [1] }, ch_fai.map{ it [1] }  )
                ch_software_versions = ch_software_versions.mix(DNA_MODIFICATION_ANALYSIS_MODKIT_METHYLASSO_HAPLOTAGGED.out.modkit_versions.first().ifEmpty(null))
            }
        }

        ch_bedtools_version = Channel.empty()
        if (!params.skip_bigwig) {

            /*
             * SUBWORKFLOW: Convert BAM -> BEDGraph -> BigWig
             */
            BEDTOOLS_UCSC_BIGWIG ( ch_view_sortbam )
            ch_bedtools_version = ch_bedtools_version.mix(BEDTOOLS_UCSC_BIGWIG.out.bedtools_version.first().ifEmpty(null))
            ch_software_versions = ch_software_versions.mix(BEDTOOLS_UCSC_BIGWIG.out.bedgraphtobigwig_version.first().ifEmpty(null))
        }
        if (!params.skip_bigbed) {

            /*
             * SUBWORKFLOW: Convert BAM -> BED12 -> BigBED
             */
            BEDTOOLS_UCSC_BIGBED ( ch_view_sortbam )
            ch_bedtools_version = ch_bedtools_version.mix(BEDTOOLS_UCSC_BIGBED.out.bedtools_version.first().ifEmpty(null))
            ch_software_versions = ch_software_versions.mix(BEDTOOLS_UCSC_BIGBED.out.bed12tobigbed_version.first().ifEmpty(null))
        }
        ch_software_versions = ch_software_versions.mix(ch_bedtools_version.first().ifEmpty(null))

        ch_view_sortbam
            .map { it -> [ it[0], it[3] ] }
            .set { ch_sortbam }
        ch_view_sortbam
            .map { it -> [ it[0], it[3], it[4] ] }
            .set { ch_nanopolish_sortbam }
    } else {
        ch_sample
            .map { it -> if (it[6].toString().endsWith('.bam')) [ it[0], it[6] ] }
            .set { ch_sample_bam }
        BAM_RENAME ( ch_sample_bam )
        ch_sortbam = BAM_RENAME.out.bam
    }

    ch_featurecounts_gene_multiqc       = Channel.empty()
    ch_featurecounts_transcript_multiqc = Channel.empty()
    if (!params.skip_quantification && (params.protocol == 'cDNA' || params.protocol == 'directRNA')) {

        // Check that reference genome and annotation are the same for all samples if perfoming quantification
        // Check if we have replicates and multiple conditions in the input samplesheet
        REPLICATES_EXIST    = false
        MULTIPLE_CONDITIONS = false
        ch_sample.map{ it[2] }.unique().toList().set { fastas }
        ch_sample.map{ it[3] }.unique().toList().set { gtfs }
        // BUG: ".val" halts the pipeline ///////////////////////
        //  if ( gtfs.map{it[0]} == false || fastas.map{it[0]} == false || gtfs.size().val != 1 || fasta.size().val != 1 ) {
        //      exit 1, """Quantification can only be performed if all samples in the samplesheet have the same reference fasta and GTF file."
        //              Please specify the '--skip_quantification' parameter if you wish to skip these steps."""
        //  }
        //  REPLICATES_EXIST    = ch_sample.map { it -> it[0].split('_')[-1].replaceAll('R','').toInteger() }.max().val > 1
        //  MULTIPLE_CONDITIONS = ch_sample.map { it -> it[0].split('_')[0..-2].join('_') }.unique().count().val > 1

        ch_r_version = Channel.empty()
        if (params.quantification_method == 'bambu') {
            ch_sample
                .map { it -> [ it[2], it[3] ]}
                .unique()
                .set { ch_sample_annotation }

            /*
             * MODULE: Quantification and novel isoform detection with bambu
             */
            BAMBU ( ch_sample_annotation, ch_sortbam.collect{ it [1] } )
            ch_gene_counts       = BAMBU.out.ch_gene_counts
            ch_transcript_counts = BAMBU.out.ch_transcript_counts
            ch_software_versions = ch_software_versions.mix(BAMBU.out.versions.first().ifEmpty(null))
        } else {

            /*
             * SUBWORKFLOW: Novel isoform detection with StringTie and Quantification with featureCounts
             */
            QUANTIFY_STRINGTIE_FEATURECOUNTS( ch_sample, ch_sortbam )
            ch_gene_counts                      = QUANTIFY_STRINGTIE_FEATURECOUNTS.out.ch_gene_counts
            ch_transcript_counts                = QUANTIFY_STRINGTIE_FEATURECOUNTS.out.ch_transcript_counts
            ch_software_versions                = ch_software_versions.mix(QUANTIFY_STRINGTIE_FEATURECOUNTS.out.stringtie2_version.first().ifEmpty(null))
            ch_software_versions                = ch_software_versions.mix(QUANTIFY_STRINGTIE_FEATURECOUNTS.out.featurecounts_version.first().ifEmpty(null))
            ch_featurecounts_gene_multiqc       = QUANTIFY_STRINGTIE_FEATURECOUNTS.out.featurecounts_gene_multiqc.ifEmpty([])
            ch_featurecounts_transcript_multiqc = QUANTIFY_STRINGTIE_FEATURECOUNTS.out.featurecounts_transcript_multiqc.ifEmpty([])
        }
        if (!params.skip_differential_analysis) {

            /*
             * SUBWORKFLOW: Differential gene and transcript analysis with DESeq2 and DEXseq
             */
            DIFFERENTIAL_DESEQ2_DEXSEQ( ch_gene_counts, ch_transcript_counts )
            ch_software_versions = ch_software_versions.mix(DIFFERENTIAL_DESEQ2_DEXSEQ.out.deseq2_version.first().ifEmpty(null))
            ch_software_versions = ch_software_versions.mix(DIFFERENTIAL_DESEQ2_DEXSEQ.out.dexseq_version.first().ifEmpty(null))
        }
    }

    if (!params.skip_modification_analysis && params.protocol == 'directRNA') {

        /*
         * SUBWORKFLOW: RNA modification detection with xPore and m6anet
         */
        RNA_MODIFICATION_XPORE_M6ANET( ch_sample, ch_nanopolish_sortbam )
    }

    if (!params.skip_fusion_analysis && (params.protocol == 'cDNA' || params.protocol == 'directRNA')) {

        /*
         * SUBWORKFLOW: RNA_FUSIONS_JAFFAL
         */
        ch_fastq
            .map { it -> [ it[0], it[1] ] }
            .set { ch_fastq_simple }

        RNA_FUSIONS_JAFFAL( ch_fastq_simple, params.jaffal_ref_dir )
    }

    /*
     * MODULE: Parse software version numbers
     */
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_software_versions.unique().collectFile()
    )

    if (!params.skip_multiqc) {
        workflow_summary    = WorkflowNanoseq.paramsSummaryMultiqc(workflow, summary_params)
        ch_workflow_summary = Channel.value(workflow_summary)

        /*
         * MODULE: MultiQC
         */
        MULTIQC (
        ch_multiqc_config,
        ch_multiqc_custom_config.collect().ifEmpty([]),
        ch_fastqc_multiqc.ifEmpty([]),
        ch_samtools_multiqc.collect().ifEmpty([]),
        ch_featurecounts_gene_multiqc.ifEmpty([]),
        ch_featurecounts_transcript_multiqc.ifEmpty([]),
        CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect(),
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml')
        )
    }
}

////////////////////////////////////////////////////
/* --              COMPLETION EMAIL            -- */
////////////////////////////////////////////////////

workflow.onComplete {
    if (params.email) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
        //Completion.email(workflow, params, params.summary_params, log, multiqc_report)
    }
//    Completion.summary(workflow, params, log)
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

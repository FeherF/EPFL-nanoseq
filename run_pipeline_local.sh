#!/bin/bash

### === CONFIGURATION (edit these only) ===
SAMPLE_NAME="sampleName"  
INPUT_PATH="small_samples/small_NA12878_DNA.pod5"  # .pod5 file
GTF_PATH=""                                     
DORADO_MODEL="hac"                                 # hac or sup
DORADO_MODIFICATION="5mCG_5hmCG"
CALL_VARIANTS=true
VARIANT_CALLER="clair3"
CLAIR_MODEL="dorado_model"                         # Use same model as basecalling or choose one
STRUCTURAL_VARIANT_CALLER="longcalld"
PHASE_WHATSHAP=true
ANNOTATE_VCF=true
### =======================================

# Output color
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "\n${YELLOW}===== Starting EPFL-nanoseq Pipeline (Local Run) =====${NC}\n"

cd ..

### === ENVIRONMENT DETECTION ===
if command -v nvidia-smi &>/dev/null && nvidia-smi -L &>/dev/null; then
    echo -e "${YELLOW}Detected NVIDIA GPUs. Running basecalling stage locally.${NC}\n"
    GPU_PRESENT=true
    REFERENCE_FASTA="/data/upwaszak/public/genomes/GRCh38DH/GRCh38_full_analysis_set_plus_decoy_hla.fa"
    VEP_DATA_PATH="/data/upwaszak/bin/vep"
    ONLY_BASECALLING="true"
    SKIP_BASECALLING="false"
else
    echo -e "${YELLOW}No NVIDIA GPUs detected. Running variant calling and downstream locally.${NC}\n"
    GPU_PRESENT=false
    SKIP_BASECALLING="true"
    ONLY_BASECALLING="false"
    INPUT_PATH=$(find results/dorado -maxdepth 1 -name '*.fastq.gz' | head -n 1)
    if [[ "$CLAIR_MODEL" == "dorado_model" ]]; then
        CLAIR_MODEL=$(sed -E 's/^dna_//; s/@v([0-9.]+)/_v\1/; s/\.//g' < results/dorado/model.txt)
    fi
    REFERENCE_FASTA="/data/shared/genomes/human/GRCh38DH/GRCh38_full_analysis_set_plus_decoy_hla.fa"
    VEP_DATA_PATH="/data/bin/vep"
fi

### === PIPELINE EXECUTION ===

echo -e "${YELLOW}Generating samplesheet.csv with input: ${INPUT_PATH}${NC}\n"
cat > samplesheet.csv <<EOF
group,replicate,barcode,input_file,fasta,gtf
${SAMPLE_NAME},1,,${INPUT_PATH},${REFERENCE_FASTA},${GTF_PATH}
EOF

echo -e "${YELLOW}Launching Nextflow pipeline with parameters:${NC}"
echo -e "${YELLOW}  only_basecalling = ${ONLY_BASECALLING}${NC}"
echo -e "${YELLOW}  skip_basecalling = ${SKIP_BASECALLING}${NC}"
echo -e "${YELLOW}  dorado_model = ${DORADO_MODEL}${NC}"
echo -e "${YELLOW}  dorado_modification = ${DORADO_MODIFICATION}${NC}"
echo -e "${YELLOW}  call_variants = ${CALL_VARIANTS}${NC}"
echo -e "${YELLOW}  variant_caller = ${VARIANT_CALLER}${NC}"
echo -e "${YELLOW}  clair_model = ${CLAIR_MODEL}${NC}"
echo -e "${YELLOW}  structural_variant_caller = ${STRUCTURAL_VARIANT_CALLER}${NC}"
echo -e "${YELLOW}  phase_whatshap = ${PHASE_WHATSHAP}${NC}"
echo -e "${YELLOW}  annotate_vcf = ${ANNOTATE_VCF}${NC}"
echo -e "${YELLOW}  vep_data_path = ${VEP_DATA_PATH}${NC}"

CMD="nextflow run EPFL-nanoseq \
  --input samplesheet.csv \
  --protocol DNA \
  -profile singularity \
  --only_basecalling ${ONLY_BASECALLING} \
  --skip_basecalling ${SKIP_BASECALLING} \
  --dorado_model '${DORADO_MODEL}' \
  --dorado_modification '${DORADO_MODIFICATION}' \
  --call_variants ${CALL_VARIANTS} \
  --variant_caller '${VARIANT_CALLER}' \
  --clair_model '${CLAIR_MODEL}' \
  --structural_variant_caller '${STRUCTURAL_VARIANT_CALLER}' \
  --phase_whatshap ${PHASE_WHATSHAP} \
  --annotate_vcf ${ANNOTATE_VCF} \
  --vep_data_path '${VEP_DATA_PATH}' \
  -resume"

echo -e "\n${YELLOW}Running Nextflow pipeline...${NC}"
eval $CMD

echo -e "\n${YELLOW}===== Pipeline Completed (Local run) =====${NC}\n"

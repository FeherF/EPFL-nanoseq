#!/bin/bash

### === CONFIGURATION (edit these only) ===
REMOTE_HOST="upwaszaksrv1.epfl.ch"
REMOTE_USER="feher"
REMOTE_DEST_DIR="${SAMPLE_NAME}"                   # Directory on TREX where restuls will be stored

SAMPLE_NAME="sampleName"  
INPUT_PATH="small_samples/small_NA12878_DNA.pod5"  # .pod5 file
GTF_PATH=""                                     
DORADO_MODEL="hac"                                 # hac or sup
DORADO_MODIFICATION="5mCG_5hmCG"
CALL_VARIANTS=true
VARIANT_CALLER="clair3"
CLAIR_MODEL="dorado_model"                         # We use the same model used during basecalling with dorado, otherwise choose one here https://github.com/nanoporetech/rerio/tree/master/clair3_models
STRUCTURAL_VARIANT_CALLER="longcalld"
PHASE_WHATSHAP=true
ANNOTATE_VCF=true
### =======================================

# Output color
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
echo -e "\n\033[1;33m===== Starting EPFL-nanoseq Pipeline =====\033[0m\n"
cd ..

### === ENVIRONMENT DETECTION ===
if command -v nvidia-smi &>/dev/null && nvidia-smi -L &>/dev/null; then
    echo -e "${YELLOW}Detected NVIDIA GPUs. Running on BMO (basecalling stage).${NC}\n"
    GPU_PRESENT=true
    REFERENCE_FASTA="/data/upwaszak/public/genomes/GRCh38DH/GRCh38_full_analysis_set_plus_decoy_hla.fa"
    VEP_DATA_PATH="/data/upwaszak/bin/vep"
    ONLY_BASECALLING="true"
    SKIP_BASECALLING="false"
    if ! ssh -o PasswordAuthentication=no -o BatchMode=yes -o ConnectTimeout=5 ${REMOTE_USER}@${REMOTE_HOST} 'exit' 2>/dev/null; then
        echo -e "${YELLOW}SSH key not yet added to remote server. Attempting to add...${NC}"
        if [ ! -f "$HOME/.ssh/id_rsa.pub" ]; then
            echo -e "${YELLOW}No SSH key found. Generating one...${NC}\n"
            ssh-keygen -t rsa -b 4096 -C "${USER}@$(hostname)" -f "$HOME/.ssh/id_rsa" -N ""
        fi
        ssh-copy-id ${REMOTE_USER}@${REMOTE_HOST}
    else
        echo -e "${YELLOW}SSH key already configured. No password required for remote access.${NC}\n"
    fi
else
    echo -e "${YELLOW}No NVIDIA GPUs detected. Running on TREX (variant calling and downstream).${NC}\n"
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

### === SYNC OUTPUT TO REMOTE (BMO only) ===
if $GPU_PRESENT; then
    LOCAL_PIPELINE_DIR="EPFL-nanoseq"
    LOCAL_RESULTS_DIR="results"

    if [ ! -d "$LOCAL_PIPELINE_DIR" ]; then
        echo -e "${YELLOW}ERROR: Local pipeline directory '$LOCAL_PIPELINE_DIR' does not exist. Exiting.${NC}" >&2
        exit 2
    fi

    if [ ! -d "$LOCAL_RESULTS_DIR" ]; then
        echo -e "${YELLOW}Warning: '$LOCAL_RESULTS_DIR' directory not found. Creating empty results directory on remote.${NC}"
    fi

    echo -e "${YELLOW}Syncing pipeline and results to TREX at ${REMOTE_USER}@${REMOTE_HOST}:~/${REMOTE_DEST_DIR}${NC}"
    ssh ${REMOTE_USER}@${REMOTE_HOST} "mkdir -p ~/${REMOTE_DEST_DIR}"

    rsync -avz --delete --quiet "${LOCAL_PIPELINE_DIR}/" "${REMOTE_USER}@${REMOTE_HOST}:~/${REMOTE_DEST_DIR}/EPFL-nanoseq/"
    rsync -avz --quiet "${LOCAL_RESULTS_DIR}/" "${REMOTE_USER}@${REMOTE_HOST}:~/${REMOTE_DEST_DIR}/results/"

    if [[ $? -eq 0 ]]; then
        echo -e "${YELLOW}✅ Sync complete.${NC}"
    else
        echo -e "${YELLOW}❌ Sync failed.${NC}"
        exit 3
    fi

    echo -e "\n${YELLOW}Connecting to TREX to launch pipeline inside tmux session 'nanoseq'...${NC}"
    ssh ${REMOTE_USER}@${REMOTE_HOST} bash -lc '
        set -e
        source ~/.bashrc
        source ~/.profile
        export SDKMAN_DIR="$HOME/.sdkman"
        [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"
        export JAVA_HOME="$SDKMAN_DIR/candidates/java/current"
        export PATH="$JAVA_HOME/bin:$PATH"

        cd ~/'"${REMOTE_DEST_DIR}"'/EPFL-nanoseq
        echo -e "\n\033[1;33mLaunching ./run_pipeline.sh inside tmux session \"nanoseq\"...\033[0m\n"
        tmux new-session -d -s nanoseq '\''./run_pipeline.sh; echo -e "\n\033[1;33mPipeline finished. Press ENTER to keep terminal open...\033[0m\n"; read -r; exec bash'\''

        echo -e "\n\033[1;33mNextflow pipeline started on TREX inside tmux session \"nanoseq\".\033[0m"
        echo -e "\033[1;33mYou can attach with:\033[0m"
        echo -e "\033[1;33m  tmux attach-session -t nanoseq\033[0m\n"
    '
fi

echo -e "\n\033[1;33m===== Pipeline Completed (BMO sync + TREX launch) =====\033[0m\n"

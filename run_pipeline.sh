#!/bin/bash

cd ..
### === CONFIGURATION (edit these only) ===
REMOTE_USER="feher"
REMOTE_HOST="upwaszaksrv1.epfl.ch"
SAMPLE_NAME="sampleName"  # Change this accordingly
INPUT_PATH="small_samples/small_NA12878_DNA.pod5"  # This will be a .pod5 file
REMOTE_DEST_DIR="${SAMPLE_NAME}"
GTF_PATH=""
DORADO_MODEL="hac"
DORADO_MODIFICATION="5mCG_5hmCG"
CALL_VARIANTS=true
VARIANT_CALLER="clair3"
CLAIR_MODEL="dorado_model"  # We use the same model used during basecalling with dorado
STRUCTURAL_VARIANT_CALLER="longcalld"
PHASE_WHATSHAP=true
ANNOTATE_VCF=true
### =======================================

# Define colors for nicer output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

### === ENVIRONMENT DETECTION ===
if command -v nvidia-smi &>/dev/null && nvidia-smi -L &>/dev/null; then
    echo -e "${GREEN}Detected NVIDIA GPUs. Running on BMO (basecalling stage).${NC}"
    GPU_PRESENT=true
    REFERENCE_FASTA="/data/upwaszak/public/genomes/GRCh38DH/GRCh38_full_analysis_set_plus_decoy_hla.fa"
    VEP_DATA_PATH="/data/upwaszak/bin/vep"
    ONLY_BASECALLING="true"
    SKIP_BASECALLING="false"
    # Setup SSH key for passwordless transfer to TREX after basecalling
    if ! ssh -o PasswordAuthentication=no -o BatchMode=yes -o ConnectTimeout=5 ${REMOTE_USER}@${REMOTE_HOST} 'exit' 2>/dev/null; then
        echo -e "${YELLOW}SSH key not yet added to remote server. Attempting to add...${NC}"

        if [ ! -f "$HOME/.ssh/id_rsa.pub" ]; then
            echo -e "${YELLOW}No SSH key found. Generating one...${NC}"
            ssh-keygen -t rsa -b 4096 -C "${USER}@$(hostname)" -f "$HOME/.ssh/id_rsa" -N ""
        fi

        ssh-copy-id ${REMOTE_USER}@${REMOTE_HOST}
    else
        echo -e "${GREEN}SSH key already configured. No password required for remote access.${NC}"
    fi
else
    echo -e "${GREEN}No NVIDIA GPUs detected. Running on TREX (variant calling and downstream).${NC}"
    GPU_PRESENT=false
    SKIP_BASECALLING="true"
    ONLY_BASECALLING="false"
    INPUT_PATH=$(find results/dorado -maxdepth 1 -name '*.fastq.gz' | head -n 1)
    CLAIR_MODEL=$(sed -E 's/^dna_//; s/@v([0-9.]+)/_v\1/; s/\.//g' < results/dorado/model.txt)
    REFERENCE_FASTA="/data/shared/genomes/human/GRCh38DH/GRCh38_full_analysis_set_plus_decoy_hla.fa"
    VEP_DATA_PATH="/data/bin/vep"
fi


### === PIPELINE EXECUTION ===

echo -e "${YELLOW}Generating samplesheet.csv with input: ${INPUT_PATH}${NC}"
cat > samplesheet.csv <<EOF
group,replicate,barcode,input_file,fasta,gtf
${SAMPLE_NAME},1,,${INPUT_PATH},${REFERENCE_FASTA},${GTF_PATH}
EOF

echo -e "${YELLOW}Launching Nextflow pipeline with parameters:${NC}"
echo -e "  only_basecalling = ${ONLY_BASECALLING}"
echo -e "  skip_basecalling = ${SKIP_BASECALLING}"
echo -e "  dorado_model = ${DORADO_MODEL}"
echo -e "  dorado_modification = ${DORADO_MODIFICATION}"
echo -e "  call_variants = ${CALL_VARIANTS}"
echo -e "  variant_caller = ${VARIANT_CALLER}"
echo -e "  clair_model = ${CLAIR_MODEL}"
echo -e "  structural_variant_caller = ${STRUCTURAL_VARIANT_CALLER}"
echo -e "  phase_whatshap = ${PHASE_WHATSHAP}"
echo -e "  annotate_vcf = ${ANNOTATE_VCF}"
echo -e "  vep_data_path = ${VEP_DATA_PATH}"

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

echo -e "${YELLOW}Running Nextflow pipeline...${NC}"
eval $CMD

### === SYNC OUTPUT TO REMOTE (BMO only) ===
if $GPU_PRESENT; then
    LOCAL_PIPELINE_DIR="EPFL-nanoseq"
    LOCAL_RESULTS_DIR="results"

    if [ ! -d "$LOCAL_PIPELINE_DIR" ]; then
        echo -e "${RED}ERROR: Local pipeline directory '$LOCAL_PIPELINE_DIR' does not exist. Exiting.${NC}" >&2
        exit 2
    fi

    if [ ! -d "$LOCAL_RESULTS_DIR" ]; then
        echo -e "${YELLOW}Warning: '$LOCAL_RESULTS_DIR' directory not found. Creating empty results directory on remote.${NC}"
    fi

    echo -e "${YELLOW}Syncing pipeline directory '${LOCAL_PIPELINE_DIR}' and results '${LOCAL_RESULTS_DIR}' to remote host ${REMOTE_USER}@${REMOTE_HOST}:~/${REMOTE_DEST_DIR}/${NC}"
    ssh ${REMOTE_USER}@${REMOTE_HOST} "mkdir -p ~/${REMOTE_DEST_DIR}"

    rsync -avz --delete "${LOCAL_PIPELINE_DIR}/" "${REMOTE_USER}@${REMOTE_HOST}:~/${REMOTE_DEST_DIR}/EPFL-nanoseq/"
    rsync -avz "${LOCAL_RESULTS_DIR}/" "${REMOTE_USER}@${REMOTE_HOST}:~/${REMOTE_DEST_DIR}/results/"

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Sync complete.${NC}"
    else
        echo -e "${RED}❌ Sync failed.${NC}"
        exit 3
    fi

    echo -e "${YELLOW}Connecting to remote host to launch pipeline inside tmux session 'nanoseq'...${NC}"
    ssh ${REMOTE_USER}@${REMOTE_HOST} bash -lc "
        set -e
        source ~/.bashrc
        source ~/.profile
        export SDKMAN_DIR=\"\$HOME/.sdkman\"
        [[ -s \"\$SDKMAN_DIR/bin/sdkman-init.sh\" ]] && source \"\$SDKMAN_DIR/bin/sdkman-init.sh\"
        export JAVA_HOME=\"\$SDKMAN_DIR/candidates/java/current\"
        export PATH=\"\$JAVA_HOME/bin:\$PATH\"

        cd ~/${REMOTE_DEST_DIR}/EPFL-nanoseq
        echo 'Launching ./run_pipeline.sh on TREX in tmux session \"nanoseq\"...'
        tmux new-session -d -s nanoseq \"bash -c './run_pipeline.sh; echo \\\"Pipeline finished. Press ENTER ...\\\"; read -r; exec bash'\"

        echo 'Nextflow pipeline started on TREX inside tmux session \"nanoseq\".'
        echo 'You can attach with:'
        echo '  tmux attach-session -t nanoseq'
    "
fi

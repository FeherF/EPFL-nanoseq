#!/bin/bash

cd ..
### === CONFIGURATION (edit these only) ===
REMOTE_USER="feher"
REMOTE_HOST="upwaszaksrv1.epfl.ch"
SAMPLE_NAME="sampleName"  # Change this accordingly
INPUT_PATH="small_samples/small_NA12878_DNA.pod5"  # Can be FASTQ or POD5
REMOTE_DEST_DIR="${SAMPLE_NAME}"
GTF_PATH=""
DORADO_MODEL="hac"
DORADO_MODIFICATION="5mCG_5hmCG"
CALL_VARIANTS=true
VARIANT_CALLER="clair3"
STRUCTURAL_VARIANT_CALLER="longcalld"
PHASE_WHATSHAP=true
ANNOTATE_VCF=true
### =======================================

### === ENVIRONMENT DETECTION ===
if command -v nvidia-smi &>/dev/null && nvidia-smi -L &>/dev/null; then
    echo "NVIDIA GPUs available, running on BMO"
    GPU_PRESENT=true
    REFERENCE_FASTA="/data/upwaszak/public/genomes/GRCh38DH/GRCh38_full_analysis_set_plus_decoy_hla.fa"
    VEP_DATA_PATH="/data/upwaszak/bin/vep"

    # Setup SSH key only once
    if ! ssh -o PasswordAuthentication=no -o BatchMode=yes -o ConnectTimeout=5 ${REMOTE_USER}@${REMOTE_HOST} 'exit' 2>/dev/null; then
        echo "SSH key not yet added to remote server. Attempting to add..."

        if [ ! -f "$HOME/.ssh/id_rsa.pub" ]; then
            echo "No SSH key found. Generating one..."
            ssh-keygen -t rsa -b 4096 -C "${USER}@$(hostname)" -f "$HOME/.ssh/id_rsa" -N ""
        fi

        ssh-copy-id ${REMOTE_USER}@${REMOTE_HOST}
    else
        echo "SSH key already configured. No password required."
    fi
else
    echo "No NVIDIA GPUs detected, running on TREX"
    GPU_PRESENT=false
    REFERENCE_FASTA="/data/shared/genomes/human/GRCh38DH/GRCh38_full_analysis_set_plus_decoy_hla.fa"
    VEP_DATA_PATH="/data/bin/vep"
fi

### === PIPELINE FLAGS ===
if $GPU_PRESENT; then
    SKIP_BASECALLING=false
    ONLY_BASECALLING=true
else
    SKIP_BASECALLING=true
    ONLY_BASECALLING=false
fi

CLAIR_MODEL=$([[ "$ONLY_BASECALLING" == "false" && "$SKIP_BASECALLING" == "false" ]] && echo "dorado_model" || echo "r1041_e82_400bps_sup_v410")

# Validate conflicting flags
if [[ "$ONLY_BASECALLING" == "true" && "$SKIP_BASECALLING" == "true" ]]; then
    echo "ERROR: BOTH ONLY_BASECALLING and SKIP_BASECALLING are true. Exiting." >&2
    exit 1
fi

### === PIPELINE EXECUTION ===

# Create samplesheet.csv
cat > samplesheet.csv <<EOF
group,replicate,barcode,input_file,fasta,gtf
${SAMPLE_NAME},1,,${INPUT_PATH},${REFERENCE_FASTA},${GTF_PATH}
EOF

# Run pipeline
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

echo "Running Nextflow pipeline..."
eval $CMD

### === SYNC OUTPUT TO REMOTE (BMO only) ===
if $GPU_PRESENT; then
    LOCAL_RESULT_DIR="results/dorado"

    if [ ! -d "$LOCAL_RESULT_DIR" ]; then
        echo "ERROR: Local output directory '$LOCAL_RESULT_DIR' does not exist. Skipping sync." >&2
        exit 2
    fi

    echo "Syncing output to remote: ${REMOTE_USER}@${REMOTE_HOST}:~/${REMOTE_DEST_DIR}/"
    ssh ${REMOTE_USER}@${REMOTE_HOST} "mkdir -p ~/${REMOTE_DEST_DIR}"
    rsync -avz ${LOCAL_RESULT_DIR}/ ${REMOTE_USER}@${REMOTE_HOST}:~/${REMOTE_DEST_DIR}/

    if [[ $? -eq 0 ]]; then
        echo "✅ Sync complete: ${LOCAL_RESULT_DIR} → ${REMOTE_USER}@${REMOTE_HOST}:~/${REMOTE_DEST_DIR}/"
    else
        echo "❌ Sync failed."
        exit 3
    fi
    
    echo "Connecting to remote host to clone and prepare EPFL-nanoseq repo..."
    ssh ${REMOTE_USER}@${REMOTE_HOST} bash -lc "
        set -e  # exit on failure
        source ~/.bashrc
        source ~/.profile
        export SDKMAN_DIR=\"\$HOME/.sdkman\"
        [[ -s \"\$SDKMAN_DIR/bin/sdkman-init.sh\" ]] && source \"\$SDKMAN_DIR/bin/sdkman-init.sh\"
        export JAVA_HOME=\"\$SDKMAN_DIR/candidates/java/current\"
        export PATH=\"\$JAVA_HOME/bin:\$PATH\"
        
        cd ~/${REMOTE_DEST_DIR}
        # If the repo doesn't exist yet, clone it
        if [ ! -d "EPFL-nanoseq" ]; then
            echo "Cloning EPFL-nanoseq repository..."
            git clone -b dev https://github.com/FeherF/EPFL-nanoseq.git
        else
            echo "EPFL-nanoseq repo already exists. Skipping clone."
        fi

        cd EPFL-nanoseq
        echo "Pulling latest changes from dev branch..."
        git checkout dev
        git pull origin dev

        echo "Running ./run_pipeline.sh..."
        tmux new-session -d -s nextflow_pipeline_session \"bash -c './run_pipeline.sh; echo \\\"Pipeline finished. Press ENTER ...\\\"; read -r; exec bash'\"

        echo 'Nextflow pipeline started inside tmux session \"nextflow_pipeline_session\". You can attach with:'
        echo '  tmux attach-session -t nextflow_pipeline_session' 



    "
fi

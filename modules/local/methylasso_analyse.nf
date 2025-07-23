process METHYLASSO_ANALYSE {
    tag "$meta.id"
    label 'process_long'
    errorStrategy 'ignore'
    container 'docker.io/ff1997/methylasso:latest'

    input:
    tuple val(meta), path(methyl_bed)

    output:
    path "versions.yml"                                      , emit: versions
    path "*.pdf"                                             , emit: calls
    path "*.tsv"                                             , emit: calls_tsv

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    INPUT_DIR="input"
    mkdir -p "\$INPUT_DIR"

    awk -v outdir="\$INPUT_DIR" '
    BEGIN {
        FS = OFS = "\t";
    }
    {
        chr = \$1;
        mod = \$4;
        perc = \$11 / 100;

        # Only process canonical chromosomes
        if (chr !~ /^chr([1-9]|1[0-9]|2[0-2]|X|Y|M)\$/) next;
        if (chr ~ /(random|chrUn)/) next;

        # Only process 5mC
        if (mod != "m") next;

        print \$1, \$2, \$3, \$10, perc >> outdir "/methylasso_input_m.bed";
    }
    ' "${methyl_bed}"


    source /opt/conda/etc/profile.d/conda.sh
    conda activate MethyLasso

    run_methylasso_or_warn() {
        local infile="input/methylasso_input_m.bed"
        local outfile="m"

        if [ -s "\$infile" ] && [ \$(wc -l < "\$infile") -ge 50000 ]; then
            Rscript /opt/methylasso/MethyLasso.R --n1 healthy --c1 "\$infile" --cov 4 --meth 5 -t 20 -o "."
        else
            echo "Sample m has too few rows for MethyLasso (<50000). Skipping analysis." > "\${outfile}.txt"
        fi
    }

    run_methylasso_or_warn
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
    methylasso: \$(Rscript /opt/methylasso/MethyLasso.R --version | grep 'MethyLasso version' | cut -d' ' -f3)
    END_VERSIONS
    """


}

process DORADO_BASECALL {
    tag "$meta.id"
    label 'process_high'

    container 'docker.io/ff1997/dorado-pigz:latest'

    input:
    tuple val(meta), path(pod5_path)

    output:
    tuple val(meta), path("*bc.fastq.gz")  , emit: dorado_out
    path("model.txt")                      , emit: model
    path "versions.yml"                    , emit: versions

    script:

    def emit_args = (params.dorado_modification == null) ? "--emit-fastq > ${meta.id}.bc.fastq && gzip ${meta.id}.bc.fastq" : "--modified-bases $params.dorado_modification > ${meta.id}.bc.bam"
    def dorado_model = (params.dorado_model == null) ? "hac" : params.dorado_model

    """
    dorado basecaller $dorado_model $pod5_path $emit_args 2> execution.log

    model_line=\$(grep -oP 'downloading\\s+\\Kdna_[^ ]+' execution.log | head -n1 || true)

    if [[ -n "\$model_line" ]]; then
        clair3_model=\$(echo "\$model_line" \\
            | sed -E 's/^dna_//' \\
            | sed -E 's/r/r/' \\
            | sed -E 's/\\./_/g' \\
            | sed -E 's/@v([0-9]+)\\.([0-9]+)/_v\\1\\2/' \\
        )_model
    else
        clair3_model="NA"
    fi

    echo "\$model_line" > model.txt

    ${params.dorado_modification ? """
    samtools fastq -T MM,ML -@ $task.cpus ${meta.id}.bc.bam > ${meta.id}.bc.fastq
    pigz -p48 ${meta.id}.bc.fastq
    rm ${meta.id}.bc.bam
    """ : ""}

    rm -rf $dorado_model
    rm -rf ~/.cache/dorado

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dorado: \$(echo \$(dorado --version 2>&1) | sed -r 's/.{81}//')
    END_VERSIONS

    """
}

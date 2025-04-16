//TODO: check if we can use GPU
process DORADO_BASECALL {
    tag "$meta.id"
    label 'process_medium'

    container "docker.io/ontresearch/dorado"

    input:
    tuple val(meta), path(pod5_path)

    output:
    tuple val(meta), path("*bc.fastq.gz")  , emit: dorado_out
    path "versions.yml"                    , emit: versions

    script:

    def emit_args = (params.dorado_modification == null) ? "--emit-fastq > ${meta.id}.bc.fastq && gzip ${meta.id}.bc.fastq" : "--modified-bases $params.dorado_modification > ${meta.id}.bc.bam"
    def dorado_model = (params.dorado_model == null) ? "hac" : params.dorado_model

    """
    dorado basecaller $dorado_model $pod5_path $emit_args

    ${params.dorado_modification ? """
    samtools fastq -T MM,ML -@ $task.cpus ${meta.id}.bc.bam > ${meta.id}.bc.fastq
    gzip ${meta.id}.bc.fastq
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

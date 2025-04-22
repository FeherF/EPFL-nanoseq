// Just addedd the container, logic still to be implemented, conversion from modkit and analysis with methylasso
process METHYLASSO_ANALYSE {
    tag "$meta.id"
    label 'process_medium'

    container 'docker.io/ff1997/methylasso:latest'

    input:
    tuple val(meta), path(bam)

    output:
    path "versions.yml"              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    Rscript /opt/methylasso/MethyLasso.R --version
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
    methylasso: \$(Rscript /opt/methylasso/MethyLasso.R --version | grep 'MethyLasso version' | cut -d' ' -f3)
    END_VERSIONS
    """
}

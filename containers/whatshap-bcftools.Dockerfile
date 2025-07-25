FROM continuumio/miniconda3

RUN conda install -n base -c conda-forge mamba && conda clean -afy

ENV CONDA_ALWAYS_YES=true \
    CONDA_CHANNELS=bioconda,conda-forge,defaults \
    PATH=/opt/conda/bin:$PATH

RUN mamba create -n bioenv python=3.10 bcftools=1.22 whatshap=2.8 samtools -c bioconda && \
    conda clean -afy

SHELL ["conda", "run", "-n", "bioenv", "/bin/bash", "-c"]

CMD ["bash"]


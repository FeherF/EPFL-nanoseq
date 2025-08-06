FROM --platform=linux/amd64 continuumio/miniconda3:latest

ENV DEBIAN_FRONTEND=noninteractive

RUN conda config --add channels defaults && \
    conda config --add channels bioconda && \
    conda config --add channels conda-forge && \
    conda install -y ont-modkit=0.5.0 samtools ucsc-bedgraphtobigwig=482 && \
    conda clean -afy

WORKDIR /data

CMD ["bash"]
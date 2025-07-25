FROM continuumio/miniconda3:latest

ENV DEBIAN_FRONTEND=noninteractive
ENV ENV_NAME=vep

RUN conda update -y -n base -c defaults conda && \
    conda config --set solver libmamba && \
    conda create -y -n ${ENV_NAME} && \
        conda install -y -n ${ENV_NAME} -c conda-forge -c bioconda -c defaults \
        ensembl-vep==112.0 \
        bcftools==1.20 \
        samtools==1.20 \
        ucsc-liftover==447 \
        perl-dbi \
        perl-list-moreutils \
        binutils && \
    conda clean -afy

# Remove broken conda activation scripts that cause unbound var errors
RUN rm -f /opt/conda/envs/${ENV_NAME}/etc/conda/activate.d/activate-binutils_*.sh && \
    rm -f /opt/conda/envs/${ENV_NAME}/etc/conda/activate.d/activate-gcc_*.sh

RUN apt-get update && apt-get install -y curl unzip rsync && rm -rf /var/lib/apt/lists/*

# Set environment variables for Perl and binaries
ENV PATH=/opt/conda/envs/${ENV_NAME}/bin:$PATH
ENV PERL5LIB=/opt/conda/envs/${ENV_NAME}/lib/perl5/site_perl/5.22.2:$PERL5LIB

# Define VEP cache location (to be mounted externally at runtime)
ENV VEP_CACHE_DIR=/data/.vep
ENV VEP_CACHE=$VEP_CACHE_DIR

# Download and install vcf2maf v1.6.22
WORKDIR /opt
RUN curl -L -o vcf2maf.zip https://github.com/mskcc/vcf2maf/archive/refs/tags/v1.6.22.zip && \
    unzip vcf2maf.zip && rm vcf2maf.zip && \
    ln -s /opt/vcf2maf-1.6.22/vcf2maf.pl /usr/local/bin/vcf2maf && \
    ln -s /opt/vcf2maf-1.6.22/maf2maf.pl /usr/local/bin/maf2maf && \
    chmod +x /usr/local/bin/vcf2maf /usr/local/bin/maf2maf

SHELL ["/bin/bash", "-c"]

WORKDIR /data

ENTRYPOINT ["/bin/bash"]
CMD ["bash"]


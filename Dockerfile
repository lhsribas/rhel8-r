FROM registry.redhat.io/ubi8/ubi:8.2

LABEL maintainer="Luiz Ribas <lribas@redhat.com>" \
      so.version="Red Hat Enterprise Linux 8.2"

ARG username=admin
ARG password=admin
ARG R_VERSION=3.6.3
ARG CRAN
ARG BUILD_DATE

ENV BUILD_DATE ${BUILD_DATE:-2020-04-24}
ENV R_VERSION=${R_VERSION:-3.6.3} \
    CRAN=${CRAN:-https://cran.rstudio.com} \ 
    TERM=xterm 

USER root

RUN subscription-manager register --username ${username} --password ${password} --auto-attach

RUN yum update -y && \
    yum groupinstall -y 'Development Tools' && \
    yum install -y java-1.8.0-openjdk && \
    yum install -y xz xz-devel && \        
    yum install -y readline-devel && \
    yum install -y xz xz-devel && \
    yum install -y pcre pcre-devel && \
    yum install -y libcurl-devel && \
    yum install -y texlive && \
    yum install -y *gfortran* && \
    yum install -y zlib* && \
    yum install -y bzip2-* && \
    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \
    ARCH=$( /bin/arch ) && \
    subscription-manager repos --enable "codeready-builder-for-rhel-8-${ARCH}-rpms" && \
    yum install  xorg-x11-server-Xorg xorg-x11-xauth xorg-x11-apps -y

## Instalation of R
RUN yum install -y xorg-x11-server-devel libX11-devel libXt-devel && \
    curl -O https://cran.r-project.org/src/base/R-3/R-${R_VERSION}.tar.gz && \
    ## Extract source code
    tar -xf R-${R_VERSION}.tar.gz && \
    ## Moving to /opt
    mv R-${R_VERSION} /opt/ && \
    ## Chnage permission
    chown -R root:0 /opt/R-${R_VERSION} && \
    ## Move to folder
    cd /opt/R-${R_VERSION} && \
    ## Configure script
    ./configure --with-x=yes \
                --enable-R-shlib \
                --enable-memory-profiling \
                --with-readline \
                --with-blas \
                --with-tcltk \
                --disable-nls \
                --with-recommended-packages \
    ## Now to launch R from anywhere
    && ln -s /opt/R-${R_VERSION} /usr/local/R

#Build and Install
RUN cd /opt/R-${R_VERSION} \
    && make \
    && make install \
    ## Add a library directory (for user-installed packages)
    && mkdir -p /usr/local/R-${R_VERSION}/site-library \
    && chown root:0 /usr/local/R-${R_VERSION}/site-library \
    && chmod a+rwX /usr/local/R-${R_VERSION}/site-library 


## Fix library path  
RUN sed -i '/^R_LIBS_USER=.*$/d' /usr/local/R/etc/Renviron \
    && echo "R_LIBS_USER=\${R_LIBS_USER-'/usr/local/R-${R_VERSION}/site-library'}" >> /usr/local/R/etc/Renviron \
    && echo "R_LIBS=\${R_LIBS-'/usr/local/R-${R_VERSION}/site-library:/usr/local/R/library'}" >> /usr/local/R/etc/Renviron

RUN if [ -z "$BUILD_DATE" ]; then MRAN=$CRAN; \
    else MRAN=https://mran.microsoft.com/snapshot/${BUILD_DATE}; fi \
    && echo MRAN=$MRAN >> /etc/environment \
    && echo "options(repos = c(CRAN='$MRAN'), download.file.method = 'libcurl')" >> /usr/local/R/etc/Rprofile.site \
    ## Use littler installation scripts
    && Rscript -e "install.packages(c('littler', 'docopt'), repo = '$CRAN')" \
    && ln -s /usr/local/R-${R_VERSION}/site-library/littler/examples/install2.r /usr/local/bin/install2.r \
    && ln -s /usr/local/R-${R_VERSION}/site-library/littler/examples/installGithub.r /usr/local/bin/installGithub.r \
    && ln -s /usr/local/R-${R_VERSION}/site-library/littler/bin/r /usr/local/bin/r \
    ## Clean up from R source install
    && cd / 

USER 1001

CMD ["R"]
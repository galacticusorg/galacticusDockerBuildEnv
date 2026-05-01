# Galacticus Docker image
# Uses Docker multi-stage build to build the build environment for Galacticus.

FROM ubuntu:latest AS build

ENV INSTALL_PATH=/usr/local
ENV GCC_MAJOR=12
ENV GCC_VERSION=12-20250702
ENV PATH=$INSTALL_PATH/gcc-$GCC_MAJOR/bin:$INSTALL_PATH/bin:$PATH
ENV LD_LIBRARY_PATH=$INSTALL_PATH/lib64:$INSTALL_PATH/lib:$INSTALL_PATH/gcc-$GCC_MAJOR/lib64:$INSTALL_PATH/gcc-$GCC_MAJOR/lib:/usr/lib/x86_64-linux-gnu
ENV LIBRARY_PATH=/usr/lib/x86_64-linux-gnu

# Create wrapper scripts for certain commands. These require us to unset LD_LIBRARY_PATH, otherwise they pick up libstdc++ from
# our GCC install and complain about it being out of date.
RUN echo '#!/bin/bash\nunset LD_LIBRARY_PATH\n/usr/bin/apt $@' > /usr/local/bin/apt && \
	chmod a+x /usr/local/bin/apt

RUN echo '#!/bin/bash\nunset LD_LIBRARY_PATH\n/usr/bin/apt-get $@' > /usr/local/bin/apt-get && \
	chmod a+x /usr/local/bin/apt-get

RUN echo '#!/bin/bash\nunset LD_LIBRARY_PATH\n/usr/bin/gs $@' > /usr/local/bin/gs && \
	chmod a+x /usr/local/bin/gs

RUN echo '#!/bin/bash\nunset LD_LIBRARY_PATH\n/usr/bin/python3 $@' > /usr/local/bin/python3-nolib && \
	chmod a+x /usr/local/bin/python3-nolib

# Install basic tools to allow us to download and build. Also remove tools we do not need to save space.
RUN apt -y update && \
    apt -y remove java-common ruby3.2 && \
    apt -y autoremove && \
    apt -y install wget make xz-utils bzip2 curl libcurl4-openssl-dev patch
# Set build options.
## We force use of the BFD linker here. The GCC in galacticus/buildenv:latest uses the gold linker by default. But, the gold
## linker seems to not correctly allow us to get values of some GSL constants (e.g. gsl_root_fsolver_brent) in Fortran.
ENV GALACTICUS_FCFLAGS="-fintrinsic-modules-path $INSTALL_PATH/finclude -fintrinsic-modules-path $INSTALL_PATH/include -fintrinsic-modules-path $INSTALL_PATH/include/gfortran -fintrinsic-modules-path $INSTALL_PATH/lib/gfortran/modules -L$INSTALL_PATH/lib -L$INSTALL_PATH/lib64 -fuse-ld=bfd -DTHREADSAFEIO"
ENV GALACTICUS_CFLAGS="-fuse-ld=bfd"
ENV GALACTICUS_CPPFLAGS="-fuse-ld=bfd"

# Ensure tzdata is installed and be sure to do it non-interactively otherwise is can ask for the timezone which will crash the build.
RUN     DEBIAN_FRONTEND="noninteractive" apt -y update
RUN     DEBIAN_FRONTEND="noninteractive" apt -y install tzdata

# Install a binary of gcc so we get a sufficiently current version.
RUN     cd $INSTALL_PATH &&\
	( wget https://gfortran.meteodat.ch/download/x86_64/snapshots/gcc-$GCC_VERSION.tar.xz || wget -c https://users.obs.carnegiescience.edu/abenson/galacticus/gcc-$GCC_VERSION.tar.xz ) &&\
	tar xf gcc-$GCC_VERSION.tar.xz &&\
	( wget http://gfortran.meteodat.ch/download/x86_64/gcc-infrastructure.tar.xz || wget -c https://users.obs.carnegiescience.edu/abenson/galacticus/gcc-infrastructure.tar.xz )  &&\
	tar xf gcc-infrastructure.tar.xz &&\
	rm gcc-$GCC_VERSION.tar.xz gcc-infrastructure.tar.xz
RUN     apt -y update && \
	apt -y install libblas-dev liblapack-dev binutils libc-dev gcc-multilib

# install GSL v2.6
RUN     apt -y update && \
	apt -y install texinfo
RUN     cd /opt &&\
 	wget ftp://ftp.gnu.org/gnu/gsl/gsl-2.6.tar.gz &&\
 	tar xvfz gsl-2.6.tar.gz &&\
 	cd gsl-2.6 &&\
 	./configure --prefix=$INSTALL_PATH &&\
 	make -j4 &&\
 	make check &&\
 	make install &&\
 	cd .. &&\
 	rm -rf gsl-2.6.tar.gz gsl-2.6
	
# install HDF5 v1.14.5
RUN     apt -y update && \
	apt -y install zlib1g-dev
RUN     cd /opt &&\
	wget https://support.hdfgroup.org/releases/hdf5/v1_14/v1_14_5/downloads/hdf5-1.14.5.tar.gz &&\
	tar -vxzf hdf5-1.14.5.tar.gz &&\
	cd hdf5-1.14.5 &&\
	F9X=gfortran ./configure --prefix=$INSTALL_PATH --enable-fortran --enable-build-mode=production &&\
	make -j4 &&\
	make install &&\
	cd .. &&\
	rm -rf hdf5-1.14.5.tar.gz hdf5-1.14.5
   
# install FoX v4.1.3
RUN     cd /opt &&\
	wget https://github.com/galacticusorg/fox/archive/refs/tags/v4.1.3.tar.gz &&\
	tar xvfz v4.1.3.tar.gz &&\
	cd fox-4.1.3 &&\
	FC=gfortran FCFLAGS="-fPIC -g" CFLAGS="-fPIC -g" ./configure &&\
	make -j4 &&\
	make install &&\
	cd .. &&\
	rm -rf xvfz v4.1.3.tar.gz fox-4.1.3
    
# install FFTW 3.3.4 (optional)
RUN     cd /opt &&\
	wget ftp://ftp.fftw.org/pub/fftw/fftw-3.3.4.tar.gz &&\
	tar xvfz fftw-3.3.4.tar.gz &&\
	cd fftw-3.3.4 &&\
	CFLAGS="-fPIC" FFLAGS="-fPIC" ./configure --prefix=$INSTALL_PATH &&\
	make -j4 &&\
	make install &&\
	cd .. &&\
	rm -rf xvfz fftw-3.3.4.tar.gz fftw-3.3.4
    
# install ANN 1.1.2 (optional)
RUN     cd /opt &&\
	wget http://www.cs.umd.edu/~mount/ANN/Files/1.1.2/ann_1.1.2.tar.gz &&\
	tar xvfz ann_1.1.2.tar.gz &&\
	cd ann_1.1.2 &&\
	sed -i~ -r s/"CFLAGS = \-O3"/"CFLAGS = \-O3 -fPIC"/ Make-config &&\
	make linux-g++  &&\
	cp bin/* $INSTALL_PATH/bin/. &&\
	cp lib/* $INSTALL_PATH/lib/. &&\
	cp -R include/* $INSTALL_PATH/include/. &&\
	cd .. &&\
	rm -rf ann_1.1.2.tar.gz ann_1.1.2

# install matheval v1.1.13 (optional)
RUN     apt -y update && \
	apt -y install bison flex guile-3.0 guile-3.0-dev gettext
RUN     cd /opt &&\
	wget https://github.com/galacticusorg/libmatheval/releases/download/latest/libmatheval-1.1.13.tar.gz &&\
	tar xvfz libmatheval-1.1.13.tar.gz &&\
	cd libmatheval-1.1.13 &&\
	CFLAGS="-I/usr/include/x86_64-linux-gnu -I/usr/include/guile/3.0" ./configure --prefix=$INSTALL_PATH/ &&\
	make -j4 &&\
	make install &&\
	cd .. &&\
	rm -rf libmatheval-1.1.13.tar.gz libmatheval-1.1.13

# install git
RUN     apt -y update && \
	apt -y install git libgit2-dev

# install latex and related tools
RUN     apt -y update && \
	apt -y install texlive texlive-latex-extra texlive-science texlive-extra-utils

# install OpenMPI
RUN     cd /opt &&\
	wget https://download.open-mpi.org/release/open-mpi/v1.10/openmpi-1.10.7.tar.bz2 &&\
	tar -vxjf openmpi-1.10.7.tar.bz2 &&\
	cd openmpi-1.10.7 &&\
	FC=gfortran ./configure --prefix=$INSTALL_PATH --enable-mpi-thread-multiple --disable-dlopen &&\
	make -j4 &&\
	make install &&\
	cd .. &&\
	rm -rf openmpi-1.10.7.tar.bz2 openmpi-1.10.7

# reduce security level of OpenSSL to allow communication with older servers
RUN     echo "openssl_conf = default_conf" > /opt/openssl.cnf &&\
	cat /etc/ssl/openssl.cnf >> /opt/openssl.cnf &&\
	echo "" >> /opt/openssl.cnf &&\
	echo "[ default_conf ]" >> /opt/openssl.cnf &&\
	echo "" >> /opt/openssl.cnf &&\
	echo "ssl_conf = ssl_sect" >> /opt/openssl.cnf &&\
	echo "" >> /opt/openssl.cnf &&\
	echo "[ssl_sect]" >> /opt/openssl.cnf &&\
	echo "" >> /opt/openssl.cnf &&\
	echo "system_default = system_default_sect" >> /opt/openssl.cnf &&\
	echo "" >> /opt/openssl.cnf &&\
	echo "[system_default_sect]" >> /opt/openssl.cnf &&\
	echo "MinProtocol = TLSv1.2" >> /opt/openssl.cnf &&\
	echo "CipherString = DEFAULT:@SECLEVEL=1" >> /opt/openssl.cnf &&\
	mv /opt/openssl.cnf /etc/ssl/openssl.cnf

# install tools needed for tests
RUN     apt -y update &&\
        DEBIAN_FRONTEND="noninteractive" apt -y install libxml2-utils

# install qhull library
ENV GALACTICUS_CPPFLAGS="$GALACTICUS_CPPFLAGS -I$INSTALL_PATH/include/libqhullcpp"
RUN     wget http://www.qhull.org/download/qhull-2020-src-8.0.2.tgz &&\
	tar xvfz qhull-2020-src-8.0.2.tgz &&\
	cd qhull-2020.2 &&\
	PREFIX=$INSTALL_PATH make &&\
	PREFIX=$INSTALL_PATH make install &&\
	cd .. &&\
	rm -rf qhull-2020.2 qhull-2020-src-8.0.2.tgz

# install Python and Python modules needed by Galacticus' build infrastructure, test suite, and analysis scripts.
# Note: `python3-h5py` pulls in the system HDF5 library; this is independent of our custom HDF5 install in $INSTALL_PATH which
# is what Galacticus itself links against.
RUN     apt -y update && \
        apt -y install python3-minimal python3-pip libhdf5-dev \
            python3-h5py python3-numpy python3-lxml python3-yaml python3-pytest \
            python3-requests python3-matplotlib python3-scipy python3-astropy \
            python3-termcolor python3-git
# Install Python packages not available in Debian repositories.
RUN     pip3 install --break-system-packages PyPDF2 num2tex colossus cusp_halo_relation

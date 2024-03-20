# Galacticus Docker image
# Uses Docker multi-stage build to build the build environment for Galacticus.

FROM ubuntu:latest as build

RUN apt -y update && \
    apt -y install wget make xz-utils bzip2

ENV INSTALL_PATH /usr/local
ENV GCC_MAJOR 12
ENV GCC_VERSION 12-20240315
ENV PATH $INSTALL_PATH/gcc-$GCC_MAJOR/bin:$INSTALL_PATH/bin:$PATH
ENV LD_LIBRARY_PATH $INSTALL_PATH/lib64:$INSTALL_PATH/lib:$INSTALL_PATH/gcc-$GCC_MAJOR/lib64:$INSTALL_PATH/gcc-$GCC_MAJOR/lib:/usr/lib/x86_64-linux-gnu
ENV LIBRARY_PATH /usr/lib/x86_64-linux-gnu

# Set build options.
## We force use of the BFD linker here. The GCC in galacticus/buildenv:latest uses the gold linker by default. But, the gold
## linker seems to not correctly allow us to get values of some GSL constants (e.g. gsl_root_fsolver_brent) in Fortran.
ENV GALACTICUS_FCFLAGS "-fintrinsic-modules-path $INSTALL_PATH/finclude -fintrinsic-modules-path $INSTALL_PATH/include -fintrinsic-modules-path $INSTALL_PATH/include/gfortran -fintrinsic-modules-path $INSTALL_PATH/lib/gfortran/modules -L$INSTALL_PATH/lib -L$INSTALL_PATH/lib64 -fuse-ld=bfd -DTHREADSAFEIO"
ENV GALACTICUS_CFLAGS "-fuse-ld=bfd"
ENV GALACTICUS_CPPFLAGS "-fuse-ld=bfd"

# Ensure tzdata is installed and be sure to do it non-interactively otherwise is can ask for the timezone which will crash the build.
RUN     DEBIAN_FRONTEND="noninteractive" apt -y update
RUN     DEBIAN_FRONTEND="noninteractive" apt -y install tzdata

# Install a binary of gcc so we get a sufficiently current version.
RUN     cd $INSTALL_PATH &&\
	wget https://gfortran.meteodat.ch/download/x86_64/snapshots/gcc-$GCC_VERSION.tar.xz &&\
	tar xf gcc-$GCC_VERSION.tar.xz &&\
	wget http://gfortran.meteodat.ch/download/x86_64/gcc-infrastructure.tar.xz &&\
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
	
# install HDF5 v1.8.20
RUN     apt -y update && \
	apt -y install zlib1g-dev
RUN     cd /opt &&\
	wget https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.8/hdf5-1.8.20/src/hdf5-1.8.20.tar.gz &&\
	tar -vxzf hdf5-1.8.20.tar.gz &&\
	cd hdf5-1.8.20 &&\
	F9X=gfortran ./configure --prefix=$INSTALL_PATH --enable-fortran --enable-production &&\
	make -j4 &&\
	make install &&\
	cd .. &&\
	rm -rf hdf5-1.8.20.tar.gz hdf5-1.8.20
   
# install FoX v4.1.0
RUN     cd /opt &&\
	wget https://github.com/andreww/fox/archive/4.1.0.tar.gz &&\
	tar xvfz 4.1.0.tar.gz &&\
	cd fox-4.1.0 &&\
	FC=gfortran FCFLAGS="-fPIC" CFLAGS="-fPIC" ./configure &&\
	make -j4 &&\
	make install &&\
	cd .. &&\
	rm -rf xvfz 4.1.0.tar.gz fox-4.1.0
    
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

# install guile v1.8.8 (optional)
RUN     apt -y update && \
	apt -y install libltdl-dev libgmp-dev
RUN	wget https://ftp.gnu.org/gnu/guile/guile-1.8.8.tar.gz &&\
	tar xvfz guile-1.8.8.tar.gz &&\
	cd guile-1.8.8 &&\
	CFLAGS=-I/usr/include/x86_64-linux-gnu ./configure --prefix=$INSTALL_PATH/ --disable-error-on-warning &&\
	make -j4 &&\
	make install &&\
	cd .. &&\
	rm -rf xvfz guile-1.8.8.tar.gz guile-1.8.8

# install matheval v1.1.12 (optional)
RUN     apt -y update && \
	apt -y install flex
RUN     cd /opt &&\
	wget https://github.com/galacticusorg/libmatheval/releases/download/latest/libmatheval-1.1.12.tar.gz &&\
	tar xvfz libmatheval-1.1.12.tar.gz &&\
	cd libmatheval-1.1.12 &&\
	CFLAGS=-I/usr/include/x86_64-linux-gnu ./configure --prefix=$INSTALL_PATH/ &&\
	make -j4 &&\
	make install &&\
	cd .. &&\
	rm -rf libmatheval-1.1.12.tar.gz libmatheval-1.1.12

# install Perl modules
RUN     apt -y update
RUN     apt -y install expat
RUN     apt -y install perl
RUN     apt -y install libyaml-perl libdatetime-perl libfile-slurp-perl liblatex-encode-perl libxml-simple-perl libxml-validator-schema-perl libxml-sax-perl libxml-sax-expat-perl libregexp-common-perl libfile-next-perl liblist-moreutils-perl libio-stringy-perl libclone-perl libfile-which-perl libwww-curl-perl libjson-pp-perl perl-doc libtext-bibtex-perl
# make a link to ParserDetails.ini - otherwise Perl seems unable to find it.
RUN     mkdir -p $INSTALL_PATH/share/perl/5.34.0/XML/SAX &&\
	cd $INSTALL_PATH/share/perl/5.34.0/XML/SAX &&\
	ln -sf /etc/perl/XML/SAX/ParserDetails.ini

ENV PERL_MM_USE_DEFAULT=1
RUN     perl -MCPAN -e 'force("install","Cwd")'
RUN     perl -MCPAN -e 'force("install","Data::Dumper")'
RUN     perl -MCPAN -e 'force("install","File::Copy")'
RUN     perl -MCPAN -e 'force("install","NestedMap")'
RUN     perl -MCPAN -e 'force("install","Scalar::Util")'
RUN     perl -MCPAN -e 'force("install","Term::ANSIColor")'
RUN     perl -MCPAN -e 'force("install","Text::Table")'
RUN     perl -MCPAN -e 'force("install","XML::SAX::ParserFactory")'
RUN     perl -MCPAN -e 'force("install","Text::Template")'
RUN     perl -MCPAN -e 'force("install","List::Uniq")'

# install git
RUN     apt -y update && \
	apt -y install git

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

# install PDL and other tools needed for tests
RUN     apt -y update &&\
        DEBIAN_FRONTEND="noninteractive" apt -y install pdl libpdl-stats-perl libpdl-linearalgebra-perl libsys-cpu-perl libio-compress-perl libcapture-tiny-perl gnuplot libxml2-utils libmime-lite-perl libdata-uuid-perl libcfitsio-dev libswitch-perl libwww-curl-perl libclass-date-perl
RUN     perl -MCPAN -e 'force("install","PDL::IO::HDF5")'
RUN     perl -MCPAN -e 'force("install","Imager::Color")'
RUN     perl -MCPAN -e 'force("install","Astro::Cosmology")'
RUN     perl -MCPAN -e 'force("install","Astro::FITS::CFITSIO")'
RUN     perl -MCPAN -e 'force("install","XML::LibXML::PrettyPrint")'
RUN     perl -MCPAN -e 'force("install","POSIX::strftime::GNU")'
RUN     perl -MCPAN -e 'force("install","Math::SigFigs")'
RUN     perl -MCPAN -e 'force("install","Image::ExifTool")'

# install qhull library
ENV GALACTICUS_CPPFLAGS "$GALACTICUS_CPPFLAGS -I$INSTALL_PATH/include/libqhullcpp"
RUN     wget http://www.qhull.org/download/qhull-2020-src-8.0.2.tgz &&\
	tar xvfz qhull-2020-src-8.0.2.tgz &&\
	cd qhull-2020.2 &&\
	PREFIX=$INSTALL_PATH make &&\
	PREFIX=$INSTALL_PATH make install &&\
	cd .. &&\
	rm -rf qhull-2020.2 qhull-2020-src-8.0.2.tgz

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

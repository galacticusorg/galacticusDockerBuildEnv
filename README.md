# Docker Build Environment for Galacticus

![](https://img.shields.io/docker/cloud/automated/galacticusorg/buildenv) ![](https://img.shields.io/docker/cloud/build/galacticusorg/buildenv)

A Docker container providing a build environment for the [Galacticus](https://github.com/galacticusorg/galacticus) galaxy formation model. It provides all compilers, libraries, and tools for compiling Galacticus from source.

## Quick Start

The following instructions show how to build Galacticus using this Docker container.

* Pre-requisite: you must have a [Docker](https://www.docker.com/) engine installed and running on your system

* Download the Galacticus Build Environment image from the Docker repository:
  * `docker pull galacticusorg/buildenv:latest`
  
* Start a container from the image:
  * `docker run --rm --name buildenv -it galacticusorg/buildenv:latest bash`

* Once inside the container, you can clone the Galacticus repos and compile (this will take a while, maybe 30 minutes), for example:
```
export GALACTICUS_EXEC_PATH=/opt/galacticus
export GALACTICUS_DATA_PATH=/opt/datasets
cd /opt
git clone https://github.com/galacticusorg/galacticus.git galacticus
git clone https://github.com/galacticusorg/datasets.git
cd /opt/galacticus
make -j4 Galacticus.exe
```

* Try running a simple model to check everything works:
  * `Galacticus.exe parameters/quickTest.xml`

* You can exit the container, but note that this will lose all of your work.
  * `exit`

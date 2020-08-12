#!/bin/bash
# Copyright 2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance with the License. A copy of the License is located at
#
# http://aws.amazon.com/apache2.0/
#
# or in the "LICENSE.txt" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or implied. See the License for the specific language governing permissions and limitations under the License.

set -e

WORK_DIR=`mktemp -d`
DEFAULT_CONDA_PREFIX="/shared/conda"
export CONDA_ALWAYS_YES="true"

# If path was not specified, used default conda prefix
if [[ $# -eq 1 ]]; then
  CONDA_PREFIX=$1
else
  CONDA_PREFIX=$DEFAULT_CONDA_PREFIX
fi

if [ -d "$CONDA_PREFIX" ]; then
  >&2 echo "$CONDA_PREFIX already exists"
  exit 1
fi

pushd $PWD

# Install conda environment and activate
cd $WORK_DIR
wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-py37_4.8.3-Linux-x86_64.sh
bash Miniconda3-py37_4.8.3-Linux-x86_64.sh -b -p $CONDA_PREFIX
source $CONDA_PREFIX/bin/activate

# Install CUDA
conda install cudatoolkit-dev=10.0 -c conda-forge

# Install NCCL
cd $WORK_DIR
git clone https://github.com/NVIDIA/nccl.git -b v2.6.4-1
# AWS OFI NCCL Plugin is compatible with this version of NCCL as of 6/1/2020.
cd nccl
make -j64 src.build CUDA_HOME=$CONDA_PREFIX NVCC_GENCODE="-gencode=arch=compute_70,code=sm_70"
make pkg.txz.build
tar xvf build/pkg/txz/nccl_*.txz -C $CONDA_PREFIX --strip-components=1

# Install AWS OFI NCCL Plugin
cd $WORK_DIR
git clone https://github.com/aws/aws-ofi-nccl.git -b v1.0.1-aws
cd aws-ofi-nccl
# This is a temporary workaround to hardcode this commit to avoid changes to aws branch causing issues
./autogen.sh
./configure --with-libfabric=/opt/amazon/efa/ --with-cuda=$CONDA_PREFIX --with-nccl=$CONDA_PREFIX --with-mpi=/opt/amazon/openmpi --prefix=$CONDA_PREFIX
make
make install

# Install cmake
pip install cmake

pip install toposort networkx pytest nltk tqdm html2text progressbar
pip --no-cache-dir --no-cache install git+https://github.com/NVIDIA/dllogger

#Install TF
pip install tensorflow-gpu==1.14

export PATH=/opt/amazon/openmpi/bin:$PATH
export LD_LIBRARY_PATH=/opt/amazon/openmpi/lib:$LD_LIBRARY_PATH

HOROVOD_CUDA_HOME=/shared/conda HOROVOD_NCCL_HOME=/shared/conda HOROVOD_GPU_ALLREDUCE=NCCL  HOROVOD_WITH_TENSORFLOW=1 pip install --no-cache-dir horovod

# Install MPI4PY
pip install mpi4py

rm -rf $WORK_DIR

popd

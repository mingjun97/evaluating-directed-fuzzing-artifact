#!/bin/bash

set -e

export NO_CORESIGHT=1
export NO_NYX=1
export LLVM_VERSION=14
export GCC_VERSION=10
export DEBIAN_FRONTEND=noninteractive
export NO_ARCH_OPT=1
export IS_DOCKER=1
export LLVM_CONFIG=llvm-config-${LLVM_VERSION}
export AFL_SKIP_CPUFREQ=1
export AFL_TRY_AFFINITY=1
export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1

apt-get update && apt-get full-upgrade -y && \
    apt-get install -y --no-install-recommends wget ca-certificates apt-utils && \
    rm -rf /var/lib/apt/lists/*

echo "deb [signed-by=/etc/apt/keyrings/llvm-snapshot.gpg.key] http://apt.llvm.org/focal/ llvm-toolchain-focal-${LLVM_VERSION} main" > /etc/apt/sources.list.d/llvm.list
wget -qO /etc/apt/keyrings/llvm-snapshot.gpg.key https://apt.llvm.org/llvm-snapshot.gpg.key

apt-get update && \
    apt-get -y install --no-install-recommends \
    make cmake automake meson ninja-build bison flex \
    git xz-utils bzip2 wget jupp nano bash-completion less vim joe ssh psmisc \
    python3 python3-dev python3-pip python-is-python3 \
    libtool libtool-bin libglib2.0-dev \
    apt-transport-https gnupg dialog \
    gnuplot-nox libpixman-1-dev bc \
    gcc-${GCC_VERSION} g++-${GCC_VERSION} gcc-${GCC_VERSION}-plugin-dev gdb lcov \
    clang-${LLVM_VERSION} clang-tools-${LLVM_VERSION} libc++1-${LLVM_VERSION} \
    libc++-${LLVM_VERSION}-dev libc++abi1-${LLVM_VERSION} libc++abi-${LLVM_VERSION}-dev \
    libclang1-${LLVM_VERSION} libclang-${LLVM_VERSION}-dev \
    libclang-common-${LLVM_VERSION}-dev libclang-rt-${LLVM_VERSION}-dev libclang-cpp${LLVM_VERSION} \
    libclang-cpp${LLVM_VERSION}-dev liblld-${LLVM_VERSION} \
    liblld-${LLVM_VERSION}-dev liblldb-${LLVM_VERSION} liblldb-${LLVM_VERSION}-dev \
    libllvm${LLVM_VERSION} libomp-${LLVM_VERSION}-dev libomp5-${LLVM_VERSION} \
    lld-${LLVM_VERSION} lldb-${LLVM_VERSION} llvm-${LLVM_VERSION} \
    llvm-${LLVM_VERSION}-dev llvm-${LLVM_VERSION}-runtime llvm-${LLVM_VERSION}-tools \
    $([ "$(dpkg --print-architecture)" = "amd64" ] && echo gcc-${GCC_VERSION}-multilib gcc-multilib) \
    $([ "$(dpkg --print-architecture)" = "arm64" ] && echo libcapstone-dev) && \
    rm -rf /var/lib/apt/lists/*

update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-${GCC_VERSION} 0
update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-${GCC_VERSION} 0
update-alternatives --install /usr/bin/clang clang /usr/bin/clang-${LLVM_VERSION} 0
update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-${LLVM_VERSION} 0

wget -qO- https://sh.rustup.rs | CARGO_HOME=/etc/cargo sh -s -- -y -q --no-modify-path
export PATH=$PATH:/etc/cargo/bin

apt-get clean -y

git clone --depth=1 https://github.com/vanhauser-thc/afl-cov /benchmark/tool-script/afl-cov/
wget https://github.com/AFLplusplus/AFLplusplus/archive/refs/tags/v4.10c.tar.gz && \
    tar zxf v4.10c.tar.gz && rm v4.10c.tar.gz && \
    mv AFLplusplus-4.10c /fuzzer/AFLplusplus


cd /benchmark/tool-script/afl-cov/
make install

cd /fuzzer/AFLplusplus
make clean
make distrib
make install

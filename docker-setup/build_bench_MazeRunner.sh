#!/bin/bash

. $(dirname $0)/build_bench_common.sh

# arg1 : Target project
# arg2~: Fuzzing targets
function build_with_MazeRunner() {
    for TARG in "${@:2}"; do
        str_array=($TARG)
        BIN_NAME=${str_array[0]}
        # make sure ko-clang-fast wraps clang-12
        CC="/fuzzer/symsan/build/bin/ko-clang"
        CXX="/fuzzer/symsan/build/bin/ko-clang++"
        TMP_DIR=/benchmark/temp_$1

        export KO_CC="clang-12"
        export KO_CXX="clang++-12"
        export KO_ADD_AFLGO=1
        export KO_DONT_OPTIMIZE=1
        export KO_USE_FASTGEN=1
        export KO_NO_NATIVE_ZLIB=1
        export LDFLAGS="-ldl -lutil"

        for BUG_NAME in "${str_array[@]:1}"; do
            ### Draw CFG and CG with BBtargets
            mkdir -p $TMP_DIR
            ### Build with distance info, with ASAN disabled
            cd /benchmark
            cp /benchmark/static_analysis_results/${BIN_NAME}-${BUG_NAME}/* $TMP_DIR/

            rm -rf /benchmark/RUNDIR-$1
            export AFLGO_TARGET_DIR=$TMP_DIR
            unset AFLGO_PREPROCESSING
            build_target $1 $CC $CXX ""

            ### copy results
            copy_build_result $1 $BIN_NAME $BUG_NAME "SymSan"
            rm -rf /benchmark/RUNDIR-$1

            ### Cleanup
            rm -rf $TMP_DIR
        done
    done
}

# Build with MazeRunner
mkdir -p /benchmark/bin/MazeRunner
build_with_MazeRunner "libming-4.7" \
    "swftophp 2016-9827 2016-9829 2016-9831 2017-9988 2017-11728 2017-11729" &
build_with_MazeRunner "binutils-2.26" \
    "cxxfilt 2016-4487 2016-4489 2016-4490 2016-4491 2016-4492 2016-6131" &

wait

cp /benchmark/bin/MazeRunner/cxxfilt-2016-4492 /benchmark/bin/MazeRunner/cxxfilt-2016-4492-crash1

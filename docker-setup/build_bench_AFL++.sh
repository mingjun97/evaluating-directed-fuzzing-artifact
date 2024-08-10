#!/bin/bash

. $(dirname $0)/build_bench_common.sh

# arg1 : Target project
# arg2~: Fuzzing targets
function build_with_AFLPP() {
    for TARG in "${@:2}"; do
        str_array=($TARG)
        BIN_NAME=${str_array[0]}

        cd /benchmark
        export AFLPP="/fuzzer/AFLplusplus"
        export CC="${AFLPP}/afl-clang-fast"
        export CXX="${AFLPP}/afl-clang-fast++"

        build_target $1 $CC $CXX " "

        for BUG_NAME in "${str_array[@]:1}"; do
            copy_build_result $1 $BIN_NAME $BUG_NAME "AFL++"
        done

        rm -rf /benchmark/RUNDIR-$1
    done
}

# Build with AFL++
mkdir -p /benchmark/bin/AFL++
build_with_AFLPP "libming-4.7" \
    "swftophp 2016-9827 2016-9829 2016-9831 2017-9988 2017-11728 2017-11729" &
build_with_AFLPP "binutils-2.26" \
    "cxxfilt 2016-4487 2016-4489 2016-4490 2016-4491 2016-4492 2016-6131 \
             2016-4492-crash2" &

wait

cp /benchmark/bin/AFL++/cxxfilt-2016-4492 /benchmark/bin/AFL++/cxxfilt-2016-4492-crash1

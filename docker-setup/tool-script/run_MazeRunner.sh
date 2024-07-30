#!/bin/bash

FUZZER_NAME='MazeRunner'

AFLGO_BIN=/box/${1}_aflgo
SYMSAN_BIN=/box/${1}_symsan
ATAT=$2
TARGET_DIR=/benchmark/static_analysis_results/${1}

export AFL_HANG_TMOUT=1000
export AFL_SKIP_CPUFREQ=1
export AFL_NO_AFFINITY=1
export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
ulimit -c 0

. $(dirname $0)/common-setup.sh

ulimit -c 0
mkdir output

if [[ ${1} == swftophp* ]]; then
  pushd /fuzzer/symsan/mazerunner
  git apply /tool-script/use_built_in_solver.patch
  popd
fi

nohup timeout 4h \
  /fuzzer/symsan/mazerunner/mazerunner.py \
  -a explore -n mazerunner -i seed -m reachability -o output -s $TARGET_DIR -- $SYMSAN_BIN $ATAT \
  > output/mazerunner.log 2>&1 &
sleep 20s
nohup timeout $4 \
  /fuzzer/AFLGo/afl-fuzz \
  $DICT_OPT -S aflgo -t 2000+ -m none -z exp -c 4h -i output/mazerunner/queue -o output -- $AFLGO_BIN $ATAT \
  > output/aflgo.log 2>&1 &

mkdir output/crashes
sleep $4
echo "FINISHED" > /STATUS
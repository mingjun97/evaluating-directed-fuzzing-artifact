#!/bin/bash

FUZZER_NAME='MazeRunner'
. $(dirname $0)/common-setup.sh

ulimit -c 0
export AFL_SKIP_CPUFREQ=1
export AFL_NO_AFFINITY=1
export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1

# Set exploitation time as 7/8 of 24 hours.
nohup timeout $4 nice -n 10 /fuzzer/AFLGo++/afl-2.57b/afl-fuzz \
  $DICT_OPT -S aflgo -t 2000+ -m none -d -z exp -c 21h -i seed -o output -- $AFLGO_BIN \
  > output/aflgo.log 2>&1 &
nohup timeout $4 nice -n 0 /fuzzer/symsan/mazerunner/mazerunner.py -a explore -f aflgo -m reachability -o output -s $TARGET_DIR -- $SYMSAN_BIN
  > output/mazerunner.log 2>&1 &

mkdir output/crashes
sleep $4
echo "FINISHED" > /STATUS
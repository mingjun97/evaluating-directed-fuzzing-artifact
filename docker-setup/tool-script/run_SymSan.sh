#!/bin/bash

FUZZER_NAME='SymSan'

AFLGO_BIN=/box/${1}_aflgo++
SYMSAN_BIN=/box/${1}_symsan
ATAT=$2
TARGET_DIR=/benchmark/static_analysis_results/${1}

. $(dirname $0)/common-setup.sh

ulimit -c 0
mkdir output

# Set exploitation time as 7/8 of 24 hours.
nohup timeout $4 nice -n 0 \
  /fuzzer/AFLGo++/afl-2.57b/afl-fuzz \
  $DICT_OPT -S aflgo -t 2000+ -m none -z exp -c 21h -i seed -o output -- $AFLGO_BIN $ATAT \
  > output/aflgo.log 2>&1 &
nohup timeout $4 nice -n 0 \
  /fuzzer/symsan/mazerunner/mazerunner.py \
  -a symsan -f aflgo -m reachability -o output -s $TARGET_DIR -- $SYMSAN_BIN $ATAT \
  > output/symsan.log 2>&1 &

mkdir output/crashes
sleep $4
echo "FINISHED" > /STATUS

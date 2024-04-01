#!/bin/bash

# Replay newly found crash inputs
README="output/crashes/README.txt"
if [ -f "$README" ]; then
    rm $README
fi
CRASH_LIST=$(ls output/crashes) || exit 1
crash=$4
# During the replay, set the following ASAN_OPTIONS again.
export ASAN_OPTIONS=allocator_may_return_null=1,detect_leaks=0

cp -f /benchmark/bin/ASAN/$1 ./$1
START_TIME=$(stat -c%Y .start)
DIFF_TIME=$(echo `stat -c%Y output/crashes/${crash}` - $START_TIME | bc)
readarray -d , -t CRASH_ID <<<$crash
echo -e "\nReplaying crash - ${CRASH_ID[0]} (found at ${DIFF_TIME} sec.):" >> output/replay_log.txt
if [[ $3 == "stdin" ]]; then
    cat output/crashes/$crash | timeout -k 30 15 ./$1 $2 2>> output/replay_log.txt
elif [[ $3 == "file" ]]; then
    cp -f output/crashes/$crash ./@@
    timeout -k 30 15 ./$1 $2 2>> output/replay_log.txt
else
    echo "Invalid input source: $3"
    exit 1
fi

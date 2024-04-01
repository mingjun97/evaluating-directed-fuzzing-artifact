#!/bin/bash

# Replay newly found crash inputs
rm output/crashes/README.txt
CRASH_LIST=$(ls output/crashes)

# During the replay, set the following ASAN_OPTIONS again.
export ASAN_OPTIONS=allocator_may_return_null=1,detect_leaks=0

cp -f /benchmark/bin/ASAN/$1 ./$1
echo "Crash Replay log for ${1}" > output/replay_log.txt

for crash in $CRASH_LIST; do
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
done

# Copy the output directory to the path visible by the host.
cp -r output /output

# Notify that the whole fuzzing campaign has successfully finished.
echo "FINISHED" > /STATUS

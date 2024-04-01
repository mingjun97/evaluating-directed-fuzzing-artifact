#!/bin/bash

# replay.sh <targ_prog> <cmdline> <src> <patch versions>
# legal patch versions: a, b, orig, default

README="output/crashes/README.txt"
if [ -f "$README" ]; then
    rm $README
fi
CRASH_LIST=$(ls output/crashes) || exit 1
# During the replay, set the following ASAN_OPTIONS again.
export ASAN_OPTIONS=allocator_may_return_null=1,detect_leaks=0

TARG=$1
VERS=($4)
crash=$5

for VER in ${VERS[@]}; do 
    if [[ $VER == "orig" ]]; then
        PATCHED=/benchmark/bin/ASAN/$1
        LOG=output/replay_log_orig.txt
    elif [[ $VER == "default" ]]; then
        PATCHED=/benchmark/bin/patched/$1
        LOG=output/replay_log_patch.txt
    else
        PATCHED=/benchmark/bin/patched/$1-$VER
        LOG=output/replay_log_patch_$VER.txt
    fi

    readarray -d , -t CRASH_ID <<< $crash
    echo -e "\nReplaying crash - ${CRASH_ID[0]} :" >> $LOG
    if [[ $3 == "stdin" ]]; then
        cat output/crashes/$crash | timeout -k 30 30 $PATCHED 2>> $LOG
        if [[ $? -eq 124 ]]; then
            echo "TIMEOUT" >> $LOG
        fi
    elif [[ $3 == "file" ]]; then
        cp -f output/crashes/$crash ./@@
        timeout -k 30 30 $PATCHED $2 2>> $LOG
        if [[ $? -eq 124 ]]; then
            echo "TIMEOUT" >> $LOG
        fi
    else
        echo "Invalid input source: $3"
        exit 1
    fi
done
#! /usr/bin/env python3

import subprocess
import os
import sys
import time

from parse_result import parse_tte, parse_found_time
from common import csv_write_row

# Directory paths and execution settings
crash_dir = "/box/output/crashes"
status_file = "/STATUS"

def monitor_crashes():
    try:
        os.remove(f"{crash_dir}/README.txt")
    except FileNotFoundError:
        pass
    processed = set()
    while True:
        current_crashes = set(os.listdir(crash_dir))
        new_crashes = current_crashes - processed
        for crash in new_crashes:
            if not 'id:' in crash:
                continue
            if is_CVE_triggered(crash):
                print(f"[*] CVE discovered by {crash}")
                mark_cve_discovered()
                return
        processed.update(new_crashes)
        time.sleep(60)

def run_cmd(cmd):
    print(f"[*] Executing: {cmd}")
    subprocess.run(cmd, shell=True)

def is_CVE_triggered(crash_file):
    # run common-postproc-single.sh
    cmd = "cd /box && /tool-script/common-postproc-single.sh "
    cmd += f"\"{targ_prog}\" \"{cmdline}\" \"{src}\" \"{crash_file}\""
    run_cmd(cmd)
    target_tool = "%s-%s" % (targ_prog, tool)
    targ_dir = "/box/output"
    store_replay_outputs(target_tool, targ_dir)
    # run replay-single.sh
    patch_vers = "default"
    cmd = "cd /box && /tool-script/replay-single.sh "
    cmd += f"\"{targ_prog}\" \"{cmdline}\" \"{src}\" \"{patch_vers}\" \"{crash_file}\""
    run_cmd(cmd)
    # Determine if the crash is due to a CVE based on output or error comparison
    tte = parse_tte(target_tool, targ_dir, "patch")
    if not tte is None:
        return True
    return False

def mark_cve_discovered():
    with open(status_file, "w") as f:
        f.write("FINISHED")

def store_replay_outputs(target_tool, outdir):
    log_file = os.path.join(outdir, "replay_log.txt")
    time_list = parse_found_time(log_file)
    found_time_file = os.path.join(outdir, "found_time.csv")
    csv_write_row(found_time_file, time_list, append=True)

if __name__ == "__main__":
    global tool, targ_prog, cmdline, src, timelimit, iter_id
    if len(sys.argv) < 5:
        exit(1)
    tool = sys.argv[1]
    targ_prog = sys.argv[2]
    cmdline = sys.argv[3]
    src = sys.argv[4]
    timelimit = int(sys.argv[5])
    iter_id = sys.argv[6]
    monitor_crashes()
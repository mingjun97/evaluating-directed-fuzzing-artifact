import os, subprocess, csv
import time

# TODO: Move to a separate file for configuration.
LOGICAL_CPU_NUM = 72
MAX_INSTANCE_NUM = 35
MEM_PER_INSTANCE = 4

START_CMD = 'docker start %s'
RM_CMD = 'docker rm %s'
WAIT_CMD = 'docker wait %s'
KILL_CMD = 'docker kill %s'
STOP_CMD = 'docker stop %s'

def kill_container(task):
    targ_prog, cmdline, src, iter_id = task
    container = "%s-%s" % (targ_prog, iter_id)
    cmd = KILL_CMD % container
    run_cmd(cmd)
    time.sleep(10)

def stop_container(task):
    targ_prog, cmdline, src, iter_id = task
    container = "%s-%s" % (targ_prog, iter_id)
    cmd = STOP_CMD % container
    run_cmd(cmd)
    time.sleep(10)

def remove_container(task):
    targ_prog, cmdline, src, iter_id = task
    container = "%s-%s" % (targ_prog, iter_id)
    cmd = RM_CMD % container
    run_cmd(cmd)    
    time.sleep(10)

def resume_container(conf, task):
    targ_prog, cmdline, src, iter_id = task
    container = "%s-%s" % (targ_prog, iter_id)
    cmd = START_CMD % container
    run_cmd(cmd)
    time.sleep(10)

def run_cmd(cmd_str):
    print("[*] Executing: %s" % cmd_str)
    cmd_args = cmd_str.split()
    try:
        PIPE = subprocess.PIPE
        p = subprocess.Popen(cmd_args, stdin=PIPE, stdout=PIPE, stderr=PIPE)
        output, err = p.communicate()
        return output
    except Exception as e:
        print(e)
        exit(1)


def run_cmd_in_docker(container, cmd_str, is_detached):
    print("[*] Executing '%s' in container %s" % (cmd_str, container))
    exec_flag = "-d" if is_detached else ""
    cmd_prefix = "docker exec %s %s /bin/bash -c" % (exec_flag, container)
    cmd_args = cmd_prefix.split()
    cmd_args += [cmd_str]
    try:
        PIPE = subprocess.PIPE
        p = subprocess.Popen(cmd_args, stdin=PIPE, stdout=PIPE, stderr=PIPE)
        output, err = p.communicate()
        return str(output)
    except Exception as e:
        print(e)
        exit(1)


def check_cpu_count():
    n_str = run_cmd("nproc")
    try:
        if int(n_str) < MAX_INSTANCE_NUM:
            print("Not enough CPU cores, please decrease MAX_INSTANCE_NUM")
            exit(1)
    except Exception as e:
        print(e)
        print("Failed to count the number of CPU cores, abort")
        exit(1)


def fetch_works(worklist):
    works = []
    for i in range(MAX_INSTANCE_NUM):
        if len(worklist) <= 0:
            break
        works.append(worklist.pop(0))
    return works


def csv_read(filename):
    f = open(filename, 'r', newline='')
    reader = csv.reader(f)
    rows = []
    for row in reader:
        rows.append(list(row))
    return rows


def csv_write_row(filename, data, append=False):
    mode = 'a' if append else 'w'
    f = open(filename, mode, newline='')
    writer = csv.writer(f)
    writer.writerow(data)
    f.close()

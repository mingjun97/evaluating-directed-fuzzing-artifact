from concurrent.futures import ThreadPoolExecutor, as_completed
import queue
import sys, os, time, csv, shutil
from common import *
from benchmark import generate_fuzzing_worklist, generate_replay_worklist, FUZZ_TARGETS, EXP_ENV
from replay import run_replay
from parse_result import print_result, parse_found_time
from plot import draw_result
import copy

BASE_DIR = os.path.join(os.path.dirname(__file__), os.pardir)
IMAGE_NAME = "prosyslab/directed-fuzzing-benchmark"
SUPPORTED_TOOLS = \
  [ "AFLGo", "Beacon", "WindRanger","SelectFuzz", "DAFL" ]
FIGURES_AND_TABLES = [
    "table3", "table4", "table5", "table6", "table7", "table8", "table9", "table9-minimal",
    "figure6", "figure7"
]


def decide_outdir(isReproduce, target, tool):
    name = "%s-%ssec-%siters" % (target, timelimit, iteration)
    if isReproduce:
        outdir = os.path.join(BASE_DIR, "output", "origin")
    elif tool == "":
        outdir = os.path.join(BASE_DIR, "output", target)
    else:
        outdir = os.path.join(BASE_DIR, "output", target, tool)
    os.makedirs(outdir, exist_ok=True)
    return outdir


def start_container(work, i):
    targ_prog, _, _, iter_id = work
    cmd = "docker run --tmpfs /box:exec -m=%dg --cpuset-cpus=%d,%d -it -d --name %s-%s %s" \
            % (MEM_PER_INSTANCE, i, i + LOGICAL_CPU_NUM/2,targ_prog, iter_id, IMAGE_NAME)
    run_cmd(cmd)
    time.sleep(10)

def spawn_replay_containers(works, outdir, tool):
    for i in range(len(works)):
        targ_prog, _, _, iter_id = works[i]
        target_tool = "%s-%s" % (targ_prog, tool)
        fuzz_result_dir = os.path.join(outdir, target_tool,
                                       f"{targ_prog}-{iter_id}")
        cmd = "docker run --tmpfs /box:exec --rm -v%s:/output -m=%dg --cpuset-cpus=%d -it -d --name %s-%s %s" \
                % (fuzz_result_dir, MEM_PER_INSTANCE, i, targ_prog, iter_id, IMAGE_NAME)
        run_cmd(cmd)


def run_fuzzing(work, tool, timelimit):
    targ_prog, cmdline, src, iter_id = work
    cmd = "/tool-script/run_%s.sh %s \"%s\" %s %d" % \
            (tool, targ_prog, cmdline, src, timelimit)
    run_cmd_in_docker("%s-%s" % (targ_prog, iter_id), cmd, True)
    time.sleep(10)


def wait_finish(work, timelimit):
    elapsed_t= 0
    while elapsed_t < timelimit:
        time.sleep(60)
        elapsed_t += 60
        targ_prog, _, _, iter_id = work
        container = "%s-%s" % (targ_prog, iter_id)
        stat_str = run_cmd_in_docker(container, "cat /STATUS", False)
        if "FINISHED" in stat_str:
            print("%s-%s has finished" % (targ_prog, iter_id))
            break
    stop_container(work)
    resume_container(work)

def store_outputs(work, outdir, tool):
    targ_prog, cmdline, src, iter_id = work
    target_tool = "%s-%s" % (targ_prog, tool)
    if not os.path.exists(os.path.join(outdir, target_tool)):
        os.makedirs(os.path.join(outdir, target_tool), exist_ok=True)
    # Clean up potential previous results
    container = "%s-%s" % (targ_prog, iter_id)
    container_outdir = os.path.join(outdir, target_tool, container)
    if os.path.exists(container_outdir):
        shutil.rmtree(container_outdir)
    cmd = "docker cp %s:/output %s" % (container, container_outdir)
    run_cmd(cmd)


def store_replay_outputs(work, outdir, tool):
    targ_prog, cmdline, src, iter_id = work
    target_tool = "%s-%s" % (targ_prog, tool)
    log_file = os.path.join(outdir, target_tool, f"{targ_prog}-{iter_id}",
                            "replay_log.txt")
    time_list = parse_found_time(log_file)
    found_time_file = os.path.join(outdir, target_tool,
                                    f"{targ_prog}-{iter_id}",
                                    "found_time.csv")
    csv_write_row(found_time_file, time_list)


def cleanup_container(work):
    kill_container(work)
    remove_container(work)


def run_experiment(task, action, timelimit, outdir_data, cpu_queue):
    if action == "run":
        # if os.path.isfile(os.path.join(maze_out_path, 'outputs', '.done')):
        #     print(f"Skipping {tool}-{epoch} for {maze} as it already exists\n")
        #     return
        # elif os.path.isdir(maze_out_path):
        #     print(f"removing {maze_out_path} because .done file is missing")
        #     try:
        #         shutil.rmtree(maze_out_path)
        #     except Exception as e:
        #         print(f"Error removing directory {maze_out_path}: {e}")
        print(f"[*] Run Fuzzing for {task}")
        work, tool = task[:-1], task[-1]
        cpu_id = cpu_queue.get()
        start_container(work, cpu_id)
        run_fuzzing(work, tool, timelimit)
        wait_finish(work, timelimit)
        store_outputs(work, outdir_data, tool)
        cleanup_container(work)
        cpu_queue.put(cpu_id)


def main():

    if len(sys.argv) < 2:
        print(
            "Usage: %s <run/draw> <table/figure/target name> ( <time> <iterations> \"<tool list>\" )"
            % sys.argv[0])
        exit(1)
    action = sys.argv[1]
    target = sys.argv[2]

    if target in FIGURES_AND_TABLES:
        timelimit = EXP_ENV["TIMELIMTS"][target]
        iteration = EXP_ENV["ITERATIONS"][target]
        tools = EXP_ENV["TOOLS"][target]
        target_list = EXP_ENV["TARGETS"][target]
        patch_vers = EXP_ENV["PATCH_VERSIONS"][target]
    else:
        if target not in [x for (x, y, z, w) in FUZZ_TARGETS]:
            print("Invalid target! \n \
                Choose from [table3, table4, table5, table6, table7, table8, table9, figure6, figure7] or give a valid custom target"
                  )
            exit(1)

        if len(sys.argv) < 5:
            timelimit = EXP_ENV["TIMELIMTS"]["custom"]
            iteration = EXP_ENV["ITERATIONS"]["custom"]
            tools = EXP_ENV["TOOLS"]["custom"]
        else:
            EXP_ENV["TIMELIMTS"]["custom"] = timelimit = int(sys.argv[3])
            EXP_ENV["ITERATIONS"]["custom"] = iteration = int(sys.argv[4])
            EXP_ENV["TOOLS"]["custom"] = tools = sys.argv[5].split()
        EXP_ENV["TARGETS"]["custom"] = target_list = [target]
        # For now, do not receive patch versions for custom targets
        patch_vers = EXP_ENV["PATCH_VERSIONS"]["custom"]

    check_cpu_count()

    # Set output directory
    ## set and make data directory for fuzzing output.
    ## if action is draw-original, set data directory for original data
    if action == "draw-original":
        outdir_data = os.path.join(BASE_DIR, "output", "original_data")
    else:
        outdir_data = os.path.join(BASE_DIR, "output", "data")
        os.makedirs(outdir_data, exist_ok=True)
    ## set and make result directory for figures and tables
    outdir_result = os.path.join(BASE_DIR, "output", target)
    os.makedirs(outdir_result, exist_ok=True)

    worklist = generate_fuzzing_worklist(target_list, iteration)
    targets = []
    for tool in tools:
        for w in worklist:
            targets.append(w + (tool,))
    
    cpu_queue = queue.Queue()
    for i in range(MAX_INSTANCE_NUM):
        cpu_queue.put(i)
    
    with ThreadPoolExecutor(max_workers=MAX_INSTANCE_NUM) as executor:
        futures = [executor.submit(run_experiment, t, action, timelimit, outdir_data, cpu_queue) for t in targets]
        for future in as_completed(futures):
            future.result()

    # Parse and print results in CSV format
    print("[*] Parse and print results in CSV format")
    print_result(outdir_data, outdir_result, target, tools, target_list)

    # Draw figure from CSV file
    if "figure" in target:
        print("[*] Draw target")
        draw_result(outdir_data, outdir_result, target)

if __name__ == "__main__":
    main()

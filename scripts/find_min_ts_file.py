#! /usr/bin/python3
import os
import sys

def find_min_ts(target_directory):
    min_ts_value = float('inf')
    min_ts_file = None

    for filename in os.listdir(target_directory):
        if filename.startswith('id:') and filename.endswith('dis:0'):
            ts_value = float(filename.split(',')[2].split(':')[1])/1000
            if ts_value < min_ts_value:
                min_ts_value = ts_value
                min_ts_file = filename

    return min_ts_file, min_ts_value

def process_experiment(base_directory):
    iterations = [f'iter-{i}' for i in range(10)]
    ts_values = []

    for iteration in iterations:
        iter_directory = os.path.join(base_directory, iteration, 'mazerunner', 'queue')
        if os.path.exists(iter_directory):
            min_ts_file, min_ts_value = find_min_ts(iter_directory)
            if min_ts_file:
                print(f'{base_directory}/{iteration}: {min_ts_file}')
                ts_values.append(min_ts_value)

    if ts_values:
        average_ts = sum(ts_values) / len(ts_values)
        print(f'Average ts for {base_directory}: {average_ts}')
    else:
        print(f'No valid ts values found for {base_directory}')

def main(base_directory):
    for experiment in os.listdir(base_directory):
        experiment_directory = os.path.join(base_directory, experiment)
        if os.path.isdir(experiment_directory):
            process_experiment(experiment_directory)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <base_directory>")
        sys.exit(1)

    base_directory = sys.argv[1]
    main(base_directory)


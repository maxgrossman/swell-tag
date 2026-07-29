import schedule
import time

from urllib.request import urlopen
from pathlib import Path
from datetime import datetime, timezone, timedelta
from shutil import copyfileobj
from sqlmesh.core.context import Context
from datetime import datetime, timezone
from tenacity import retry, stop_after_attempt, wait_exponential

import logging
import subprocess
import os

logging.basicConfig(
    format='%(asctime)s - %(levelname)s - %(message)s',
    level=logging.INFO
)

class WithableContext:
    def __init__(self, paths):
        self.paths = paths
    def __enter__(self):
        self.context = Context(paths=self.paths)
        return self.context
    def __exit__(self, exc_type, exc_val, exc_tb):
        if not self.context:
            return
        self.context.close()


def get_process_interval(model):
    right_now = datetime.now(timezone.utc)
    last_5_min_interval = right_now.replace(
        minute=right_now.minute - (right_now.minute % 5), 
        second=0, 
        microsecond=0
    )
    latest_run_end = None
    with WithableContext(paths='.') as context:
        missing_intervals = context.check_intervals(
            environment="prod",
            select_models=[model],
            no_signals=True
        )
        # just go from 2 hours ago to last 5 minute interval
        if not missing_intervals:
            last_5_2_hours_ago = last_5_min_interval - timedelta(hours=2)
            return last_5_2_hours_ago, last_5_min_interval 

        model_snapshot_name = '.'.join([f'"{part}"' for part in model.split('.')])
        print(model_snapshot_name)
        for snapshot, snapshot_intervals in missing_intervals.items():
            print(snapshot.name)
            if snapshot.name != model_snapshot_name: continue
            if not snapshot_intervals.intervals: continue
            snapshot_intervals.intervals.sort(key=lambda x: x[0])    
            first_missing_start_ms = snapshot_intervals.intervals[-1][0]
            latest_run_end = datetime.fromtimestamp(first_missing_start_ms / 1000.0, tz=timezone.utc)

    return latest_run_end, last_5_min_interval

@retry(stop=stop_after_attempt(3),wait=wait_exponential(multiplier=1, min=2, max=10))
def download_latest_obs():
    logging.info('Downloading latest obs file.')
    clean_minute = datetime.now(timezone.utc)
    clean_minute.replace(second=0,microsecond=0)
    file_name = 'latest_obs.' + clean_minute.isoformat() + '.txt'
    file_path = Path(*['./latest_obs', file_name])

    with urlopen('https://www.ndbc.noaa.gov/data/latest_obs/latest_obs.txt') as resp,\
         open(file_path, 'wb+') as file_handler:
         copyfileobj(resp, file_handler)

def process_latest_obs():
    model = 'ndbc.ndbc_duck.raw_measurements_latest_obs'
    command = [
        'venv/bin/sqlmesh',
        '--log-to-stdout', 
        'run', 
        '--select-model', model,
    ]
    print("load new batch -> " + " ".join(command))
    subprocess.run(command, check=True)

def cleanup_latest_obs():
    latest_obs_dir = os.path.join(os.getcwd(),'latest_obs')
    all_files = os.listdir(latest_obs_dir)
    ten_mintes_utc = datetime.now(timezone.utc) - timedelta(minutes=10)
    cleanup_files = list(filter(lambda f: 'latest_obs' in f and datetime.fromisoformat(
        f.split('latest_obs.')[1].split('.txt')[0]
    ) < ten_mintes_utc, all_files))
    logging.info(f'Cleaning up {str(len(cleanup_files))} files older than 10 minutes.') 
    for f in cleanup_files:
        os.remove(os.path.join(latest_obs_dir, f))

    pass

def main():
    schedule.every().minute.at(':00').do(lambda: [func() for func in [download_latest_obs, process_latest_obs]])
    schedule.every(10).minutes.do(cleanup_latest_obs)

    while True:
        logging.info('Starting pending jobs')
        schedule.run_pending()
        logging.info('Finished pending jobs')
        time.sleep(10)

if __name__ == '__main__':
    main()

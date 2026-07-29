from itertools import batched
from datetime import datetime, timezone
from sqlmesh.core.context import Context

import argparse
import subprocess
import logging

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger()


this_year = datetime.now(timezone.utc).year

app = argparse.ArgumentParser(prog='backfiller')
app.add_argument('--start_year', default=2000)
app.add_argument('--end_year', default=this_year)
app.add_argument('--models', default='ndbc_duck.raw_measurements,ndbc_duck.raw_measurements_realtime')

BACKFILL_MODELS = [
    'ndbc_duck.raw_measurements',
    'ndbc_duck.raw_measurements_realtime',
    'ushlc.station_measurements',
    'swell.tags'
    # 'isd_duck.raw_measurements_isd'
]

def run_shell_cmd(command):
    print(' '.join(command))
    subprocess.run(command, check=True)

def main():
    args = app.parse_args()
    start_year = int(args.start_year)
    end_year = int(args.end_year)
    models = [m.strip() for m in args.models.split(',')]

    if start_year < 2000 or end_year > this_year:
        raise argparse.ArgumentError(message=f'Invalid star_year or end_year, must be in bounds 2000 to {str(this_year)}')

    if any(m not in BACKFILL_MODELS for m in models):
        raise argparse.ArgumentError(message=f'Provided unknown model, can only backfill {",".join(BACKFILL_MODELS)}')

    # make sure we've got the the bouy table the other guys rely on.
    run_shell_cmd(['venv/bin/sqlmesh', '--log-to-stdout', 'plan', '--auto-apply','--skip-backfill'])
    run_shell_cmd(['venv/bin/sqlmesh', '--log-to-stdout', 'run', '--select-model','ndbc_duck.bouy_history'])
    run_shell_cmd(['venv/bin/sqlmesh', '--log-to-stdout', 'run', '--select-model','isd_duck.weather_stations'])
    run_shell_cmd(['venv/bin/sqlmesh', '--log-to-stdout', 'run', '--select-model','ushlc.weather_stations'])
    # make sure we have all of the index files
    run_shell_cmd(['make', 'data_index'])

    every_2 = [y for y in range(start_year, end_year+1, 2)]
    every_2_ranges = list(zip(every_2, every_2[1:]))
    for start, end in every_2_ranges: 
        start_fmt = datetime(year=start, month=1, day=1).strftime('%Y-%m-%d')
        end_fmt = datetime(year=end, month=12, day=31).strftime('%Y-%m-%d')
        # backfill the historical bouy tables.
        for model in models:
            run_shell_cmd(['venv/bin/sqlmesh', '--log-to-stdout','run', '--start', start_fmt, '--end', end_fmt,'--select-model', model])

        run_shell_cmd(['venv/bin/sqlmesh', '--log-to-stdout','run', '--start', start_fmt, '--end', end_fmt,'--select-model', 'ndbc_duck.standard_measurements'])
    
if __name__ == '__main__':
    main()
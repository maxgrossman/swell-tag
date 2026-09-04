import sqlmesh
import handlers.constants as constants
from datetime import datetime
from sqlmesh.core.snapshot.definition import merge_intervals
from handlers.utils import split_year
from handlers.models import EventModel, enforce_model

@enforce_model()
def handler(event: EventModel, context):
    context = sqlmesh.Context(paths='.')
    all_intervals = []
    for model in constants.BACKFILLABLE_MODELS:
        check = context.check_intervals(
            environment=event.get('environment', 'prod'),
            no_signals=False,
            select_models=[model]
        )
     
        intervals = check[list(check.keys())[0]].intervals
        merged_intervals = merge_intervals(intervals)
        all_intervals += merged_intervals

    all_merged_isos = [
        [datetime.fromtimestamp(epoch/1000,UTC) for epoch in interval] \
        for interval in merge_intervals(all_intervals)
    ]

    final_intervals = []
    for interval in all_merged_isos:
        final_intervals = final_intervals + split_year(interval,[])

    return {
        'ranges': final_intervals, 
        'models': constants.BACKFILLABLE_MODELS
    }
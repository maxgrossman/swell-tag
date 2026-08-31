import pytest

from constants import BASELINE_MODELS, RAW_MODELS
from utils import year_days
from sqlmesh_handler import (
    handler_select_full, 
    handler_select_interval,
    handler_initialize_models,
    handler_ensure_dependencies,
    handler_build_missing_intervals
)

def test_ensure_dependencies_fails_lambda():
    result = handler_ensure_dependencies(
        event={'models': BASELINE_MODELS + RAW_MODELS},
        context={}
    )
    assert result['status'] == 'missing_dependencies'
    
def test_baseline_lambda():
    handler_select_full(
        event={'models': BASELINE_MODELS},
        context={}
    )
    handler_initialize_models(
        event={'models': RAW_MODELS},
        context={}
    )

def test_ensure_dependencies_success_lambda():
    result = handler_ensure_dependencies(
        event={'models': BASELINE_MODELS + RAW_MODELS},
        context={}
    )
    assert result['status'] == 'have_dependencies'

def test_interval_lambda():
    handler_select_interval(
        event={
            'models': [
                'ndbc_duck.raw_measurements',
                'ushlc.station_measurements'
            ],
            'ranges': [
                ['2020-01-01T00:00:00Z','2020-12-31T00:00:00Z']
            ]

        },
        context={}
    )

@pytest.mark.explicit
def test_build_missing_intervals_handler():
    intervals = handler_build_missing_intervals(event={}, context={})
    # this gonna change but hey, just up it!
    assert len(intervals) == 27
    for interval in intervals[:-1]:
        assert round((interval[1]-interval[0]).total_seconds()/(60*60*24)) == year_days(interval[0].year)
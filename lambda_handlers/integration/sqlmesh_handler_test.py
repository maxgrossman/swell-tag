import pytest

from lambda_handlers.sqlmesh_handler import (
    handler_select_full, 
    handler_select_interval,
    handler_ensure_dependencies
)

def test_ensure_dependencies_fails_lambda():
    result = handler_ensure_dependencies(
        event={
            'models': [
                'ndbc_duck.archive',
                'ndbc_duck.archive_realtime',
                'ndbc_duck.bouy_history',
                'ushlc.archive',
                'ushlc.stations',
                'era5.archive'
            ]
        },
        context={}
    )
    assert result['status'] == 'missing_dependencies'
    
def test_baseline_lambda():
    handler_select_full(
        event={
            'models': [
                'ndbc_duck.archive',
                'ndbc_duck.archive_realtime',
                'ndbc_duck.bouy_history',
                'ushlc.archive',
                'ushlc.stations',
                'era5_duck.archive'
            ]
        },
        context={}
    )

def test_ensure_dependencies_success_lambda():
    result = handler_ensure_dependencies(
        event={
            'models': [
                'ndbc_duck.archive',
                'ndbc_duck.archive_realtime',
                'ndbc_duck.bouy_history',
                'ushlc.archive',
                'ushlc.stations',
                'era5_duck.archive'
            ],

        },
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
            'start': '2020-01-01T00:00:00Z',
            'end': '2020-12-31T00:00:00Z'

        },
        context={}
    )

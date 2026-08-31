import pytest

from utils import split_year
from datetime import datetime, UTC

def test_split_year():
    # takes 1.5 year interval, gives me 2 intervals
    interval = [
        datetime(
            year=2024,
            month=3,
            day=1,
            tzinfo=UTC
        ),
        datetime(
            year=2025,
            month=9,
            day=1,
            tzinfo=UTC
        )
    ]
    intervals = split_year(interval, [])
    assert len(intervals) == 2
    len_first = (intervals[0][1]-intervals[0][0]).days / 365
    len_second = round((intervals[1][1]-intervals[1][0]).days / 365,2)
    assert len_first == 1
    assert  len_second == 0.5

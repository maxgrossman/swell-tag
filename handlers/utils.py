from datetime import timedelta
from calendar import isleap

def year_days(year):
    return 365 + (1 if isleap(year) else 0)

def split_year(interval, intervals):
    interval_end = interval[0] + timedelta(days=year_days(interval[0].year))
    if interval_end < interval[1]:
        intervals.append([interval[0],interval_end - timedelta(microseconds=1)])
        return split_year([interval_end, interval[1]], intervals)

    intervals.append(interval)
    return intervals
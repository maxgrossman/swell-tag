
from zoneinfo import ZoneInfo
import argparse
from datetime import datetime
from pathlib import Path
import json

def to_dms(degrees_raw):
    degrees = round(degrees_raw)
    rest = degrees_raw - degrees
    minutes_raw = rest * 60
    minutes = round(minutes_raw)
    rest = minutes_raw - minutes
    seconds = round(rest * 60, 4)
    return [degrees, minutes, seconds]

spot_lut = {
    "jocko's": [21.6217,-158.0838],
    'laniakea': [21.6190,-158.0852],
    'alamoanabeachpark': [21.291794, -157.848113],
    'hi-haleiwa': [21.6028, -158.1074],
    'sunsetbeach': [33.88073, -78.51223]
}

metadata = {
    "EXIF:Artist": "John Doe",
    "EXIF:Copyright": "Copyright 2026 John Doe",
    "EXIF:Make": "Camera Brand",
    "EXIF:Model": "SuperCam 5000",
    "EXIF:LensModel": "50mm f/1.8",
    "EXIF:DateTimeOriginal": "2026:10:25 12:00:00",
    "GPS:GPSLatitude": 21.2620,
    "GPS:GPSLatitudeRef": "N",
    "GPS:GPSLongitude": -157.8060,
    "GPS:GPSLongitudeRef": "W",
    "GPS:GPSAltitude": 15,
}

exifier = argparse.ArgumentParser()
exifier.add_argument('--input_dir')

if __name__ == '__main__':
    local_tz = ZoneInfo("Pacific/Honolulu")
    folder_path = Path(exifier.parse_args().input_dir)
    # Loop through all files in the directory
    for file_path in folder_path.iterdir():
        if 'exif_json' in str(file_path): continue
        filename = Path(file_path).name
        # _,spot,date_part,
        parts = filename.replace('.mp4','').replace('.MOV','').replace('(1)','').split("_")
        spot = parts[1]
        date_main = parts[2]
        date_rest = parts[3]
        spot_exif = metadata.copy()
        spot_coords = spot_lut.get(spot)
        spot_exif['GPS:GPSLatitude'] = to_dms(spot_coords[0])
        spot_exif['GPS:GPSLongitude'] = to_dms(spot_coords[1])

        dt = datetime.strptime(date_main + "_" + date_rest, "%Y%m%d_%H%M").replace(tzinfo=local_tz)
        spot_exif["EXIF:DateTimeOriginal"] = dt.isoformat()


        with open(str(file_path) + '.exif_json', 'w+') as exif_meta:
            exif_meta.write(json.dumps(spot_exif))

    print("EXIF metadata successfully generated and written!")
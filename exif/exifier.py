from exif import Image
from zoneinfo import ZoneInfo
import argparse
from datetime import datetime
from pathlib import Path
import os
import cv2

def to_dms(degrees_raw):
    degrees = int(degrees_raw)
    rest = degrees_raw - degrees
    minutes_raw = rest * 60
    minutes = int(minutes_raw)
    rest = minutes_raw - minutes
    seconds = int(rest * 60)
    return (degrees, minutes, seconds)

spot_lut = {
    "jocko's": [21.6217,-158.0838],
    'laniakea': [21.6190,-158.0852],
    'alamoanabeachpark': [21.291794, -157.848113],
    'hi-haleiwa': [21.6028, -158.1074],
    'sunsetbeach': [33.88073, -78.51223]
}

exifier = argparse.ArgumentParser()
exifier.add_argument('--input_dir')



def extract_frames(video_path, output_folder, image_prefix, interval_seconds=5):
    # Create the output directory if it doesn't exist
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)

    # Open the video file
    cap = cv2.VideoCapture(video_path)

    if not cap.isOpened():
        print(True, f"Error: Could not open video {video_path}")
        return

    # Get the Frames Per Second (FPS) of the video
    fps = cap.get(cv2.CAP_PROP_FPS)

    # Calculate how many frames to skip to hit the desired interval
    frame_interval = int(fps * interval_seconds)

    frame_count = 0
    saved_count = 0

    print(f"Processing video at {fps:.2f} FPS...")
    print(f"Extracting a frame every {frame_interval} frames ({interval_seconds} seconds)...")

    while True:
        # ret, frame = cap.get()
        ret, frame = cap.get_frame() if hasattr(cap, 'get_frame') else cap.read()

        # Break the loop if we hit the end of the video
        if not ret:
            break

        output_files = []

        # Check if the current frame matches our time interval
        if frame_count % frame_interval == 0:
            # Format the output filename (e.g., frame_0001.jpg)
            output_filename = os.path.join(
                output_folder, f"{image_prefix}.frame_{saved_count:04d}.jpg"
            )

            # Save the frame as a JPG image
            cv2.imwrite(output_filename, frame)
            saved_count += 1

            output_files.append(output_filename)

        frame_count += 1

        return output_files

    # Clean up and release the video file pointer
    cap.release()
    print(f"Done! Successfully extracted {saved_count} frames to '{output_folder}'.")

if __name__ == '__main__':
    local_tz = ZoneInfo("Pacific/Honolulu")
    folder_path = Path(exifier.parse_args().input_dir)
    # Loop through all files in the directory
    for file_path in [f for f in folder_path.iterdir() if '.mp4' in str(f)]:
        if 'exif_json' in str(file_path): continue
        filename = Path(file_path).name
        # _,spot,date_part,
        name_part = filename.replace('.mp4','')
        parts = name_part.replace('.MOV','').replace('(1)','').split("_")
        spot = parts[1]
        date_main = parts[2]
        date_rest = parts[3]
        spot_coords = spot_lut.get(spot)

        iso_dt = datetime.strptime(date_main + "_" + date_rest, "%Y%m%d_%H%M").replace(tzinfo=local_tz).isoformat()
        written_frames = extract_frames(
            video_path=file_path, output_folder=folder_path,
            image_prefix=name_part, interval_seconds=5
    )

        for img_path in written_frames:
            with open(img_path, "rb") as image_file:
                my_image = Image(image_file)

            my_image.gps_latitude = to_dms(abs(spot_coords[0]))
            my_image.gps_latitude_ref = 'N' if spot_coords[0] >= 0 else 'S'
            my_image.gps_longitude = to_dms(abs(spot_coords[1]))
            my_image.gps_longitude_ref = 'E' if spot_coords[1] >= 0 else 'W'
            my_image.datetime_original = iso_dt

            with open(img_path, "wb") as new_image_file:
                my_image = new_image_file.write(my_image.get_file())

    print("EXIF metadata successfully generated and written!")
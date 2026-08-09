#!/usr/bin/env python3
"""Extract date and GPS metadata from a folder of images as JSON for `aura-probe`.

    python3 Tools/probe_library.py ~/photos > library.json
    (cd Packages/AuraKit && swift run aura-probe < ../../library.json)

Reads EXIF only — no pixels are decoded and nothing is written.
"""

import datetime as dt
import json
import os
import sys

import piexif


def to_degrees(dms, ref):
    degrees = dms[0][0] / dms[0][1]
    minutes = dms[1][0] / dms[1][1]
    seconds = dms[2][0] / dms[2][1]
    value = degrees + minutes / 60 + seconds / 3600
    return -value if ref in (b"S", b"W") else value


def read(path):
    try:
        exif = piexif.load(path)
    except Exception:
        return None

    stamp = exif["Exif"].get(piexif.ExifIFD.DateTimeOriginal) \
        or exif["0th"].get(piexif.ImageIFD.DateTime)
    if not stamp:
        return None

    when = dt.datetime.strptime(stamp.decode(), "%Y:%m:%d %H:%M:%S")

    gps = exif.get("GPS") or {}
    latitude = longitude = None
    if piexif.GPSIFD.GPSLatitude in gps and piexif.GPSIFD.GPSLongitude in gps:
        latitude = to_degrees(gps[piexif.GPSIFD.GPSLatitude], gps.get(piexif.GPSIFD.GPSLatitudeRef))
        longitude = to_degrees(gps[piexif.GPSIFD.GPSLongitude], gps.get(piexif.GPSIFD.GPSLongitudeRef))

    return {
        "id": os.path.basename(path),
        "timestamp": when.replace(tzinfo=dt.timezone.utc).timestamp(),
        "latitude": latitude,
        "longitude": longitude,
    }


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: probe_library.py <folder>")

    folder = sys.argv[1]
    seeds = []
    for name in sorted(os.listdir(folder)):
        if not name.lower().endswith((".jpg", ".jpeg", ".tif", ".tiff")):
            continue
        seed = read(os.path.join(folder, name))
        if seed:
            seeds.append(seed)

    json.dump(seeds, sys.stdout)


if __name__ == "__main__":
    main()

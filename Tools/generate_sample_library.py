#!/usr/bin/env python3
"""Generate a synthetic photo library with real EXIF timestamps and GPS coordinates.

The iOS Simulator's stock photos carry no location metadata, so Aura correctly finds
no journeys in them and there is nothing to look at. This produces a library that does
have coordinates: a Bristol home base, three trips that should become journeys, and a
day trip that should deliberately *not*.

    python3 Tools/generate_sample_library.py --out ~/aura-sample-library
    xcrun simctl addmedia booted ~/aura-sample-library/*.jpg

Each image is labelled with its place and date so you can tell at a glance whether the
app grouped it correctly.
"""

import argparse
import datetime as dt
import os
import random

import piexif
from PIL import Image, ImageDraw, ImageFont

# (name, latitude, longitude, hue) — hue only drives the placeholder colour so that
# each place is visually distinct in the grid.
HOME = ("Bristol", 51.4545, -2.5879, 200)

TRIPS = [
    # (name, [(place, lat, lon, hue)], start date, days, photos/day)
    ("Lisbon", [
        ("Lisbon", 38.7223, -9.1393, 25),
        ("Sintra", 38.7979, -9.3907, 90),
        ("Cascais", 38.6979, -9.4215, 45),
    ], dt.date(2025, 9, 12), 5, 14),
    ("Tokyo", [
        ("Shibuya", 35.6595, 139.7005, 300),
        ("Asakusa", 35.7148, 139.7967, 340),
        ("Hakone", 35.2324, 139.1069, 160),
    ], dt.date(2025, 4, 3), 6, 12),
    ("Edinburgh", [
        ("Edinburgh", 55.9533, -3.1883, 260),
    ], dt.date(2026, 1, 23), 3, 10),
]

# Close enough to home that Aura should treat it as everyday life, not a journey.
# If this shows up in the feed, the home radius is set too tight.
DAY_TRIP = ("Bath", 51.3811, -2.3590, 120, dt.date(2025, 11, 8), 12)

SIZE = (1200, 900)


def render(path, label, sublabel, hue):
    image = Image.new("RGB", SIZE)
    draw = ImageDraw.Draw(image)

    top = tuple(int(c * 255) for c in hsv_to_rgb(hue / 360, 0.55, 0.85))
    bottom = tuple(int(c * 255) for c in hsv_to_rgb(((hue + 30) % 360) / 360, 0.7, 0.45))
    for y in range(SIZE[1]):
        t = y / SIZE[1]
        draw.line(
            [(0, y), (SIZE[0], y)],
            fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)),
        )

    try:
        title_font = ImageFont.truetype("DejaVuSans-Bold.ttf", 84)
        body_font = ImageFont.truetype("DejaVuSans.ttf", 44)
    except OSError:
        title_font = ImageFont.load_default()
        body_font = ImageFont.load_default()

    draw.text((70, SIZE[1] - 260), label, font=title_font, fill=(255, 255, 255))
    draw.text((70, SIZE[1] - 150), sublabel, font=body_font, fill=(255, 255, 255, 200))
    image.save(path, "JPEG", quality=72)


def hsv_to_rgb(h, s, v):
    import colorsys
    return colorsys.hsv_to_rgb(h, s, v)


def deg_to_dms(value):
    value = abs(value)
    degrees = int(value)
    minutes = int((value - degrees) * 60)
    seconds = round((value - degrees - minutes / 60) * 3600 * 100)
    return ((degrees, 1), (minutes, 1), (seconds, 100))


def write_exif(path, when, latitude, longitude):
    stamp = when.strftime("%Y:%m:%d %H:%M:%S").encode()
    exif = {
        "0th": {piexif.ImageIFD.Make: b"Aura", piexif.ImageIFD.Model: b"Sample"},
        "Exif": {
            piexif.ExifIFD.DateTimeOriginal: stamp,
            piexif.ExifIFD.DateTimeDigitized: stamp,
        },
        "GPS": {},
    }
    exif["0th"][piexif.ImageIFD.DateTime] = stamp

    if latitude is not None and longitude is not None:
        exif["GPS"] = {
            piexif.GPSIFD.GPSLatitudeRef: b"N" if latitude >= 0 else b"S",
            piexif.GPSIFD.GPSLatitude: deg_to_dms(latitude),
            piexif.GPSIFD.GPSLongitudeRef: b"E" if longitude >= 0 else b"W",
            piexif.GPSIFD.GPSLongitude: deg_to_dms(longitude),
            piexif.GPSIFD.GPSDateStamp: when.strftime("%Y:%m:%d").encode(),
        }

    piexif.insert(piexif.dump(exif), path)


def jitter(coordinate, metres=800):
    """Photos from one place are never at one exact point."""
    return coordinate + random.uniform(-metres, metres) / 111_320


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="aura-sample-library")
    parser.add_argument("--seed", type=int, default=7)
    args = parser.parse_args()

    random.seed(args.seed)
    os.makedirs(args.out, exist_ok=True)
    index = 0

    def emit(label, sublabel, hue, when, latitude, longitude):
        nonlocal index
        index += 1
        path = os.path.join(args.out, f"{index:04d}-{label.lower().replace(' ', '-')}.jpg")
        render(path, label, sublabel, hue)
        write_exif(path, when, latitude, longitude)

    # Home. Deliberately includes late-night photos: those are the only signal
    # home-base inference has, and it needs at least 20 of them.
    name, latitude, longitude, hue = HOME
    day = dt.date(2025, 3, 1)
    while day < dt.date(2026, 2, 1):
        for hour in (9, 13, 19, 22, 23):
            if random.random() < 0.45:
                continue
            when = dt.datetime.combine(day, dt.time(hour, random.randint(0, 59)))
            emit(name, when.strftime("%d %b %Y"), hue, when,
                 jitter(latitude, 1500), jitter(longitude, 1500))
        day += dt.timedelta(days=random.randint(2, 5))

    # Trips, which should each become one journey with a chapter per place.
    for trip_name, places, start, days, per_day in TRIPS:
        for offset in range(days):
            date = start + dt.timedelta(days=offset)
            place, latitude, longitude, hue = places[offset % len(places)]
            for shot in range(per_day):
                when = dt.datetime.combine(
                    date, dt.time(random.randint(8, 21), random.randint(0, 59))
                )
                emit(place, f"{trip_name} · day {offset + 1}", hue, when,
                     jitter(latitude), jitter(longitude))

        # A couple of location-less shots per trip — a boarding pass screenshot, a
        # photo AirDropped from someone else. Aura should absorb these by time alone.
        for shot in range(3):
            when = dt.datetime.combine(start, dt.time(6, 30 + shot))
            emit(f"{trip_name} screenshot", "no location", 0, when, None, None)

    # Should NOT become a journey: too close to home.
    name, latitude, longitude, hue, date, count = DAY_TRIP
    for shot in range(count):
        when = dt.datetime.combine(date, dt.time(random.randint(10, 17), random.randint(0, 59)))
        emit(name, "day trip — should NOT be a journey", hue, when,
             jitter(latitude), jitter(longitude))

    print(f"Wrote {index} photos to {args.out}")


if __name__ == "__main__":
    main()

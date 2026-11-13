"""Independent WGS-72 SGP4 reference for a single CelesTrak ISS OMM JSON.

Usage: python satellite-reference.py iss-omm.json > reference.json
Requires sgp4==2.25 (install outside the app).
"""
import json
import math
import sys
from datetime import datetime, timezone

from sgp4.api import Satrec, WGS72
from sgp4.propagation import gstime


row = json.load(open(sys.argv[1], encoding="utf-8-sig"))
if isinstance(row, list):
    row = row[0]
stamp = datetime.fromisoformat(row["EPOCH"].rstrip("Z")).replace(tzinfo=timezone.utc)
epoch = stamp.timestamp()
sat = Satrec()
sat.sgp4init(
    WGS72, "i", row["NORAD_CAT_ID"], epoch / 86400 + 2440587.5 - 2433281.5,
    row["BSTAR"], 0, 0, row["ECCENTRICITY"], math.radians(row["ARG_OF_PERICENTER"]),
    math.radians(row["INCLINATION"]), math.radians(row["MEAN_ANOMALY"]),
    row["MEAN_MOTION"] * math.tau / 1440, math.radians(row["RA_OF_ASC_NODE"]),
)


def state(time):
    error, position, velocity = sat.sgp4_tsince((time - epoch) / 60)
    if error:
        raise RuntimeError(error)
    return position, velocity


def look(position, time, lat, lon, height):
    # Rotate the station and local horizon basis into TEME, instead of rotating
    # the spacecraft into the Earth-fixed frame as the app does.
    phi = math.radians(lat)
    theta = gstime(time / 86400 + 2440587.5) + math.radians(lon)
    s, c = math.sin(phi), math.cos(phi)
    st, ct = math.sin(theta), math.cos(theta)
    e2 = 1 - (6356.752314245 / 6378.137) ** 2
    n = 6378.137 / math.sqrt(1 - e2 * s * s)
    site = ((n + height) * c * ct, (n + height) * c * st, (n * (1 - e2) + height) * s)
    dx, dy, dz = [a - b for a, b in zip(position, site)]
    east = -st * dx + ct * dy
    north = -s * ct * dx - s * st * dy + c * dz
    zenith = c * ct * dx + c * st * dy + s * dz
    distance = math.sqrt(dx * dx + dy * dy + dz * dz)
    return math.degrees(math.asin(zenith / distance)), math.degrees(math.atan2(east, north)) % 360, distance


def first_pass(start, site, threshold):
    aos, peak = None, None
    stop = min(start + 86400, int(epoch + 48 * 3600))
    for t in range(start - 1800, stop + 1):
        point = look(state(t)[0], t, *site)
        if point[0] > threshold:
            if aos is None:
                aos = t
                peak = (t, point)
            if point[0] > peak[1][0]:
                peak = (t, point)
        elif aos is not None:
            if t > start:
                return dict(aos=aos, peak=peak[0], los=t, maxAlt=peak[1][0])
            aos, peak = None, None
    return None


sites = [(39.9042, 116.4074, 0.043), (-33.4489, -70.6693, 0.52)]
vectors = []
for offset in (0, 15, 90, 720, 1440, 2880):
    t = epoch + offset * 60
    r, v = state(t)
    vectors.append(dict(minutes=offset, position=r, velocity=v, look=look(r, t, *sites[0])))

midnight = (int(epoch) // 86400 + 1) * 86400
x, y, z = state(midnight)[0]
lat = math.degrees(math.atan2(z, math.hypot(x, y)))
lon = math.degrees(math.atan2(y, x) - gstime(midnight / 86400 + 2440587.5))
lon = (lon + 180) % 360 - 180
cases = [(int(epoch) + 8 * 3600, sites[0], 10), (int(epoch) + 8 * 3600, sites[1], 20),
         (midnight - 900, (lat, lon, 0), 10), (int(epoch) + 8 * 3600, (90, 0, 0), 20)]
print(json.dumps(dict(vectors=vectors, vectorSite=sites[0], cases=[
    dict(start=start, site=site, threshold=threshold, expected=first_pass(start, site, threshold))
    for start, site, threshold in cases
])))

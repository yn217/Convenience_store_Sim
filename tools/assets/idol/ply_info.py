"""Facts about a 3DGS PLY for the #238 source record (numpy only): sha256, splat count, properties, the SH degree
the file can carry (f_rest_* count), opacity / scale statistics and the raw and robust bounding boxes.

    python -I tools/assets/idol/ply_info.py <reference.ply> [...]
"""
import hashlib
import json
import math
import sys

import numpy as np


def header(path: str):
    """(property names, vertex count, header byte length). Binary little-endian float properties only."""
    names, count = [], 0
    with open(path, "rb") as f:
        while True:
            raw = f.readline()
            if not raw:
                raise ValueError("no end_header")
            line = raw.decode("ascii").strip()
            if line.startswith("format") and "binary_little_endian" not in line:
                raise ValueError("not a binary little-endian PLY: " + line)
            if line.startswith("element vertex"):
                count = int(line.split()[-1])
            elif line.startswith("property"):
                kind = line.split()[1]
                if kind != "float":
                    raise ValueError("non-float property: " + line)
                names.append(line.split()[-1])
            elif line == "end_header":
                return names, count, f.tell()


def read(path: str) -> dict:
    names, count, start = header(path)
    with open(path, "rb") as f:
        f.seek(start)
        data = np.frombuffer(f.read(count * 4 * len(names)), dtype="<f4").reshape(count, len(names))
    return {n: data[:, i] for i, n in enumerate(names)}


def sh_degree(names) -> int:
    """3 DC + 3 * ((d + 1)^2 - 1) rest coefficients for degree d; 0 when there is no f_rest_*."""
    rest = sum(1 for n in names if n.startswith("f_rest_"))
    if rest == 0:
        return 0
    d = int(round(math.sqrt(rest / 3 + 1) - 1))
    if 3 * ((d + 1) ** 2 - 1) != rest:
        raise ValueError("f_rest_* count %d is not 3 * ((d+1)^2 - 1)" % rest)
    return d


def sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def info(path: str) -> dict:
    names, count, _ = header(path)
    p = read(path)
    xyz = np.stack([p["x"], p["y"], p["z"]], 1)
    alpha = 1 / (1 + np.exp(-p["opacity"].astype(np.float64)))
    scale = np.exp(np.stack([p["scale_%d" % i] for i in range(3)], 1).astype(np.float64)).max(1)
    q = lambda a, v: [round(float(x), 5) for x in np.quantile(a, v, axis=0)]
    return {
        "path": path.replace("\\", "/"),
        "sha256": sha256(path),
        "splats": count,
        "properties": names,
        "sh_degree": sh_degree(names),
        "bbox_min": [round(float(v), 5) for v in xyz.min(0)],
        "bbox_max": [round(float(v), 5) for v in xyz.max(0)],
        "bbox_robust_0.5_99.5": [q(xyz, 0.005), q(xyz, 0.995)],
        "opacity_quantiles_5_50_95": q(alpha, [0.05, 0.5, 0.95]),
        "opacity_below_0.04": round(float((alpha <= 0.04).mean()), 4),
        "max_scale_quantiles_50_99_max": q(scale, [0.5, 0.99, 1.0]),
    }


if __name__ == "__main__":
    print(json.dumps([info(a) for a in sys.argv[1:]], indent=1))

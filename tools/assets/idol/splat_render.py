"""A small orthographic 3D Gaussian Splat rasterizer (torch, CUDA when available) for the Idol PLY outputs
(speridlabs/idol, F:/AI_Tools/idol-sdk). Idol writes the standard 3DGS PLY with the z-up object turned y-up, so
load() turns it back: z-up, x right, y away, inside about [-0.5, 0.5]^3.

Run with the Idol venv (it has CUDA torch):  F:/AI_Tools/idol-sdk/.venv/Scripts/python.exe -I <this file> ...
"""
import math

import numpy as np
import torch

C0 = 0.28209479177387814
DEV = "cuda" if torch.cuda.is_available() else "cpu"


def read_ply(path: str) -> dict:
    with open(path, "rb") as f:
        names, count = [], 0
        while True:
            line = f.readline().decode("ascii").strip()
            if line.startswith("element vertex"):
                count = int(line.split()[-1])
            elif line.startswith("property"):
                names.append(line.split()[-1])
            elif line == "end_header":
                break
        data = np.frombuffer(f.read(count * 4 * len(names)), dtype="<f4").reshape(count, len(names))
    return {n: data[:, i] for i, n in enumerate(names)}


def quat_to_mat(q: torch.Tensor) -> torch.Tensor:
    q = torch.nn.functional.normalize(q, dim=1)
    w, x, y, z = q.unbind(1)
    return torch.stack([
        1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y),
        2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x),
        2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y),
    ], 1).reshape(-1, 3, 3)


def load(path: str) -> dict:
    """{xyz [N,3], cov [N,3,3], rgb [N,3] 0..1, alpha [N]} in the z-up object frame."""
    p = read_ply(path)
    t = lambda *k: torch.tensor(np.stack([p[n] for n in k], 1), dtype=torch.float32, device=DEV)
    xyz_y = t("x", "y", "z")
    # PLY (X, Y, Z) = (x, -z, y)  ->  x = X, y = Z, z = -Y
    m = torch.tensor([[1, 0, 0], [0, 0, 1], [0, -1, 0]], dtype=torch.float32, device=DEV)
    xyz = xyz_y @ m.T
    rot = m @ quat_to_mat(t("rot_0", "rot_1", "rot_2", "rot_3"))
    s = torch.exp(t("scale_0", "scale_1", "scale_2"))
    rs = rot * s[:, None, :]
    cov = rs @ rs.transpose(1, 2)
    rgb = (0.5 + C0 * t("f_dc_0", "f_dc_1", "f_dc_2")).clamp(0, 1)
    alpha = torch.sigmoid(t("opacity")[:, 0])
    return {"xyz": xyz, "cov": cov, "rgb": rgb, "alpha": alpha}


def transform(g: dict, mat: torch.Tensor, shift: torch.Tensor) -> dict:
    """x' = mat x + shift (mat may scale unevenly); covariances follow."""
    return {"xyz": g["xyz"] @ mat.T + shift, "cov": mat @ g["cov"] @ mat.T, "rgb": g["rgb"], "alpha": g["alpha"]}


def select(g: dict, keep: torch.Tensor) -> dict:
    return {k: v[keep] for k, v in g.items()}


def rasterize(g: dict, J: torch.Tensor, view: torch.Tensor, origin, size, max_radius: int = 48, dilation: float = 0.3) -> np.ndarray:
    """Orthographic splatting. J [2,3]: world -> screen px (x right, y down), `view` [3]: unit vector towards the
    camera (bigger dot = nearer), origin: the screen px of the world origin, size: (w, h). Straight-alpha RGBA uint8.
    Pixel i is sampled at screen coordinate i (not i + 0.5). dilation: added to the 2D covariance (px^2)."""
    w, h = size
    uv = g["xyz"] @ J.T + torch.tensor(origin, dtype=torch.float32, device=DEV)
    depth = g["xyz"] @ view
    c2 = J @ g["cov"] @ J.T + dilation * torch.eye(2, device=DEV)
    a, b, d = c2[:, 0, 0], c2[:, 0, 1], c2[:, 1, 1]
    det = (a * d - b * b).clamp_min(1e-8)
    conic = torch.stack([d / det, -b / det, a / det], 1)
    lam = 0.5 * (a + d) + torch.sqrt((0.25 * (a - d) ** 2 + b * b).clamp_min(0))
    rad = torch.ceil(3 * torch.sqrt(lam)).clamp(1, max_radius).long()
    ok = (g["alpha"] > 1 / 255) & (uv[:, 0] + rad >= 0) & (uv[:, 0] - rad < w) & (uv[:, 1] + rad >= 0) & (uv[:, 1] - rad < h)
    pix, dep, al, col = [], [], [], []
    for r in torch.unique(rad[ok]).tolist():
        idx = torch.nonzero(ok & (rad == r))[:, 0]
        ax = torch.arange(-r, r + 1, device=DEV)
        oy, ox = torch.meshgrid(ax, ax, indexing="ij")
        for chunk in torch.split(idx, max(1, 4_000_000 // ((2 * r + 1) ** 2))):
            cx = torch.round(uv[chunk, 0])[:, None] + ox.reshape(1, -1)
            cy = torch.round(uv[chunk, 1])[:, None] + oy.reshape(1, -1)
            dx = cx + 0.5 - uv[chunk, 0:1] - 0.5
            dy = cy + 0.5 - uv[chunk, 1:2] - 0.5
            cn = conic[chunk]
            power = -0.5 * (cn[:, 0:1] * dx * dx + cn[:, 2:3] * dy * dy) - cn[:, 1:2] * dx * dy
            alpha = (g["alpha"][chunk, None] * torch.exp(power)).clamp(max=0.99)
            m = (alpha > 1 / 255) & (cx >= 0) & (cx < w) & (cy >= 0) & (cy < h)
            gi = chunk[:, None].expand_as(m)[m]
            pix.append((cy[m] * w + cx[m]).long())
            dep.append(depth[gi])
            al.append(alpha[m])
            col.append(g["rgb"][gi])
    if not pix:   # nothing on screen (an empty layer): transparent
        return np.zeros((h, w, 4), np.uint8)
    pix, dep, al, col = torch.cat(pix), torch.cat(dep), torch.cat(al), torch.cat(col)
    order = torch.argsort(dep, descending=True)                       # nearest first
    order = order[torch.sort(pix[order], stable=True).indices]       # then grouped by pixel
    pix, al, col = pix[order], al[order], col[order]
    l = torch.log1p(-al)
    cs = torch.cumsum(l.double(), 0)
    excl = cs - l
    first = torch.ones_like(pix, dtype=torch.bool)
    first[1:] = pix[1:] != pix[:-1]
    seg = torch.cumsum(first.long(), 0) - 1
    start = excl[first][seg]
    T = torch.exp((excl - start)).float()
    wgt = T * al
    img = torch.zeros(w * h, 3, device=DEV).index_add_(0, pix, col * wgt[:, None])
    acc = torch.zeros(w * h, device=DEV).index_add_(0, pix, wgt)
    rgb = img / acc.clamp_min(1e-6)[:, None]
    out = torch.cat([rgb, acc[:, None]], 1).clamp(0, 1).reshape(h, w, 4)
    return (out * 255 + 0.5).byte().cpu().numpy()


def orbit(yaw: float, pitch: float, px_per_unit: float):
    """J and view for an orthographic camera at (yaw, pitch) around z (Idol camera.json: direction (sin yaw cos
    pitch, cos yaw cos pitch, sin pitch) from the object towards the camera)."""
    v = torch.tensor([math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch)], device=DEV)
    up0 = torch.tensor([0.0, 0.0, 1.0], device=DEV)
    right = torch.linalg.cross(up0, v)
    right = right / right.norm()
    up = torch.linalg.cross(v, right)
    J = torch.stack([right, -up]) * px_per_unit
    return J, v

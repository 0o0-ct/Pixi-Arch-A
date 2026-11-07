#!/usr/bin/env python3
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
"""
pixi_colors.py - the single owner of every generated colour file.

Design
------
One process renders every consumer from one extraction run:

    wallpaper
        -> Wallust   (ANSI palette + source seed)
        -> Matugen   (Material 3 roles from the Wallust seed, not the image)
        -> this file (semantic + glass tokens, atomic writes, reloads)

Wallust and Matugen are never allowed to write a consumer directly.  Their
configuration files are kept neutral; this engine gives them a private staging
directory under ~/.cache/pixi-colors and reads the result back.

Guarantees
----------
* single writer: an flock makes concurrent wallpaper requests single-flight;
  a newer request is coalesced into pending.json and runs after the current one;
* no stale overwrite: every run has a generation token and all writes happen
  under the same lock;
* atomic output: temporary file in the destination directory + fsync + rename;
* cache: keyed by image content hash + relevant settings + engine version;
* visibility: ~/.cache/pixi-colors/last-run.json, pixi-colors.log and a desktop
  notification on failure;
* targeted reload only: no `pkill qs`, no `pkill ags`, no `pkill rofi`.

Usage
-----
    pixi_colors.py [wallpaper] [options]

    --mode dark|light|auto      M3 mode (default from settings: dark)
    --scheme NAME|auto          Matugen scheme
    --glass auto|dark|light     force the glass finish
    --theme NAME                use a Wallust built-in theme palette
    --persist                   save mode/scheme/glass overrides to settings
    --reload-only               only reload running consumers
    --force                     ignore the palette cache
"""

from __future__ import annotations

import argparse
import colorsys
import fcntl
import hashlib
import json
import math
import os
import random
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

PIPELINE_VERSION = "1"
ENGINE_NAME = "pixi-colors"

HOME = Path(os.environ.get("HOME", str(Path.home())))
XDG_CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
XDG_CACHE = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache"))
CACHE_ROOT = Path(os.environ.get("PIXI_COLORS_CACHE", XDG_CACHE / "pixi-colors"))
DEFAULT_CONFIG = XDG_CONFIG / "pixi-colors" / "settings.json"

DEFAULT_SETTINGS = {
    "mode": "dark",
    "scheme": "auto",
    "glass": "auto",
    "extraction": {
        "backend": "fastresize",
        "color_space": "lch",
        "palette": "dark16",
        "threshold": 11,
    },
    "glass_threshold": 0.55,
    "apply_gtk_scheme": True,
    "reload": True,
    "run_wallpaper_hooks": True,
    "notify_on_error": True,
}

M3_SCHEMES = (
    "scheme-content",
    "scheme-expressive",
    "scheme-fidelity",
    "scheme-fruit-salad",
    "scheme-monochrome",
    "scheme-neutral",
    "scheme-rainbow",
    "scheme-tonal-spot",
    "scheme-vibrant",
    "scheme-smart",
)

# Roles consumed by GTK, AGS, QuickShell and the engine's own semantic output.
M3_ROLE_ORDER = (
    "primary",
    "on_primary",
    "primary_container",
    "on_primary_container",
    "primary_fixed",
    "primary_fixed_dim",
    "on_primary_fixed",
    "on_primary_fixed_variant",
    "secondary",
    "on_secondary",
    "secondary_container",
    "on_secondary_container",
    "secondary_fixed",
    "secondary_fixed_dim",
    "on_secondary_fixed",
    "on_secondary_fixed_variant",
    "tertiary",
    "on_tertiary",
    "tertiary_container",
    "on_tertiary_container",
    "tertiary_fixed",
    "tertiary_fixed_dim",
    "on_tertiary_fixed",
    "on_tertiary_fixed_variant",
    "error",
    "on_error",
    "error_container",
    "on_error_container",
    "background",
    "on_background",
    "surface",
    "on_surface",
    "surface_variant",
    "on_surface_variant",
    "surface_dim",
    "surface_bright",
    "surface_container_lowest",
    "surface_container_low",
    "surface_container",
    "surface_container_high",
    "surface_container_highest",
    "surface_tint",
    "outline",
    "outline_variant",
    "inverse_surface",
    "inverse_on_surface",
    "inverse_primary",
    "scrim",
    "shadow",
)

LEGACY_KEYS = (
    "background",
    "foreground",
    "cursor",
    "color0",
    "color1",
    "color2",
    "color3",
    "color4",
    "color5",
    "color6",
    "color7",
    "color8",
    "color9",
    "color10",
    "color11",
    "color12",
    "color13",
    "color14",
    "color15",
)

WALLUST_TEMPLATE = """{
  "background": "{{background}}",
  "foreground": "{{foreground}}",
  "cursor": "{{cursor}}",
  "color0": "{{color0}}",
  "color1": "{{color1}}",
  "color2": "{{color2}}",
  "color3": "{{color3}}",
  "color4": "{{color4}}",
  "color5": "{{color5}}",
  "color6": "{{color6}}",
  "color7": "{{color7}}",
  "color8": "{{color8}}",
  "color9": "{{color9}}",
  "color10": "{{color10}}",
  "color11": "{{color11}}",
  "color12": "{{color12}}",
  "color13": "{{color13}}",
  "color14": "{{color14}}",
  "color15": "{{color15}}"
}
"""


# ---------------------------------------------------------------------------
# small utilities
# ---------------------------------------------------------------------------
class EngineError(RuntimeError):
    pass


def now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = value.strip().lstrip("#")
    if len(value) == 3:
        value = "".join(c * 2 for c in value)
    if len(value) == 8:
        value = value[:6]
    if len(value) != 6 or not re.fullmatch(r"[0-9a-fA-F]{6}", value):
        raise EngineError(f"invalid colour: {value!r}")
    return int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16)


def rgb_to_hex(rgb: tuple[float, float, float]) -> str:
    return "#" + "".join(f"{max(0, min(255, round(c))):02x}" for c in rgb)


def normalize_hex(value: str) -> str:
    return rgb_to_hex(hex_to_rgb(value))


def rgba(value: str, alpha: float) -> str:
    r, g, b = hex_to_rgb(value)
    return f"rgba({r},{g},{b},{alpha:.2f})"


def blend(a: str, b: str, weight_a: float) -> str:
    """Mix two colours; weight_a is how much of `a` survives."""
    ar, ag, ab = hex_to_rgb(a)
    br, bg, bb = hex_to_rgb(b)
    return rgb_to_hex(
        (
            ar * weight_a + br * (1 - weight_a),
            ag * weight_a + bg * (1 - weight_a),
            ab * weight_a + bb * (1 - weight_a),
        )
    )


def luminance(value: str) -> float:
    """Relative sRGB luminance (gamma aware)."""
    r, g, b = (c / 255.0 for c in hex_to_rgb(value))

    def linear(c: float) -> float:
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)


def contrast(a: str, b: str) -> float:
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def ensure_light(value: str, target: float = 0.68) -> str:
    """Lift a colour toward white until it is a usable porcelain base."""
    out = value
    for step in range(11):
        if luminance(out) >= target:
            return out
        out = blend(out, "#ffffff", 0.78 - step * 0.03)
    return out


def ensure_dark(value: str, target: float = 0.10) -> str:
    """Push a colour toward black until it is a usable ink."""
    out = value
    for step in range(11):
        if luminance(out) <= target:
            return out
        out = blend(out, "#1b171c", 0.70 - step * 0.02)
    return out


def lab_lch(value: str) -> tuple[float, float, float]:
    """sRGB -> CIE LCh (D65).  Small enough to keep the engine stdlib-only."""
    r, g, b = (c / 255.0 for c in hex_to_rgb(value))

    def linear(c: float) -> float:
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    r, g, b = linear(r), linear(g), linear(b)
    x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047
    y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
    z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883

    def f(t: float) -> float:
        return t ** (1 / 3) if t > 0.008856 else (7.787 * t + 16 / 116)

    fx, fy, fz = f(x), f(y), f(z)
    L = 116 * fy - 16
    a = 500 * (fx - fy)
    bb = 200 * (fy - fz)
    C = math.hypot(a, bb)
    H = math.degrees(math.atan2(bb, a)) % 360
    return L, C, H


def best_seed(palette: dict[str, str]) -> str:
    """Pick the most representative chromatic colour from the Wallust palette.

    Matugen is seeded with this colour instead of re-reading the image.  Very
    dark/very light candidates are penalised so a near-black or near-white
    sample cannot win on raw chroma alone.
    """
    candidates: list[tuple[float, str]] = []
    for key in [f"color{i}" for i in range(1, 15)]:
        value = palette.get(key)
        if not value:
            continue
        try:
            L, C, _ = lab_lch(value)
        except EngineError:
            continue
        penalty = 1.0
        if L < 28:
            penalty = 0.45 + (L / 28.0) * 0.55
        elif L > 82:
            penalty = 0.55 + ((100 - L) / 18.0) * 0.45
        candidates.append((C * penalty, value))
    if not candidates:
        return normalize_hex(palette.get("color4", palette.get("foreground", "#808080")))
    candidates.sort(reverse=True)
    if candidates[0][0] < 6:
        # A grey image: a neutral seed is honest, but keep it in the light
        # enough range so the M3 dark scheme still has distinguishable roles.
        return normalize_hex(palette.get("color7", candidates[0][1]))
    return normalize_hex(candidates[0][1])


# ---------------------------------------------------------------------------
# PPM / image sampling
# ---------------------------------------------------------------------------
def parse_ppm(data: bytes) -> tuple[int, int, list[int]]:
    """Return width, height and an RGB integer list for P3/P6 PPM data."""
    if not data:
        raise EngineError("empty PPM output")
    if data[0:2] not in (b"P3", b"P6"):
        raise EngineError("unsupported PPM magic")
    magic = data[0:2]
    pos = 2
    values: list[int] = []
    while len(values) < 3:
        while pos < len(data) and data[pos : pos + 1].isspace():
            pos += 1
        if pos < len(data) and data[pos : pos + 1] == b"#":
            while pos < len(data) and data[pos : pos + 1] not in (b"\n", b"\r"):
                pos += 1
            continue
        start = pos
        while pos < len(data) and not data[pos : pos + 1].isspace():
            pos += 1
        if start == pos:
            raise EngineError("truncated PPM header")
        values.append(int(data[start:pos]))
    width, height, maxval = values
    if width <= 0 or height <= 0 or maxval <= 0:
        raise EngineError("invalid PPM dimensions")

    if magic == b"P6":
        # A PPM header ends with exactly one whitespace character; binary
        # pixels may legitimately start with a whitespace byte.
        if pos < len(data) and data[pos : pos + 2] == b"\r\n":
            pos += 2
        elif pos < len(data) and data[pos : pos + 1].isspace():
            pos += 1
        expected = width * height * 3
        raw = data[pos : pos + expected]
        if len(raw) != expected:
            raise EngineError("truncated PPM pixel data")
        pixels = list(raw)
    else:
        tokens = re.findall(rb"\d+", data[pos:])
        pixels = [int(t) for t in tokens[: width * height * 3]]
        if len(pixels) != width * height * 3:
            raise EngineError("truncated PPM pixel data")
    if maxval != 255:
        pixels = [round(p * 255 / maxval) for p in pixels]
    return width, height, pixels


def region_mean(
    width: int,
    height: int,
    pixels: list[int],
    x0: float,
    x1: float,
    y0: float,
    y1: float,
) -> float:
    left = max(0, min(width - 1, int(width * x0)))
    right = max(left + 1, min(width, int(math.ceil(width * x1))))
    top = max(0, min(height - 1, int(height * y0)))
    bottom = max(top + 1, min(height, int(math.ceil(height * y1))))
    total = 0.0
    count = 0
    for y in range(top, bottom):
        row = y * width * 3
        for x in range(left, right):
            i = row + x * 3
            total += 0.2126 * pixels[i] + 0.7152 * pixels[i + 1] + 0.0722 * pixels[i + 2]
            count += 1
    return (total / count / 255.0) if count else 0.5


def sample_regions(image: str) -> dict[str, float]:
    """One ImageMagick pass, six region means.  Missing magick -> neutral."""
    magick = shutil.which("magick") or shutil.which("convert")
    if not magick:
        return {
            "overall": 0.5,
            "top": 0.5,
            "center": 0.5,
            "bottom": 0.5,
            "left": 0.5,
            "right": 0.5,
            "right_top": 0.5,
        }
    try:
        sample_target = f"{image}[0]" if Path(image).suffix.lower() == ".gif" else image
        proc = subprocess.run(
            [
                magick,
                sample_target,
                "-auto-orient",
                "-background",
                "black",
                "-alpha",
                "remove",
                "-alpha",
                "off",
                "-resize",
                "64x64>",
                "-compress",
                "none",
                "ppm:-",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=20,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise EngineError(f"ImageMagick sampling failed: {exc}") from exc
    if proc.returncode != 0:
        raise EngineError(
            "ImageMagick sampling failed: " + proc.stderr.decode("utf-8", "replace")[-400:]
        )
    width, height, pixels = parse_ppm(proc.stdout)
    return {
        "overall": region_mean(width, height, pixels, 0.0, 1.0, 0.0, 1.0),
        # The bar band.  A dark photo with a bright sky is exactly the case the
        # adaptive finish exists for, so this is deliberately a band, not a row.
        "top": region_mean(width, height, pixels, 0.0, 1.0, 0.0, 0.13),
        "center": region_mean(width, height, pixels, 0.10, 0.90, 0.28, 0.72),
        "bottom": region_mean(width, height, pixels, 0.0, 1.0, 0.87, 1.0),
        "left": region_mean(width, height, pixels, 0.0, 0.15, 0.0, 1.0),
        "right": region_mean(width, height, pixels, 0.85, 1.0, 0.0, 1.0),
        "right_top": region_mean(width, height, pixels, 0.80, 1.0, 0.0, 0.55),
    }


# ---------------------------------------------------------------------------
# files / lock
# ---------------------------------------------------------------------------
def atomic_write(path: Path, data: str | bytes, mode: int | None = None) -> bool:
    """Write a file atomically.  Returns True when bytes actually changed."""
    payload = data.encode("utf-8") if isinstance(data, str) else data
    old = None
    try:
        if path.exists():
            old = path.read_bytes()
    except OSError:
        old = None
    if old == payload:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=f".{path.name}.pixi.", dir=str(path.parent))
    try:
        with os.fdopen(fd, "wb") as fh:
            fh.write(payload)
            fh.flush()
            os.fsync(fh.fileno())
        if mode is None:
            try:
                mode = path.stat().st_mode & 0o777
            except OSError:
                mode = 0o644
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    finally:
        try:
            if os.path.exists(tmp):
                os.unlink(tmp)
        except OSError:
            pass
    return True


def slug(path: Path) -> str:
    try:
        rel = path.resolve().relative_to(HOME.resolve())
    except (OSError, ValueError):
        rel = Path(path.name)
    return str(rel).replace(os.sep, "__")


def backup_file(path: Path, root: Path) -> None:
    if not path.is_file():
        return
    initial = root / "backups" / "initial" / slug(path)
    previous = root / "backups" / "previous" / slug(path)
    try:
        if not initial.exists():
            initial.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, initial)
        previous.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, previous)
    except OSError:
        pass


def read_json(path: Path, default=None):
    try:
        with path.open("r", encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return default


def deep_merge(base: dict, override: dict) -> dict:
    out = dict(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(out.get(key), dict):
            out[key] = deep_merge(out[key], value)
        else:
            out[key] = value
    return out


def load_settings(config_path: Path) -> dict:
    data = read_json(config_path, {})
    if not isinstance(data, dict):
        data = {}
    return deep_merge(DEFAULT_SETTINGS, data)


def save_settings(config_path: Path, settings: dict) -> None:
    atomic_write(config_path, json.dumps(settings, indent=2, sort_keys=False) + "\n")


# ---------------------------------------------------------------------------
# extraction
# ---------------------------------------------------------------------------
class Extractor:
    def __init__(self, settings: dict, staging: Path, log):
        self.settings = settings.get("extraction", DEFAULT_SETTINGS["extraction"])
        self.staging = staging
        self.log = log

    def _template(self) -> Path:
        template = self.staging / "templates" / "palette.json.tpl"
        template.parent.mkdir(parents=True, exist_ok=True)
        atomic_write(template, WALLUST_TEMPLATE)
        return template

    def _config(self, out: Path, directory: Path) -> Path:
        template = self._template()
        config = directory / "wallust.toml"
        text = (
            f'backend = "{self.settings.get("backend", "resized")}"\n'
            f'color_space = "{self.settings.get("color_space", "lch")}"\n'
            f'palette = "{self.settings.get("palette", "dark16")}"\n'
            f'threshold = {int(self.settings.get("threshold", 11))}\n\n'
            "[templates]\n"
            f'palette.template = "{template}"\n'
            f'palette.target = "{out}"\n'
        )
        atomic_write(config, text)
        return config

    def wallust_image(self, image: str) -> dict[str, str]:
        wallust = shutil.which("wallust")
        if not wallust:
            raise EngineError("wallust is not installed")
        run_dir = self.staging / "image"
        run_dir.mkdir(parents=True, exist_ok=True)
        out = run_dir / "palette.json"
        config = self._config(out, run_dir)
        try:
            proc = subprocess.run(
                [
                    wallust,
                    "run",
                    "-s",
                    "-q",
                    "-n",
                    "--no-hooks",
                    "-C",
                    str(config),
                    image,
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=120,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise EngineError(f"wallust failed: {exc}") from exc
        if proc.returncode != 0:
            raise EngineError("wallust failed: " + proc.stderr.decode("utf-8", "replace")[-800:])
        return self._read_palette(out)

    def wallust_theme(self, name: str) -> dict[str, str]:
        wallust = shutil.which("wallust")
        if not wallust:
            raise EngineError("wallust is not installed")
        run_dir = self.staging / "theme"
        run_dir.mkdir(parents=True, exist_ok=True)
        out = run_dir / "palette.json"
        self._config(out, run_dir)
        try:
            proc = subprocess.run(
                [
                    wallust,
                    "theme",
                    "-d",
                    str(run_dir),
                    "-q",
                    "-s",
                    "--no-hooks",
                    "--",
                    name,
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=60,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise EngineError(f"wallust theme failed: {exc}") from exc
        if proc.returncode != 0:
            raise EngineError(
                "wallust theme failed: " + proc.stderr.decode("utf-8", "replace")[-800:]
            )
        return self._read_palette(out)

    @staticmethod
    def _read_palette(path: Path) -> dict[str, str]:
        data = read_json(path, None)
        if not isinstance(data, dict):
            raise EngineError("wallust produced no readable palette")
        palette: dict[str, str] = {}
        for key in LEGACY_KEYS:
            value = data.get(key)
            if not value:
                raise EngineError(f"wallust palette is missing {key}")
            palette[key] = normalize_hex(value)
        return palette


def matugen_roles(
    seed: str, mode: str, scheme: str, log, cache_root: Path | None = None
) -> tuple[dict[str, str], str]:
    matugen = shutil.which("matugen")
    if not matugen:
        raise EngineError("matugen is not installed")
    # Ensure a valid minimal config is provided so Matugen never fails on missing [templates]
    cfg_file = (cache_root or Path("/tmp")) / "matugen_minimal.toml"
    if not cfg_file.exists():
        try:
            cfg_file.write_text("[config]\nreload_apps = false\n\n[templates]\n", encoding="utf-8")
        except OSError:
            pass
    cmd = [
        matugen,
        "-c",
        str(cfg_file) if cfg_file.exists() else str(XDG_CONFIG / "matugen" / "config.toml"),
        "color",
        "hex",
        seed,
        "-j",
        "hex",
        "--dry-run",
        "-q",
        "-m",
        mode,
        "-t",
        scheme,
    ]
    try:
        proc = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=30,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise EngineError(f"matugen failed: {exc}") from exc
    if proc.returncode != 0:
        raise EngineError("matugen failed: " + proc.stderr.decode("utf-8", "replace")[-800:])
    try:
        data = json.loads(proc.stdout.decode("utf-8", "replace"))
    except ValueError as exc:
        raise EngineError(f"matugen produced invalid JSON: {exc}") from exc
    colors = data.get("colors") or {}
    roles: dict[str, str] = {}
    for role, payload in colors.items():
        try:
            roles[role] = normalize_hex(payload["default"]["color"])
        except (KeyError, TypeError, EngineError):
            continue
    if not roles.get("primary") or not roles.get("surface"):
        raise EngineError("matugen returned an incomplete M3 palette")
    return roles, scheme


def fallback_roles(palette: dict[str, str], mode: str) -> dict[str, str]:
    """Readable approximation used only when Matugen is unavailable."""
    p = palette
    dark = mode != "light"
    bg = p["background"]
    fg = p["foreground"]
    seed = best_seed(p)
    primary = ensure_light(seed, 0.65) if dark else ensure_dark(seed, 0.35)
    on_primary = "#12141a" if luminance(primary) >= 0.45 else "#ffffff"
    primary_container = blend(primary, bg, 0.40 if dark else 0.85)
    on_primary_container = fg if dark else bg
    secondary = p.get("color6", p.get("color14", fg))
    on_secondary = "#12141a" if luminance(secondary) >= 0.45 else "#ffffff"
    secondary_container = blend(secondary, bg, 0.40 if dark else 0.85)
    on_secondary_container = fg if dark else bg
    tertiary = p.get("color4", p.get("color12", fg))
    on_tertiary = "#12141a" if luminance(tertiary) >= 0.45 else "#ffffff"
    tertiary_container = blend(tertiary, bg, 0.40 if dark else 0.85)
    on_tertiary_container = fg if dark else bg
    return {
        "primary": primary,
        "on_primary": on_primary,
        "primary_container": primary_container,
        "on_primary_container": on_primary_container,
        "primary_fixed": p.get("color14", primary),
        "primary_fixed_dim": p.get("color12", primary),
        "on_primary_fixed": p.get("color4", on_primary),
        "on_primary_fixed_variant": p.get("color11", secondary),
        "secondary": secondary,
        "on_secondary": on_secondary,
        "secondary_container": secondary_container,
        "on_secondary_container": on_secondary_container,
        "secondary_fixed": p.get("color14", secondary),
        "secondary_fixed_dim": p.get("color12", secondary),
        "on_secondary_fixed": p.get("color4", on_secondary),
        "on_secondary_fixed_variant": p.get("color12", secondary),
        "tertiary": tertiary,
        "on_tertiary": on_tertiary,
        "tertiary_container": tertiary_container,
        "on_tertiary_container": on_tertiary_container,
        "tertiary_fixed": p.get("color14", tertiary),
        "tertiary_fixed_dim": p.get("color12", tertiary),
        "on_tertiary_fixed": p.get("color4", on_tertiary),
        "on_tertiary_fixed_variant": p.get("color3", tertiary),
        "error": p.get("color1", "#ffb4ab"),
        "on_error": p.get("color15", "#690005"),
        "error_container": p.get("color9", "#93000a"),
        "on_error_container": p.get("color15", "#ffdad6"),
        "background": bg,
        "on_background": fg,
        "surface": bg,
        "on_surface": fg,
        "surface_variant": p.get("color8", bg),
        "on_surface_variant": p.get("color7", fg),
        "surface_dim": p.get("color0", bg),
        "surface_bright": p.get("color8", fg),
        "surface_container_lowest": p["background"],
        "surface_container_low": p.get("color0", bg),
        "surface_container": p.get("color0", bg),
        "surface_container_high": p.get("color8", bg),
        "surface_container_highest": p.get("color8", bg),
        "surface_tint": primary,
        "outline": p.get("color7", fg),
        "outline_variant": p.get("color8", fg),
        "inverse_surface": fg if dark else bg,
        "inverse_on_surface": bg if dark else fg,
        "inverse_primary": p.get("color14", primary),
        "scrim": "#000000",
        "shadow": "#000000",
    }


# ---------------------------------------------------------------------------
# renderers
# ---------------------------------------------------------------------------
def render_waybar(colors: dict[str, str], m3: dict[str, str]) -> str:
    lines = [
        "/* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */",
        "/* Generated by pixi_colors.py — do not edit by hand. */",
        "",
        "/* Wallust ANSI palette (terminal-compatible, always dark). */",
    ]
    for key in LEGACY_KEYS:
        if key == "background":
            lines.append(f"@define-color background {colors[key]};")
        elif key == "foreground":
            lines.append(f"@define-color foreground {colors[key]};")
        else:
            lines.append(f"@define-color {key} {colors[key]};")
    lines.append(
        f"@define-color background-alt {rgba(colors['background'], 0.25)};"
    )
    lines += ["", "/* Matugen Material 3 roles. */"]
    for role in M3_ROLE_ORDER:
        if role in m3:
            lines.append(f"@define-color {role} {m3[role]};")
    lines += [
        "",
        "/* Bluetooth module: uses the M3 primary so it follows the wallpaper. */",
        "window#waybar #bluetooth {",
        "    color: #ffffff;",
        "    background-color: @primary;",
        "    border-radius: 8px;",
        "    padding: 1px 7px;",
        "    margin: 3px 4px;",
        "    font-size: 13px;",
        "    font-weight: bold;",
        "    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.30);",
        "}",
        "window#waybar #bluetooth.connected {",
        "    color: #ffffff;",
        "    background-color: @primary;",
        "    box-shadow: 0 0 6px alpha(@primary, 0.55);",
        "}",
        "window#waybar #bluetooth.disabled,",
        "window#waybar #bluetooth.off {",
        "    color: alpha(@foreground, 0.45);",
        "    background-color: alpha(@foreground, 0.10);",
        "    box-shadow: none;",
        "}",
        "window#waybar #bluetooth:hover {",
        "    background-color: alpha(@primary, 0.85);",
        "    color: #ffffff;",
        "}",
        "",
    ]
    return "\n".join(lines)


def glass_tokens(
    colors: dict[str, str], m3: dict[str, str], branch: str
) -> dict[str, str]:
    """Concrete tokens for one glass finish.

    Porcelain is independent from the M3 mode: a light wallpaper band must get
    dark ink even when the user explicitly keeps the Material scheme dark.
    """
    base = ensure_light(colors["color15"], 0.66)
    if branch == "light":
        ink = ensure_dark(blend(m3.get("primary", colors["color13"]), "#1b171c", 0.16), 0.10)
        accent = ensure_dark(m3.get("primary", colors["color13"]), 0.24)
        warn = "#9a5b00"
        danger = "#b3261e"
        pane = rgba(base, 0.62)
        edge_glass = rgba(ink, 0.14)
        shadow = "rgba(0,0,0,0)"
        on_accent = ink
    else:
        ink_candidate = m3.get("on_surface", colors["foreground"])
        ink = ink_candidate if luminance(ink_candidate) >= 0.55 else "#f2edf1"
        accent = colors["color15"]
        warn = "#ffb454"
        danger = "#ffa8a8"
        pane = rgba(colors["color15"], 0.11)
        edge_glass = rgba(colors["color15"], 0.47)
        shadow = "rgba(0,0,0,0.10)"
        on_accent = "#12141a"
    return {
        "pane_glass": pane,
        "edge_glass": edge_glass,
        "shadow_glass": shadow,
        "ink": ink,
        "ink_muted": rgba(ink, 0.78),
        "lift": rgba(ink, 0.06),
        "lift_hi": rgba(ink, 0.11 if branch == "light" else 0.13),
        "edge": rgba(ink, 0.10),
        "edge_hi": rgba(ink, 0.20 if branch == "light" else 0.18),
        "accent_ink": accent,
        "on_accent": on_accent,
        "warn": warn,
        "danger": danger,
    }


def render_waybar_glass(tokens: dict[str, str], branch: str) -> str:
    kind = "porcelain frosted glass" if branch == "light" else "translucent smoked glass"
    lines = [
        f"/* Dynamic adaptive mode: {branch.upper()} wallpaper band ({kind}). */",
        "/* Generated by pixi_colors.py — do not edit by hand. */",
    ]
    for key in (
        "pane_glass",
        "edge_glass",
        "shadow_glass",
        "ink",
        "ink_muted",
        "lift",
        "lift_hi",
        "edge",
        "edge_hi",
        "accent_ink",
        "on_accent",
        "warn",
        "danger",
    ):
        lines.append(f"@define-color {key} {tokens[key]};")
    return "\n".join(lines) + "\n"


def render_swaync_glass(tokens: dict[str, str], branch: str) -> str:
    kind = "porcelain" if branch == "light" else "smoked glass"
    lines = [
        f"/* Dynamic adaptive mode: {branch.upper()} ({kind}). */",
        "/* Generated by pixi_colors.py — do not edit by hand. */",
    ]
    for key in (
        "pane_glass",
        "edge_glass",
        "shadow_glass",
        "ink",
        "ink_muted",
        "lift",
        "lift_hi",
        "edge",
        "edge_hi",
        "accent_ink",
        "on_accent",
        "warn",
        "danger",
    ):
        lines.append(f"@define-color {key} {tokens[key]};")
    return "\n".join(lines) + "\n"


def render_rofi_colors(colors: dict[str, str], m3: dict[str, str]) -> str:
    def g(role: str, fallback: str) -> str:
        return m3.get(role, colors.get(fallback, "#808080"))

    return f"""/* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
/* Generated by pixi_colors.py — do not edit by hand. */

* {{
    active-background: {g("primary_container", "color12")};
    active-foreground: {g("on_primary_container", "foreground")};
    normal-background: transparent;
    normal-foreground: {g("on_surface", "foreground")};
    urgent-background: {g("error_container", "color1")};
    urgent-foreground: {g("on_error_container", "foreground")};

    alternate-active-background: transparent;
    alternate-active-foreground: {g("on_surface", "foreground")};
    alternate-normal-background: transparent;
    alternate-normal-foreground: {g("on_surface", "foreground")};
    alternate-urgent-background: transparent;
    alternate-urgent-foreground: {g("on_surface", "foreground")};

    selected-active-background: {g("primary", "color13")};
    selected-active-foreground: {g("on_primary", "background")};
    selected-normal-background: {g("primary", "color13")};
    selected-normal-foreground: {g("on_primary", "background")};
    selected-urgent-background: {g("error", "color1")};
    selected-urgent-foreground: {g("on_error", "background")};

    background-color: {rgba(g("surface", "background"), 0.25)};
    background: {rgba(g("surface", "background"), 0.35)};
    foreground: {g("on_surface", "foreground")};
    border-color: {g("primary", "color13")};

    color0: {colors["color0"]};
    color1: {colors["color1"]};
    color2: {colors["color2"]};
    color3: {colors["color3"]};
    color4: {colors["color4"]};
    color5: {colors["color5"]};
    color6: {colors["color6"]};
    color7: {colors["color7"]};
    color8: {colors["color8"]};
    color9: {colors["color9"]};
    color10: {colors["color10"]};
    color11: {colors["color11"]};
    color12: {colors["color12"]};
    color13: {colors["color13"]};
    color14: {colors["color14"]};
    color15: {colors["color15"]};
}}
"""


def render_rofi_glass(tokens: dict[str, str], branch: str) -> str:
    if branch == "light":
        return f"""/* Dynamic adaptive mode: LIGHT wallpaper band (porcelain frosted glass). */
/* Generated by pixi_colors.py — do not edit by hand. */
* {{
    pane:           {tokens["pane_glass"]};
    pane-soft:      {rgba(tokens["ink"], 0.03)};
    element-bg:     {rgba(tokens["ink"], 0.04)};
    element-edge:   {rgba(tokens["ink"], 0.08)};
    lift:           {tokens["lift"]};
    lift-hi:        {tokens["lift_hi"]};
    edge:           {tokens["edge"]};
    edge-soft:      {rgba(tokens["ink"], 0.14)};
    edge-hi:        {tokens["edge_hi"]};
    edge-strong:    {rgba(tokens["ink"], 0.26)};
    selected-edge:  {rgba(tokens["ink"], 0.30)};
    edge-glass:     {tokens["edge_glass"]};
    ink:            {tokens["ink"]};
    placeholder:    {rgba(tokens["ink"], 0.55)};
}}
"""
    return f"""/* Dynamic adaptive mode: DARK wallpaper band (smoked glass + light ink). */
/* Generated by pixi_colors.py — do not edit by hand. */
* {{
    pane:           {tokens["pane_glass"]};
    pane-soft:      {rgba("#ffffff", 0.03)};
    element-bg:     {rgba("#ffffff", 0.04)};
    element-edge:   {rgba("#ffffff", 0.08)};
    lift:           {tokens["lift"]};
    lift-hi:        {tokens["lift_hi"]};
    edge:           {tokens["edge"]};
    edge-soft:      {rgba("#ffffff", 0.15)};
    edge-hi:        {tokens["edge_hi"]};
    edge-strong:    {rgba("#ffffff", 0.35)};
    selected-edge:  {rgba("#ffffff", 0.45)};
    edge-glass:     {tokens["edge_glass"]};
    ink:            {tokens["ink"]};
    placeholder:    {rgba("#ffffff", 0.45)};
}}
"""


def render_hyprland(colors: dict[str, str]) -> str:
    lines = [
        "# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */",
        "# Generated by pixi_colors.py — do not edit by hand.",
    ]
    for key in LEGACY_KEYS:
        r, g, b = hex_to_rgb(colors[key])
        lines.append(f"${key} = rgb({r:02x}{g:02x}{b:02x})")
    return "\n".join(lines) + "\n"


def hypr_color(hex_str: str) -> str:
    r, g, b = hex_to_rgb(hex_str)
    return f"rgb({r:02x}{g:02x}{b:02x})"


def render_hyprlock(colors: dict[str, str], m3: dict[str, str], branch: str) -> str:
    if branch == "light":
        ink = ensure_dark(blend(m3.get("primary", colors["color13"]), "#1b171c", 0.16), 0.10)
        base = ensure_light(colors["color15"], 0.66)
        user = ensure_dark(blend(colors["color9"], ink, 0.25), 0.30)
        layout = ensure_dark(blend(colors["color8"], ink, 0.25), 0.30)
        field_text = ensure_dark(blend(colors["color13"], ink, 0.25), 0.28)
        return f"""# Dynamic adaptive mode: LIGHT wallpaper band (porcelain lock screen).
# Generated by pixi_colors.py — do not edit by hand.
$lock_date = {rgba(ink, 0.90)}
$lock_time = {rgba(ink, 0.95)}
$lock_user = {hypr_color(user)}
$lock_layout = {hypr_color(layout)}
$lock_field_border = {hypr_color(layout)}
$lock_field_bg = {rgba(base, 0.62)}
$lock_field_text = {hypr_color(field_text)}
$lock_capslock = {hypr_color(ink)}
$lock_placeholder = {rgba(ink, 0.60)}
$lock_card_bg = {rgba(base, 0.62)}
$lock_card_border = {rgba(ink, 0.14)}
$lock_card_text = {rgba(ink, 0.80)}
"""
    return """# Dynamic adaptive mode: DARK wallpaper band (classic white glass).
# Generated by pixi_colors.py — do not edit by hand.
$lock_date = rgba(255, 255, 255, 0.9)
$lock_time = rgba(255, 255, 255, 0.95)
$lock_user = $color9
$lock_layout = $color8
$lock_field_border = $color8
$lock_field_bg = rgba(255, 255, 255, 0.1)
$lock_field_text = $color13
$lock_capslock = rgb(255, 255, 255)
$lock_placeholder = rgba(255, 255, 255, 0.60)
$lock_card_bg = rgba(15, 20, 30, 0.45)
$lock_card_border = rgba(255, 255, 255, 0.15)
$lock_card_text = rgba(255, 255, 255, 0.8)
"""


def render_qml(
    colors: dict[str, str],
    m3: dict[str, str],
    mode: str,
    scheme: str,
    branch: str,
    wallpaper: str,
    generation: str,
) -> str:
    def g(role: str, fallback: str) -> str:
        return m3.get(role, colors.get(fallback, "#808080"))

    data = {
        # Legacy keys consumed by quickshell/controlcenter Theme.qml and
        # MaterialThemeLoader.  Keep this exact spelling.
        "windowBackground": g("background", "background"),
        "primaryText": g("on_background", "foreground"),
        "layerBackground1": g("surface_container_high", "color8"),
        "layerBackground2": g("surface_container", "color0"),
        "layerBackground3": g("surface_container_low", "color0"),
        "surfaceText": g("on_surface", "foreground"),
        "secondaryText": g("on_surface_variant", "color7"),
        "borderPrimary": g("outline_variant", "color8"),
        "shadowColor": g("shadow", "background"),
        "accentPrimary": g("primary", "color4"),
        "accentSecondary": g("tertiary", "color6"),
        "selectionBackground": g("primary_container", "color12"),
        "accentPrimaryText": g("on_primary", "background"),
        "selectionText": g("on_primary_container", "color15"),
        "borderSecondary": g("outline", "color7"),
        # Full semantic palette for the overview (and any future consumer).
        "m3": {role: m3[role] for role in M3_ROLE_ORDER if role in m3},
        "mode": mode,
        "darkmode": mode != "light",
        "scheme": scheme,
        "glass": branch,
        "wallpaper": wallpaper,
        "generation": generation,
    }
    return json.dumps(data, indent=4, ensure_ascii=False) + "\n"


def render_qml_mode(branch: str, base: str, ink: str) -> str:
    return json.dumps(
        {
            "branch": branch,
            "base": base,
            "ink": ink,
            "version": PIPELINE_VERSION,
        },
        indent=2,
    ) + "\n"


def render_swaync(colors: dict[str, str], m3: dict[str, str]) -> str:
    def g(role: str, fallback: str) -> str:
        return m3.get(role, colors.get(fallback, "#808080"))

    lines = [
        "/* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */",
        "/* Generated by pixi_colors.py — do not edit by hand. */",
        "",
        f"@define-color text {g('on_surface', 'foreground')};",
        f"@define-color background {rgba(g('surface', 'background'), 0.25)};",
        f"@define-color background-alt {g('surface_container', 'color0')};",
        f"@define-color cursor {g('primary', 'color13')};",
        f"@define-color hovered {g('primary_container', 'color5')};",
        f"@define-color button-background {g('surface_container', 'color0')};",
        f"@define-color button-active {g('primary', 'color13')};",
        f"@define-color border {g('outline_variant', 'color8')};",
        f"@define-color urgent {g('error', 'color1')};",
        "",
        "/* M3 roles and compatibility aliases used by style.css. */",
        f"@define-color foreground {g('on_surface', 'foreground')};",
        f"@define-color color15 {g('on_surface', 'foreground')};",
    ]
    for role in M3_ROLE_ORDER:
        if role in m3:
            lines.append(f"@define-color {role} {m3[role]};")
    lines.append("")
    return "\n".join(lines)


def render_kitty(colors: dict[str, str]) -> str:
    return f"""# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
# Generated by pixi_colors.py — do not edit by hand.

foreground         {colors["foreground"]}
background         {colors["background"]}
cursor             {colors["cursor"]}

active_tab_foreground     {colors["background"]}
active_tab_background     {colors["foreground"]}
inactive_tab_foreground   {colors["foreground"]}
inactive_tab_background   {colors["background"]}

active_border_color   {colors["foreground"]}
inactive_border_color {colors["background"]}
bell_border_color     {colors["color1"]}

color0      {colors["color0"]}
color1      {colors["color1"]}
color2      {colors["color2"]}
color3      {colors["color3"]}
color4      {colors["color4"]}
color5      {colors["color5"]}
color6      {colors["color6"]}
color7      {colors["color7"]}
color8      {colors["color8"]}
color9      {colors["color9"]}
color10     {colors["color10"]}
color11     {colors["color11"]}
color12     {colors["color12"]}
color13     {colors["color13"]}
color14     {colors["color14"]}
color15     {colors["color15"]}
"""


def render_ghostty(colors: dict[str, str]) -> str:
    return f"""# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
# Generated by pixi_colors.py — do not edit by hand.

foreground = {colors["foreground"]}
background = {colors["background"]}
cursor-color = {colors["cursor"]}
selection-foreground = {colors["foreground"]}
selection-background = {colors["color12"]}

palette = 0={colors["color0"]}
palette = 1={colors["color1"]}
palette = 2={colors["color2"]}
palette = 3={colors["color3"]}
palette = 4={colors["color4"]}
palette = 5={colors["color5"]}
palette = 6={colors["color6"]}
palette = 7={colors["color7"]}
palette = 8={colors["color8"]}
palette = 9={colors["color9"]}
palette = 10={colors["color10"]}
palette = 11={colors["color11"]}
palette = 12={colors["color12"]}
palette = 13={colors["color13"]}
palette = 14={colors["color14"]}
palette = 15={colors["color15"]}
"""


def gtk_definitions(m3: dict[str, str]) -> str:
    def g(role: str) -> str:
        return m3.get(role, m3.get("surface", "#202020"))

    return f"""@define-color accent_color {g("primary")};
@define-color accent_fg_color {g("on_primary")};
@define-color accent_bg_color {g("primary")};
@define-color window_bg_color {g("background")};
@define-color window_fg_color {g("on_background")};
@define-color view_bg_color {g("surface")};
@define-color view_fg_color {g("on_surface")};
@define-color headerbar_bg_color {g("surface_container")};
@define-color headerbar_fg_color {g("on_surface")};
@define-color headerbar_border_color {g("outline_variant")};
@define-color popover_bg_color {g("surface_container_high")};
@define-color popover_fg_color {g("on_surface")};
@define-color card_bg_color {g("surface_container")};
@define-color card_fg_color {g("on_surface")};
@define-color dialog_bg_color {g("surface_container_high")};
@define-color dialog_fg_color {g("on_surface")};
@define-color destructive_color {g("error")};
@define-color destructive_bg_color {g("error")};
@define-color destructive_fg_color {g("on_error")};
@define-color error_bg_color {g("error")};
@define-color error_fg_color {g("on_error")};
@define-color sidebar_bg_color @window_bg_color;
@define-color sidebar_fg_color @window_fg_color;
@define-color sidebar_border_color @window_bg_color;
@define-color sidebar_backdrop_color @window_bg_color;
@define-color theme_bg_color @window_bg_color;
@define-color theme_fg_color @window_fg_color;
@define-color theme_base_color @view_bg_color;
@define-color theme_text_color @view_fg_color;
@define-color theme_selected_bg_color @accent_bg_color;
@define-color theme_selected_fg_color @accent_fg_color;
@define-color insensitive_bg_color {g("surface_container")};
@define-color insensitive_fg_color {rgba(g("on_surface"), 0.50)};
@define-color borders {g("outline_variant")};
@define-color warning_color {g("tertiary")};
@define-color success_color {g("primary")};
"""


def render_gtk3(m3: dict[str, str]) -> str:
    return (
        "/* ---- 💫 Pixi-Arch-A × macOS Tahoe 💫 ---- */\n"
        "/* Generated by pixi_colors.py — do not edit by hand. */\n\n"
        + gtk_definitions(m3)
        + """
window,
window.background,
.nautilus-window {
    background-color: alpha(@window_bg_color, 0.90);
    background-image: none;
}

.nautilus-window headerbar {
    background-color: alpha(@headerbar_bg_color, 0.85);
    border-bottom: 1px solid alpha(@headerbar_border_color, 0.35);
}

.nautilus-window .sidebar-pane,
.nautilus-window placessidebar {
    background-color: alpha(@sidebar_bg_color, 0.75);
}

.nautilus-window .view,
.nautilus-window scrolledwindow,
.nautilus-window stack {
    background-color: transparent;
}
"""
    )


def render_gtk4(m3: dict[str, str], mode: str) -> str:
    variant = "MacTahoe-Light" if mode == "light" else "MacTahoe-Dark"
    gtk_dir = HOME / ".themes" / variant / "gtk-4.0" / "gtk.css"
    if not gtk_dir.is_file():
        other = HOME / ".themes" / (
            "MacTahoe-Dark" if variant == "MacTahoe-Light" else "MacTahoe-Light"
        ) / "gtk-4.0" / "gtk.css"
        if other.is_file():
            gtk_dir = other
    return (
        "/* ---- 💫 Pixi-Arch-A × macOS Tahoe 💫 ---- */\n"
        "/* Generated by pixi_colors.py — do not edit by hand. */\n\n"
        f'@import url("file://{gtk_dir}");\n\n'
        + gtk_definitions(m3)
        + """
window,
window.background,
.nautilus-window {
    background-color: alpha(@window_bg_color, 0.90);
    background-image: none;
}

.nautilus-window headerbar {
    background-color: alpha(@headerbar_bg_color, 0.85);
    border-bottom: 1px solid alpha(@headerbar_border_color, 0.35);
}

.nautilus-window .sidebar-pane,
.nautilus-window placessidebar {
    background-color: alpha(@sidebar_bg_color, 0.75);
}

.nautilus-window .view,
.nautilus-window scrolledwindow,
.nautilus-window stack {
    background-color: transparent;
}
"""
    )


def render_ags_variables(
    colors: dict[str, str], m3: dict[str, str], mode: str, scheme: str, branch: str
) -> str:
    def g(role: str, fallback: str) -> str:
        return m3.get(role, colors.get(fallback, "#808080"))

    def solid(value: str, alpha: float = 1.0) -> str:
        r, gc, b = hex_to_rgb(value)
        return f"rgba({r},{gc},{b}, {alpha:g})"

    bar_bg = (
        rgba(ensure_light(colors["color15"], 0.66), 0.62)
        if branch == "light"
        else solid(g("surface", "background"), 0.5)
    )
    bar_fg = (
        ensure_dark(blend(m3.get("primary", colors["color13"]), "#1b171c", 0.16), 0.10)
        if branch == "light"
        else g("on_surface", "foreground")
    )
    return f"""/* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */
/* Generated by pixi_colors.py — do not edit by hand. */
/* Material 3 roles from Matugen, seeded by the Wallust palette. */

$background: {solid(g("background", "background"))};
$fg: {solid(g("on_background", "foreground"))};
$primary: {solid(g("primary", "color13"))};
$primary_container: {solid(g("primary_container", "color5"))};
$secondary: {solid(g("secondary", "color6"))};
$secondary_container: {solid(g("secondary_container", "color12"))};
$tertiary: {solid(g("tertiary", "color9"))};
$tertiary_container: {solid(g("tertiary_container", "color1"))};
$surface: {solid(g("surface", "background"))};
$surface_bright: {solid(g("surface_bright", "color8"))};
$on_background: {solid(g("on_background", "foreground"))};
$on_primary: {solid(g("on_primary", "background"))};
$on_secondary: {solid(g("on_secondary", "background"))};
$on_surface: {solid(g("on_surface", "foreground"))};
$surface_dim: {solid(g("surface_dim", "color0"))};
$on_surface_variant: {solid(g("on_surface_variant", "color7"))};
$on_primary_container: {solid(g("on_primary_container", "color15"))};
$primary_fixed_dim: {solid(g("primary_fixed_dim", "color12"))};
$on_primary_fixed_variant: {solid(g("on_primary_fixed_variant", "color11"))};
$tertiary_fixed_dim: {solid(g("tertiary_fixed_dim", "color12"))};
$on_tertiary_fixed_variant: {solid(g("on_tertiary_fixed_variant", "color3"))};

$outline: {solid(g("outline", "color7"))};
$outline_variant: {solid(g("outline_variant", "color8"))};
$error: {solid(g("error", "color1"))};
$error_container: {solid(g("error_container", "color9"))};
$on_error: {solid(g("on_error", "color15"))};
$on_error_container: {solid(g("on_error_container", "color15"))};
$scrim: {solid(g("scrim", "background"))};
$shadow: {solid(g("shadow", "background"))};
$source_color: {solid(g("primary", "color13"))};
$surface_tint: {solid(g("surface_tint", "color13"))};
$surface_variant: {solid(g("surface_variant", "color8"))};

/* general color variables */
$red: #e53935;
$accent_green: #afbea2;
$tooltipBg: $background;
$bg: {solid(g("background", "background"), 0.5)};
$barBg: {bar_bg};
$barFg: {bar_fg};
$overlay: {solid(g("on_background", "foreground"), 0.25)};
$accent: $primary;

/* os icon colors */
$os: $on_surface_variant;

/* workspaces colors */
$primaryMon: $primary;
$primaryMonHover: $primary_container;
$secondaryMon: $secondary;
$secondaryMonHover: $secondary_container;
$tertiaryMon: $tertiary;
$tertiaryMonHover: $tertiary_container;
$fourthMon: $primary;
$fourthMonHover: $primary_container;

/* button colors */
$buttonEnabled: {solid(g("primary", "color13"), 0.2)};
$buttonEnabledHover: {solid(g("primary", "color13"), 0.3)};

$buttonDisabled: $surface;
$buttonDisabledHover: {solid(g("surface_bright", "color8"), 0.7)};

/* hw circular proc colors */
$ramProc: $primary;
$cpuProc: $secondary;
$procBg: $surface_dim;

/* numeric variables */
$round: 12px;
$round2: 20px;
$spacing-xs: 0.25rem;
$spacing-sm: 0.4rem;
$spacing-md: 0.75rem;
$border-width: 1px;
$scale: 0.5rem;
$font: 1.1rem;
"""


def render_ags_theme(mode: str, scheme: str) -> str:
    return (
        "/* Generated by pixi_colors.py — do not edit by hand. */\n"
        f"$darkmode: {'true' if mode != 'light' else 'false'};\n"
        f'$material-color-scheme: "{scheme}";\n'
    )


# ---------------------------------------------------------------------------
# engine
# ---------------------------------------------------------------------------
class Engine:
    def __init__(self, args):
        self.args = args
        self.config_path = Path(args.config).expanduser() if args.config else DEFAULT_CONFIG
        self.settings = load_settings(self.config_path)
        self.cache_root = Path(args.cache_dir).expanduser() if args.cache_dir else CACHE_ROOT
        self.log_path = self.cache_root / "pixi-colors.log"
        self.pending_path = self.cache_root / "pending.json"
        self.lock_path = self.cache_root / "lock"
        self.cache_root.mkdir(parents=True, exist_ok=True)
        self.generation = f"{int(time.time())}-{os.getpid()}-{random.randrange(1000, 9999)}"
        self.errors: list[str] = []
        self.reloads: list[str] = []
        self.warnings: list[str] = []
        self.started = time.time()

    # -- logging ------------------------------------------------------------
    def log(self, message: str, quiet: bool = False) -> None:
        line = f"{now_iso()} [{ENGINE_NAME}] {message}\n"
        try:
            if self.log_path.exists() and self.log_path.stat().st_size > 1_000_000:
                os.replace(self.log_path, self.log_path.with_suffix(".log.1"))
            with self.log_path.open("a", encoding="utf-8") as fh:
                fh.write(line)
        except OSError:
            pass
        if not quiet and not self.args.quiet:
            print(message)

    def notify_error(self, message: str) -> None:
        if not self.settings.get("notify_on_error", True):
            return
        notify = shutil.which("notify-send")
        if not notify:
            return
        try:
            subprocess.run(
                [notify, "-a", ENGINE_NAME, "-u", "critical", "Pixi Colors failed", message],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=5,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired):
            pass

    # -- settings / lock ----------------------------------------------------
    def apply_overrides(self) -> None:
        changed = False
        for key in ("mode", "scheme", "glass"):
            value = getattr(self.args, key, None)
            if value:
                if self.settings.get(key) != value:
                    self.settings[key] = value
                    changed = True
        if changed and self.args.persist:
            save_settings(self.config_path, self.settings)
            self.log(f"settings saved to {self.config_path}", quiet=True)

    def acquire_lock(self) -> bool:
        self._lock_fh = open(self.lock_path, "a+")
        try:
            fcntl.flock(self._lock_fh.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            return True
        except BlockingIOError:
            return False

    def release_lock(self) -> None:
        try:
            fcntl.flock(self._lock_fh.fileno(), fcntl.LOCK_UN)
        except OSError:
            pass
        try:
            self._lock_fh.close()
        except OSError:
            pass

    def queue_pending(self) -> None:
        request = {
            "wallpaper": self.args.wallpaper,
            "mode": self.args.mode,
            "scheme": self.args.scheme,
            "glass": self.args.glass,
            "theme": self.args.theme,
            "force": bool(self.args.force),
            "persist": bool(self.args.persist),
            "queued_at": now_iso(),
        }
        atomic_write(self.pending_path, json.dumps(request, indent=2) + "\n")
        self.log("another run is active; request queued (latest wins)", quiet=True)

    def take_pending(self) -> dict | None:
        if not self.pending_path.exists():
            return None
        processing = self.pending_path.with_suffix(f".processing.{os.getpid()}")
        try:
            os.replace(self.pending_path, processing)
        except OSError:
            return None
        data = read_json(processing, None)
        try:
            processing.unlink()
        except OSError:
            pass
        return data if isinstance(data, dict) else None

    def request_from_pending(self, pending: dict) -> "Engine":
        args = argparse.Namespace(**vars(self.args))
        args.wallpaper = pending.get("wallpaper")
        args.mode = pending.get("mode")
        args.scheme = pending.get("scheme")
        args.glass = pending.get("glass")
        args.theme = pending.get("theme")
        args.force = bool(pending.get("force"))
        args.persist = bool(pending.get("persist"))
        args.reload_only = False
        return Engine(args)

    # -- wallpaper ----------------------------------------------------------
    def resolve_wallpaper(self) -> str:
        explicit = self.args.wallpaper
        if explicit:
            path = Path(explicit).expanduser()
            if path.is_file():
                return str(path.resolve())

        # swww/awww cache for the focused monitor
        monitor = None
        try:
            proc = subprocess.run(
                ["hyprctl", "monitors", "-j"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                timeout=5,
                check=False,
                text=True,
            )
            if proc.returncode == 0:
                monitors = json.loads(proc.stdout)
                for item in monitors:
                    if item.get("focused"):
                        monitor = item.get("name")
                        break
        except (OSError, ValueError, subprocess.TimeoutExpired):
            pass

        if monitor:
            # swww keeps ~/.cache/swww/<monitor>; awww keeps the same record
            # under ~/.cache/awww/<version>/<monitor>.  Both are newline files
            # whose last useful line is the active image.
            cache_files = [HOME / ".cache" / "swww" / monitor]
            awww_cache = HOME / ".cache" / "awww"
            if awww_cache.is_dir():
                cache_files.extend(
                    sorted(awww_cache.glob(f"*/{monitor}"), reverse=True)
                )
            for _ in range(10):
                for cache_file in cache_files:
                    if not cache_file.is_file():
                        continue
                    try:
                        for line in cache_file.read_text(
                            encoding="utf-8", errors="replace"
                        ).splitlines():
                            line = line.strip()
                            if not line or line.startswith(
                                ("filter", "crop:", "Lanczos", "Nearest", "Bilinear", "CatmullRom")
                            ):
                                continue
                            if Path(line).is_file():
                                return str(Path(line).resolve())
                    except OSError:
                        pass
                time.sleep(0.1)

        # `swww query` / `awww query` fallback
        for command in ("swww", "awww"):
            binary = shutil.which(command)
            if not binary:
                continue
            try:
                proc = subprocess.run(
                    [binary, "query"],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL,
                    timeout=5,
                    check=False,
                    text=True,
                )
                for line in proc.stdout.splitlines():
                    match = re.search(r"image:\s*(.+?)\s*$", line)
                    if match and Path(match.group(1)).is_file():
                        return str(Path(match.group(1)).resolve())
            except (OSError, subprocess.TimeoutExpired):
                pass

        for fallback in (
            XDG_CONFIG / "hypr" / "wallpaper_effects" / ".wallpaper_current",
            XDG_CONFIG / "rofi" / ".current_wallpaper",
        ):
            path = Path(fallback)
            if not path.is_file():
                continue
            # Older versions stored a path in .wallpaper_current.  Accept that
            # shape so a user upgrading mid-session is not left without a
            # wallpaper; the engine rewrites it as an image copy afterwards.
            try:
                if path.stat().st_size < 8192:
                    text = path.read_text(encoding="utf-8", errors="strict").strip()
                    if text.startswith("/") and Path(text).is_file():
                        return str(Path(text).resolve())
            except (OSError, UnicodeDecodeError):
                pass
            return str(path.resolve())
        raise EngineError("no wallpaper could be resolved")

    # -- extraction cache ---------------------------------------------------
    def cache_key(self, image_hash: str) -> str:
        relevant = {
            "image": image_hash,
            "version": PIPELINE_VERSION,
            "mode": self.settings.get("mode"),
            "scheme": self.settings.get("scheme"),
            "theme": self.args.theme or "",
            "extraction": self.settings.get("extraction"),
            "glass_threshold": self.settings.get("glass_threshold"),
        }
        return hashlib.sha256(
            json.dumps(relevant, sort_keys=True, separators=(",", ":")).encode()
        ).hexdigest()[:24]

    @staticmethod
    def file_hash(path: Path) -> str:
        digest = hashlib.sha256()
        with path.open("rb") as fh:
            for chunk in iter(lambda: fh.read(1024 * 1024), b""):
                digest.update(chunk)
        return digest.hexdigest()

    def image_hash(self, image: str) -> str:
        return self.file_hash(Path(image))

    def palette_cache_path(self, key: str) -> Path:
        return self.cache_root / "palettes" / f"{key}.json"

    def extract(
        self, image: str, image_hash: str, key: str
    ) -> tuple[dict, dict, dict, bool]:
        cached = read_json(self.palette_cache_path(key), None)
        if isinstance(cached, dict) and not self.args.force:
            required = ("colors", "m3", "regions", "settings", "seed")
            if all(item in cached for item in required):
                return cached["colors"], cached["m3"], cached["regions"], True

        regions = sample_regions(image)
        staging = self.cache_root / "staging" / key
        if staging.exists():
            shutil.rmtree(staging, ignore_errors=True)
        staging.mkdir(parents=True, exist_ok=True)
        extractor = Extractor(self.settings, staging, self.log)

        if self.args.theme:
            colors = extractor.wallust_theme(self.args.theme)
        else:
            colors = extractor.wallust_image(image)

        seed = best_seed(colors)
        mode = self.resolve_mode(regions)
        scheme = self.resolve_scheme(colors)
        try:
            m3, scheme = matugen_roles(seed, mode, scheme, self.log, self.cache_root)
        except EngineError as exc:
            self.warnings.append(str(exc))
            self.log(f"warning: {exc}; using Wallust fallback roles", quiet=True)
            m3 = fallback_roles(colors, mode)
            m3 = {role: m3[role] for role in M3_ROLE_ORDER if role in m3}
        result = {
            "version": PIPELINE_VERSION,
            "image_hash": image_hash,
            "settings": {
                "mode": mode,
                "scheme": scheme,
                "glass": self.settings.get("glass"),
                "extraction": self.settings.get("extraction"),
            },
            "regions": regions,
            "seed": seed,
            "colors": colors,
            "m3": m3,
            "created": now_iso(),
        }
        atomic_write(
            self.palette_cache_path(key),
            json.dumps(result, indent=2, sort_keys=False) + "\n",
        )
        self.prune_cache()
        return colors, m3, regions, False

    def prune_cache(self) -> None:
        palettes = self.cache_root / "palettes"
        if not palettes.is_dir():
            return
        files = sorted(
            (p for p in palettes.glob("*.json") if p.is_file()),
            key=lambda p: p.stat().st_mtime,
            reverse=True,
        )
        for old in files[40:]:
            try:
                old.unlink()
            except OSError:
                pass

    # -- decision helpers ---------------------------------------------------
    def resolve_mode(self, regions: dict[str, float]) -> str:
        mode = self.settings.get("mode", "dark")
        if mode == "auto":
            return "light" if regions.get("overall", 0.5) >= float(
                self.settings.get("glass_threshold", 0.55)
            ) else "dark"
        return "light" if mode == "light" else "dark"

    def resolve_scheme(self, colors: dict[str, str]) -> str:
        scheme = self.settings.get("scheme", "auto")
        if scheme in ("auto", "scheme-smart"):
            # Perceptual tiered scheme based on seed Chroma:
            # - true monochrome / grayscale (< 6): scheme-neutral (preserves clean grays)
            # - chromatic images (6..42): scheme-tonal-spot (balanced Material 3 palette with vibrant accents)
            # - vivid / neon images (>= 42): scheme-vibrant (retains wallpaper's maximum saturation)
            _, chroma, _ = lab_lch(best_seed(colors))
            if chroma < 6:
                return "scheme-neutral"
            elif chroma < 42:
                return "scheme-tonal-spot"
            else:
                return "scheme-vibrant"
        if scheme not in M3_SCHEMES:
            return "scheme-tonal-spot"
        return scheme

    def branch_for(self, region: str, regions: dict[str, float]) -> str:
        forced = self.settings.get("glass", "auto")
        if forced in ("dark", "light"):
            return forced
        mean = regions.get(region, regions.get("overall", 0.5))
        return "light" if mean >= float(self.settings.get("glass_threshold", 0.55)) else "dark"

    # -- render / write -----------------------------------------------------
    def targets(
        self,
        colors: dict[str, str],
        m3: dict[str, str],
        regions: dict[str, float],
        mode: str,
        scheme: str,
        wallpaper: str,
    ) -> tuple[dict[Path, str], dict[str, str]]:
        waybar_branch = self.branch_for("top", regions)
        rofi_branch = self.branch_for("center", regions)
        qs_branch = self.branch_for("center", regions)
        swaync_branch = self.branch_for("right_top", regions)
        ags_branch = self.branch_for("top", regions)
        hyprlock_branch = self.branch_for("overall", regions)
        gtk_branch = self.branch_for("overall", regions)

        waybar_tokens = glass_tokens(colors, m3, waybar_branch)
        rofi_tokens = glass_tokens(colors, m3, rofi_branch)
        swaync_tokens = glass_tokens(colors, m3, swaync_branch)
        qs_base = (
            ensure_light(colors["color15"], 0.66)
            if qs_branch == "light"
            else colors["color15"]
        )
        qs_tokens = glass_tokens(colors, m3, qs_branch)

        # The GTK branch is the M3 mode: GTK is a whole-application surface, so
        # the terminal-like band heuristic would flip only the shell chrome.
        gtk_mode = mode
        del gtk_branch

        files: dict[Path, str] = {
            XDG_CONFIG / "waybar/wallust/colors-waybar.css": render_waybar(colors, m3),
            XDG_CONFIG / "waybar/wallust/mode-glass.css": render_waybar_glass(
                waybar_tokens, waybar_branch
            ),
            XDG_CONFIG / "rofi/wallust/colors-rofi.rasi": render_rofi_colors(colors, m3),
            XDG_CONFIG / "rofi/wallust/mode-glass.rasi": render_rofi_glass(
                rofi_tokens, rofi_branch
            ),
            XDG_CONFIG / "hypr/wallust/wallust-hyprland.conf": render_hyprland(colors),
            XDG_CONFIG / "hypr/wallust/mode-glass-lock.conf": render_hyprlock(
                colors, m3, hyprlock_branch
            ),
            XDG_CONFIG / "quickshell/qml_color.json": render_qml(
                colors, m3, mode, scheme, qs_branch, wallpaper, self.generation
            ),
            XDG_CONFIG / "quickshell/mode-glass.json": render_qml_mode(
                qs_branch, qs_base, qs_tokens["ink"]
            ),
            XDG_CONFIG / "swaync/wallust/colors-wallust.css": render_swaync(colors, m3),
            XDG_CONFIG / "swaync/wallust/mode-glass.css": render_swaync_glass(
                swaync_tokens, swaync_branch
            ),
            XDG_CONFIG / "kitty/kitty-themes/01-Wallust.conf": render_kitty(colors),
            XDG_CONFIG / "ghostty/wallust.conf": render_ghostty(colors),
            XDG_CONFIG / "gtk-3.0/gtk.css": render_gtk3(m3),
            XDG_CONFIG / "gtk-4.0/gtk.css": render_gtk4(m3, gtk_mode),
            XDG_CONFIG / "ags/style/abstracts/_variables.scss": render_ags_variables(
                colors, m3, mode, scheme, ags_branch
            ),
            XDG_CONFIG
            / "ags/style/abstracts/_theme_variables_matugen.scss": render_ags_theme(
                mode, scheme
            ),
        }
        branches = {
            "waybar": waybar_branch,
            "rofi": rofi_branch,
            "quickshell": qs_branch,
            "swaync": swaync_branch,
            "ags": ags_branch,
            "hyprlock": hyprlock_branch,
            "gtk": gtk_mode,
        }
        return files, branches

    def write_targets(self, files: dict[Path, str]) -> dict[Path, bool]:
        changed: dict[Path, bool] = {}
        for path, content in files.items():
            parent = path.parent
            if not parent.exists():
                # Do not create a whole application tree for an uninstalled app.
                self.warnings.append(f"skipped (missing directory): {path}")
                changed[path] = False
                continue
            backup_file(path, self.cache_root)
            changed[path] = atomic_write(path, content)
        return changed

    # -- reloads ------------------------------------------------------------
    def run_cmd(self, cmd: list[str], timeout: float = 5.0) -> bool:
        try:
            proc = subprocess.run(
                cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=timeout,
                check=False,
            )
            return proc.returncode == 0
        except (OSError, subprocess.TimeoutExpired):
            return False

    def process_running(self, name: str) -> bool:
        try:
            proc = subprocess.run(
                ["pgrep", "-x", name],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=3,
                check=False,
            )
            return proc.returncode == 0
        except (OSError, subprocess.TimeoutExpired):
            return False

    def reload_waybar(self) -> None:
        if not self.process_running("waybar"):
            return
        self.run_cmd(["pkill", "-x", "waybar"], timeout=3)
        for _ in range(10):
            if not self.process_running("waybar"):
                break
            time.sleep(0.1)
        if self.process_running("waybar"):
            self.run_cmd(["pkill", "-9", "-x", "waybar"], timeout=3)
            time.sleep(0.1)
        try:
            subprocess.Popen(
                ["waybar"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                stdin=subprocess.DEVNULL,
                start_new_session=True,
                cwd=str(HOME),
                close_fds=True,
            )
            self.reloads.append("waybar:restart")
        except OSError as exc:
            self.warnings.append(f"could not restart waybar: {exc}")

    def reload_consumers(self, changed: dict[Path, bool] | None, force: bool = False) -> None:
        if self.args.no_reload or not self.settings.get("reload", True):
            return
        changed = changed or {}
        any_changed = any(changed.values())
        if not force and not any_changed:
            return

        waybar_changed = force or any(
            changed.get(XDG_CONFIG / p, False)
            for p in (
                "waybar/wallust/colors-waybar.css",
                "waybar/wallust/mode-glass.css",
            )
        )
        if waybar_changed and not self.args.skip_waybar:
            self.reload_waybar()

        if force or any(
            changed.get(XDG_CONFIG / p, False)
            for p in (
                "hypr/wallust/wallust-hyprland.conf",
                "hypr/wallust/mode-glass-lock.conf",
            )
        ):
            if shutil.which("hyprctl"):
                self.run_cmd(["hyprctl", "reload"], timeout=8)
                self.reloads.append("hyprland")

        if force or changed.get(
            XDG_CONFIG / "kitty/kitty-themes/01-Wallust.conf", False
        ):
            if self.process_running("kitty"):
                for pid in self.pids("kitty"):
                    try:
                        os.kill(pid, signal.SIGUSR1)
                    except OSError:
                        pass
                self.reloads.append("kitty")

        if force or changed.get(XDG_CONFIG / "ghostty/wallust.conf", False):
            if self.process_running("ghostty"):
                for pid in self.pids("ghostty"):
                    try:
                        os.kill(pid, signal.SIGUSR2)
                    except OSError:
                        pass
                self.reloads.append("ghostty")

        if force or any(
            changed.get(XDG_CONFIG / p, False)
            for p in (
                "swaync/wallust/colors-wallust.css",
                "swaync/wallust/mode-glass.css",
            )
        ):
            if self.process_running("swaync") and shutil.which("swaync-client"):
                self.run_cmd(["swaync-client", "-R", "-rs"], timeout=8)
                self.reloads.append("swaync")

        if force or any(
            changed.get(XDG_CONFIG / p, False)
            for p in (
                "ags/style/abstracts/_variables.scss",
                "ags/style/abstracts/_theme_variables_matugen.scss",
            )
        ):
            if self.process_running("ags"):
                if shutil.which("ags") and self.run_cmd(
                    ["ags", "request", "reload-css"], timeout=5
                ):
                    self.reloads.append("ags")
                else:
                    self.warnings.append("AGS is running but reload-css was unavailable")

        # GTK applications read gtk.css at startup; switch the desktop colour
        # scheme so libadwaita apps follow the M3 mode.
        if force or any(
            changed.get(XDG_CONFIG / p, False)
            for p in ("gtk-3.0/gtk.css", "gtk-4.0/gtk.css")
        ):
            if self.settings.get("apply_gtk_scheme", True) and shutil.which("gsettings"):
                mode = "prefer-light" if self.settings.get("_resolved_mode") == "light" else "prefer-dark"
                self.run_cmd(
                    ["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", mode],
                    timeout=5,
                )
                self.reloads.append("gtk:color-scheme")

        # QuickShell and rofi watch/read the generated files themselves; no
        # restart is needed and restarting qs would kill unrelated panels.

    @staticmethod
    def pids(name: str) -> list[int]:
        try:
            proc = subprocess.run(
                ["pgrep", "-x", name],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                timeout=3,
                check=False,
                text=True,
            )
            return [int(x) for x in proc.stdout.split() if x.isdigit()]
        except (OSError, subprocess.TimeoutExpired, ValueError):
            return []

    # -- wallpaper side files / hooks ---------------------------------------
    def write_wallpaper_links(self, wallpaper: str) -> None:
        current = XDG_CONFIG / "hypr/wallpaper_effects/.wallpaper_current"
        link = XDG_CONFIG / "rofi/.current_wallpaper"
        try:
            current.parent.mkdir(parents=True, exist_ok=True)
            same = False
            if current.is_file():
                same = self.file_hash(current) == self.file_hash(Path(wallpaper))
            if not same:
                backup_file(current, self.cache_root)
                shutil.copy2(wallpaper, current)
        except OSError as exc:
            self.warnings.append(f"could not update .wallpaper_current: {exc}")
        try:
            if link.is_symlink() or link.exists():
                link.unlink()
            link.parent.mkdir(parents=True, exist_ok=True)
            link.symlink_to(wallpaper)
        except OSError as exc:
            self.warnings.append(f"could not update rofi wallpaper link: {exc}")

    def run_hooks(self) -> None:
        if self.args.no_hooks or not self.settings.get("run_wallpaper_hooks", True):
            return
        for script in ("sddm_wallpaper.sh", "SetFolderColor.sh"):
            path = XDG_CONFIG / "hypr/scripts" / script
            if not path.is_file():
                continue
            try:
                subprocess.Popen(
                    [str(path)] + (["--normal"] if script == "sddm_wallpaper.sh" else []),
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    stdin=subprocess.DEVNULL,
                    start_new_session=True,
                    cwd=str(HOME),
                    close_fds=True,
                )
            except OSError:
                pass

    # -- last-run -----------------------------------------------------------
    def write_last_run(self, payload: dict) -> None:
        atomic_write(
            self.cache_root / "last-run.json",
            json.dumps(payload, indent=2, sort_keys=False) + "\n",
        )
        atomic_write(self.cache_root / "generation", self.generation + "\n")

    # -- main paths ---------------------------------------------------------
    def run(self) -> int:
        if self.args.reload_only:
            last = read_json(self.cache_root / "last-run.json", {}) or {}
            targets = last.get("targets", [])
            changed = {
                Path(item.get("path", "")): bool(item.get("changed"))
                for item in targets
                if item.get("path")
            }
            self.settings["_resolved_mode"] = last.get("mode", "dark")
            self.reload_consumers(changed, force=bool(self.args.force_reload))
            self.log("reload-only complete", quiet=True)
            return 0

        self.apply_overrides()

        image = self.resolve_wallpaper()
        image_hash = self.image_hash(image)
        self.settings["_resolved_mode"] = self.settings.get("mode", "dark")
        key = self.cache_key(image_hash)
        colors, m3, regions, cache_hit = self.extract(image, image_hash, key)
        mode = self.resolve_mode(regions)
        scheme = self.resolve_scheme(colors)
        self.settings["_resolved_mode"] = mode

        files, branches = self.targets(colors, m3, regions, mode, scheme, image)
        # The M3 cache stores the resolved mode/scheme; a later auto request
        # must not silently rerender with different semantics.
        changed = self.write_targets(files)
        self.write_wallpaper_links(image)
        self.reload_consumers(changed, force=bool(self.args.force_reload))
        self.run_hooks()

        target_rows = [
            {
                "path": str(path),
                "changed": bool(changed.get(path, False)),
                "exists": path.is_file(),
            }
            for path in sorted(files, key=str)
        ]
        payload = {
            "status": "ok",
            "engine": ENGINE_NAME,
            "version": PIPELINE_VERSION,
            "generation": self.generation,
            "timestamp": now_iso(),
            "duration_ms": round((time.time() - self.started) * 1000),
            "wallpaper": image,
            "image_hash": image_hash,
            "cache_key": key,
            "cache_hit": cache_hit,
            "mode": mode,
            "scheme": scheme,
            "glass": self.settings.get("glass", "auto"),
            "branches": branches,
            "regions": regions,
            "seed": best_seed(colors),
            "palette": colors,
            "m3": m3,
            "targets": target_rows,
            "reloads": self.reloads,
            "warnings": self.warnings,
            "errors": self.errors,
        }
        self.write_last_run(payload)
        self.log(
            f"ok wallpaper={Path(image).name} mode={mode} scheme={scheme} "
            f"cache={'hit' if cache_hit else 'miss'} changed={sum(changed.values())} "
            f"reloads={','.join(self.reloads) or '-'}",
            quiet=True,
        )
        if self.args.json:
            print(json.dumps(payload, indent=2))
        return 0

    def fail(self, message: str) -> int:
        self.errors.append(message)
        self.log(f"error: {message}")
        self.notify_error(message)
        payload = {
            "status": "error",
            "engine": ENGINE_NAME,
            "version": PIPELINE_VERSION,
            "generation": self.generation,
            "timestamp": now_iso(),
            "duration_ms": round((time.time() - self.started) * 1000),
            "wallpaper": self.args.wallpaper,
            "errors": self.errors,
            "warnings": self.warnings,
            "reloads": self.reloads,
        }
        self.write_last_run(payload)
        return 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="pixi_colors.py",
        description="Single-owner wallpaper colour pipeline for Hyprland-Dots.",
    )
    parser.add_argument("wallpaper", nargs="?", help="wallpaper path (optional)")
    parser.add_argument("--wallpaper", dest="wallpaper_opt", help="wallpaper path")
    parser.add_argument("--mode", choices=("dark", "light", "auto"))
    parser.add_argument("--scheme", choices=("auto",) + M3_SCHEMES)
    parser.add_argument("--glass", choices=("auto", "dark", "light"))
    parser.add_argument("--theme", help="apply a Wallust built-in theme palette")
    parser.add_argument("--persist", action="store_true", help="save overrides")
    parser.add_argument("--force", action="store_true", help="ignore palette cache")
    parser.add_argument("--reload-only", action="store_true")
    parser.add_argument("--force-reload", action="store_true")
    parser.add_argument("--skip-waybar", action="store_true")
    parser.add_argument("--no-reload", action="store_true")
    parser.add_argument("--no-hooks", action="store_true")
    parser.add_argument("--quiet", action="store_true")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--config", help="settings.json path")
    parser.add_argument("--cache-dir", help="cache directory")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.wallpaper_opt:
        args.wallpaper = args.wallpaper_opt
    del args.wallpaper_opt

    lock_engine = Engine(args)
    if not lock_engine.acquire_lock():
        lock_engine.queue_pending()
        return 0

    engine = lock_engine
    try:
        # A reload-only call should not block on a wallpaper regeneration.
        status = engine.run()

        # Coalesced requests: process the newest one, then re-check.  The lock
        # is held for the whole chain, so writes never interleave.
        while True:
            pending = lock_engine.take_pending()
            if not pending:
                break
            engine = lock_engine.request_from_pending(pending)
            status = engine.run()
        return status
    except EngineError as exc:
        return engine.fail(str(exc))
    except Exception as exc:  # keep failures visible instead of silent
        return engine.fail(f"unexpected error: {exc}")
    finally:
        lock_engine.release_lock()


if __name__ == "__main__":
    sys.exit(main())

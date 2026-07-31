#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */  #
# Genera un logo ASCII de Arch con una PALETA ALEATORIA de 5 colores
# cada vez que se abre la terminal. Hookeado desde ~/.zshrc antes de fastfetch.
import colorsys
import json
import os
import random

HOME_DIR = os.path.expanduser("~")
LOGO_REG = os.path.join(HOME_DIR, ".config/fastfetch/pixi-arch.txt")
LOGO_MIC = os.path.join(HOME_DIR, ".config/fastfetch/pixi-arch-micro.txt")
CONFIG_REG = os.path.join(HOME_DIR, ".config/fastfetch/config-pixi.jsonc")
CONFIG_MIC = os.path.join(HOME_DIR, ".config/fastfetch/config-pixi-micro.jsonc")

REG_RAW = """                  -`
                 .o+`
                `ooo/
               `+oooo:
              `+oooooo:
              -+oooooo+:
            `/:-:++oooo+:
           `/++++/+++++++:
          `/++++++++++++++:
         `/+++ooooooooooooo/`
        ./ooosssso++osssssso+`
       .oossssso-````/ossssss+`
      -osssssso.      :ssssssso.
     :osssssss/        osssso+++.
    /ossssssss/        +ssssooo/-
  `/ossssso+/:-        -:/+osssso+-
 `+sso+:-`                 `.-/+oso:
`++:.                           `-/+/
.`                                 `/"""

MIC_RAW = """      /\\
     /  \\
    /    \\
   /      \\
  /   ,,   \\
 /   |  |   \\
/_-''    ''-_\\"""

RESET = "\u001b[0m"

# Estilos temáticos (mismo carácter que las paletas curadas). Cada apertura de
# terminal genera un degradado cohesivo dentro de la familia de color del estilo
# elegido, con variación aleatoria ilimitada.
# Formato: (nombre, hue_inicio(min,max), span_hue, sat(min,max), val(min,max))
STYLES = [
    ("Crimson Sunset", (0.97, 0.99), 0.14, (0.70, 0.95), (0.85, 1.0)),
    ("Ocean Aurora",   (0.50, 0.55), 0.32, (0.65, 0.95), (0.85, 1.0)),
    ("Cyberpunk",      (0.70, 0.78), 0.32, (0.75, 1.00), (0.85, 1.0)),
    ("Emerald Breeze", (0.36, 0.42), 0.14, (0.65, 0.95), (0.85, 1.0)),
    ("Golden Flame",   (0.05, 0.10), 0.12, (0.75, 1.00), (0.85, 1.0)),
    ("Violet Storm",   (0.66, 0.72), 0.20, (0.65, 0.95), (0.80, 1.0)),
    ("Frost Blue",     (0.53, 0.58), 0.10, (0.50, 0.80), (0.90, 1.0)),
    ("Rose Quartz",    (0.92, 0.95), 0.16, (0.65, 0.95), (0.85, 1.0)),
    ("Tropical Lagoon",(0.44, 0.49), 0.14, (0.65, 0.95), (0.80, 1.0)),
    ("Lavender Haze",  (0.62, 0.66), 0.28, (0.60, 0.90), (0.85, 1.0)),
    ("Amber Glow",     (0.08, 0.11), 0.12, (0.80, 1.00), (0.85, 1.0)),
    ("Pearl & Indigo", (0.60, 0.64), 0.18, (0.55, 0.85), (0.90, 1.0)),
    ("Neon Rainbow",   (0.00, 1.00), 0.36, (0.70, 1.00), (0.85, 1.0)),
    ("Crimson Night",  (0.94, 0.98), 0.10, (0.70, 0.95), (0.70, 0.90)),
]


def rgb_ansi(r, g, b, bold=False):
    prefix = "\u001b[1;" if bold else "\u001b["
    return f"{prefix}38;2;{r};{g};{b}m"


def hsv_ansi(h, s, v, bold=False):
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, max(0.0, min(1.0, s)), max(0.0, min(1.0, v)))
    return rgb_ansi(int(r * 255), int(g * 255), int(b * 255), bold)


def generate_palette():
    _name, start_range, span, sat_range, val_range = random.choice(STYLES)
    start = random.uniform(*start_range)
    sat = random.uniform(*sat_range)
    val = random.uniform(*val_range)
    palette = []
    for i in range(5):
        h = (start + span * i) % 1.0
        s = max(0.4, min(1.0, sat + random.uniform(-0.10, 0.10)))
        v = max(0.6, min(1.0, val + random.uniform(-0.06, 0.06)))
        palette.append((h, s, v))
    return palette


def band_sizes(total_rows, num_colors):
    base = total_rows // num_colors
    remainder = total_rows % num_colors
    return [base + (1 if i < remainder else 0) for i in range(num_colors)]


def colorize(raw, palette):
    rows = raw.split("\n")
    sizes = band_sizes(len(rows), len(palette))
    out = []
    idx = 0
    for color_idx, count in enumerate(sizes):
        for _ in range(count):
            color = palette[color_idx]
            ansi = hsv_ansi(*color) if len(color) == 3 and isinstance(color[0], float) else rgb_ansi(*color)
            out.append(f"{ansi}{rows[idx]}{RESET}")
            idx += 1
    return "\n".join(out)


def update_title(path, color):
    if not os.path.exists(path):
        return
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    is_micro = "micro" in path
    spacing = "   " if is_micro else "  "
    if len(color) == 3 and isinstance(color[0], float):
        r, g, b = colorsys.hsv_to_rgb(*color)
        ansi = f"38;2;{int(r * 255)};{int(g * 255)};{int(b * 255)}m"
    else:
        ansi = f"38;2;{color[0]};{color[1]};{color[2]}m"

    for mod in data["modules"]:
        if isinstance(mod, dict) and mod.get("type") == "custom" and any(x in mod.get("format", "") for x in ["Pixi", "𝗣𝗶𝘅𝗶"]):
            mod["format"] = f" \u001b[1;{ansi}󰣇{spacing}𝗣𝗶𝘅𝗶-𝗔𝗿𝗰𝗵-𝗔\u001b[0m"

    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4, ensure_ascii=False)
        f.write("\n")


def main():
    palette = generate_palette()
    with open(LOGO_REG, "w", encoding="utf-8") as f:
        f.write(colorize(REG_RAW, palette))
    with open(LOGO_MIC, "w", encoding="utf-8") as f:
        f.write(colorize(MIC_RAW, palette))
    update_title(CONFIG_REG, palette[0])
    update_title(CONFIG_MIC, palette[0])


if __name__ == "__main__":
    main()

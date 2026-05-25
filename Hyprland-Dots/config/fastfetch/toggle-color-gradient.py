#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import json
import os

LOGO_REG = "/home/c0o0c/.config/fastfetch/pixi-arch.txt"
LOGO_MIC = "/home/c0o0c/.config/fastfetch/pixi-arch-micro.txt"
CONFIG_REG = "/home/c0o0c/.config/fastfetch/config-pixi.jsonc"
CONFIG_MIC = "/home/c0o0c/.config/fastfetch/config-pixi-micro.jsonc"

WHITE_REG_RAW = """                  -`
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

WHITE_MIC_RAW = """      /\\
     /  \\
    /    \\
   /      \\
  /   ,,   \\
 /   |  |   \\
/_-''    ''-_\\"""

# True-Color 24-bit RGB codes
COLOR_WHITE = "\u001b[38;2;255;255;255m" # #FFFFFF (Pure White)
reset = "\u001b[0m"

# Regular Colors (19-row Cyan to Magenta gradient using 24-bit True Color)
colors_reg = [
    "\u001b[38;2;0;255;255m",   # Row 1-4: Cyan
    "\u001b[38;2;0;255;255m",
    "\u001b[38;2;0;255;255m",
    "\u001b[38;2;0;255;255m",
    "\u001b[38;2;128;192;255m", # Row 5-8: Light Blue
    "\u001b[38;2;128;192;255m",
    "\u001b[38;2;128;192;255m",
    "\u001b[38;2;128;192;255m",
    "\u001b[38;2;255;128;255m", # Row 9-12: Pink/Magenta
    "\u001b[38;2;255;128;255m",
    "\u001b[38;2;255;128;255m",
    "\u001b[38;2;255;128;255m",
    "\u001b[38;2;255;0;255m",   # Row 13-16: Vibrant Magenta
    "\u001b[38;2;255;0;255m",
    "\u001b[38;2;255;0;255m",
    "\u001b[38;2;255;0;255m",
    "\u001b[38;2;128;0;255m",   # Row 17-19: Purple
    "\u001b[38;2;128;0;255m",
    "\u001b[38;2;128;0;255m"
]

# Micro Colors (7-row Cyan to Magenta gradient using 24-bit True Color)
colors_mic = [
    "\u001b[38;2;0;255;255m",   # Row 1-2: Cyan
    "\u001b[38;2;0;255;255m",
    "\u001b[38;2;128;192;255m", # Row 3-4: Light Blue
    "\u001b[38;2;128;192;255m",
    "\u001b[38;2;255;128;255m", # Row 5-6: Pink
    "\u001b[38;2;255;128;255m",
    "\u001b[38;2;255;0;255m"    # Row 7: Magenta
]

# Generate White and Gradient versions for standard logo
white_reg_lines = []
for line in WHITE_REG_RAW.split("\n"):
    white_reg_lines.append(f"{COLOR_WHITE}{line}{reset}")
WHITE_REG = "\n".join(white_reg_lines)

gradient_reg_lines = []
for i, line in enumerate(WHITE_REG_RAW.split("\n")):
    gradient_reg_lines.append(f"{colors_reg[i]}{line}{reset}")
GRADIENT_REG = "\n".join(gradient_reg_lines)

# Generate White and Gradient versions for micro logo
white_mic_lines = []
for line in WHITE_MIC_RAW.split("\n"):
    white_mic_lines.append(f"{COLOR_WHITE}{line}{reset}")
WHITE_MICRO = "\n".join(white_mic_lines)

gradient_mic_lines = []
for i, line in enumerate(WHITE_MIC_RAW.split("\n")):
    gradient_mic_lines.append(f"{colors_mic[i]}{line}{reset}")
GRADIENT_MIC = "\n".join(gradient_mic_lines)

def detect_style():
    if not os.path.exists(LOGO_REG):
        return "none"
    with open(LOGO_REG, "r", encoding="utf-8") as f:
        content = f.read()
    # If the file contains Cyan color, it's gradient
    if "\u001b[38;2;0;255;255m" in content:
        return "gradient"
    return "white"

def update_config_title(path, style):
    if not os.path.exists(path):
        return
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    for mod in data["modules"]:
        if isinstance(mod, dict) and mod.get("type") == "custom" and "Pixi - Arch" in mod.get("format", ""):
            if style == "white":
                # Pure True-Color Bold RGB White (\u001b[1;38;2;255;255;255m)
                mod["format"] = " \u001b[1;38;2;255;255;255m󰣇  Pixi - Arch\u001b[0m"
            else:
                # Pure True-Color Bold RGB Cyan (\u001b[1;38;2;0;255;255m)
                mod["format"] = " \u001b[1;38;2;0;255;255m󰣇  Pixi - Arch\u001b[0m"
                
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4, ensure_ascii=False)
        f.write("\n")

def main():
    current = detect_style()
    if current == "gradient":
        # Toggle to white
        with open(LOGO_REG, "w", encoding="utf-8") as f:
            f.write(WHITE_REG)
        with open(LOGO_MIC, "w", encoding="utf-8") as f:
            f.write(WHITE_MICRO)
        update_config_title(CONFIG_REG, "white")
        update_config_title(CONFIG_MIC, "white")
        print("Logo and Title style successfully changed to: [Super Bright True-Color White] (Default)")
    else:
        # Toggle to gradient
        with open(LOGO_REG, "w", encoding="utf-8") as f:
            f.write(GRADIENT_REG)
        with open(LOGO_MIC, "w", encoding="utf-8") as f:
            f.write(GRADIENT_MIC)
        update_config_title(CONFIG_REG, "gradient")
        update_config_title(CONFIG_MIC, "gradient")
        print("Logo and Title style successfully changed to: [Vibrant 24-bit True-Color Gradient] (Optional)")

if __name__ == "__main__":
    main()

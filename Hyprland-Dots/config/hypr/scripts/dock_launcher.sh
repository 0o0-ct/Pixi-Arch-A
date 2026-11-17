#!/usr/bin/env bash
# Lanzador del dock: abre el menú de aplicaciones (rofi) al pulsar los puntitos.
pkill rofi >/dev/null 2>&1 || true
rofi -show drun >/dev/null 2>&1 &

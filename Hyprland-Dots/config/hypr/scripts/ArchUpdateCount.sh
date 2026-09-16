#!/usr/bin/env bash

official=$(checkupdates 2>/dev/null | wc -l)
aur=$(yay -Qu 2>/dev/null | wc -l)
flatpak=$(flatpak remote-ls --updates 2>/dev/null | wc -l)

total=$(( official + aur + flatpak ))

if [ "$total" -eq 0 ]; then
    echo ""
else
    printf '{"text":"󰏗 %s","class":"has-updates","tooltip":"Aplicaciones y Paquetes de Arch Linux\\nPaquetes pendientes por actualizar: %s"}\n' "$total" "$total"
fi

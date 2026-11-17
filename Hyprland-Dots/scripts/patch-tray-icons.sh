#!/usr/bin/env bash
# /* ---- 💫 https://github.com/0o0-ct/Pixi-Arch-A 💫 ---- */ #
# Patch tray status icons (Ethernet, Bluetooth, Wi-Fi) to match Pixi-Arch-A Monet palette

python3 - << 'EOF'
import os

base_dirs = [
    os.path.expanduser('~/.icons/Flat-Remix-Blue-Dark'),
    os.path.expanduser('~/.icons/Flat-Remix-Blue-Light'),
    os.path.expanduser('~/.icons/Tela-red'),
    os.path.expanduser('~/.icons/Tela-red-dark'),
    os.path.expanduser('~/.icons/Tela-red-light'),
]

wired_connected_svg = '''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none">
  <defs>
    <style id="current-color-scheme" type="text/css">
      .ColorScheme-Text { color:#cbbeff; }
      .ColorScheme-Highlight { color:#e6deff; }
    </style>
  </defs>
  <rect x="3" y="4" width="18" height="15" rx="3.5" stroke="#cbbeff" stroke-width="1.8"/>
  <path d="M7 19v-4h10v4" stroke="#cbbeff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M7.5 8v2M10.5 8v2M13.5 8v2M16.5 8v2" stroke="#e6deff" stroke-width="1.5" stroke-linecap="round"/>
</svg>'''

wired_disconnected_svg = '''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none">
  <defs>
    <style id="current-color-scheme" type="text/css">
      .ColorScheme-Text { color:#cbbeff; }
      .ColorScheme-NegativeText { color:#ffa8a8; }
    </style>
  </defs>
  <rect x="3" y="4" width="18" height="15" rx="3.5" stroke="#cbbeff" stroke-width="1.8" opacity="0.38"/>
  <path d="M7 19v-4h10v4" stroke="#cbbeff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" opacity="0.38"/>
  <line x1="4" y1="20" x2="20" y2="4" stroke="#ffa8a8" stroke-width="1.8" stroke-linecap="round"/>
</svg>'''

bluetooth_disabled_svg = '''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none">
  <defs>
    <style id="current-color-scheme" type="text/css">
      .ColorScheme-Text { color:#cbbeff; }
      .ColorScheme-NegativeText { color:#ffa8a8; }
    </style>
  </defs>
  <path d="M7.5 6.5L16 13.5L11.5 17.5V6.5L16 10.5L7.5 17.5" stroke="#cbbeff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" opacity="0.38"/>
  <line x1="4.5" y1="19.5" x2="19.5" y2="4.5" stroke="#ffa8a8" stroke-width="1.8" stroke-linecap="round"/>
</svg>'''

bluetooth_active_svg = '''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none">
  <defs>
    <style id="current-color-scheme" type="text/css">
      .ColorScheme-Text { color:#cbbeff; }
      .ColorScheme-Highlight { color:#e6deff; }
    </style>
  </defs>
  <path d="M7.5 6.5L16 13.5L11.5 17.5V6.5L16 10.5L7.5 17.5" stroke="#cbbeff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
</svg>'''

bluetooth_connected_svg = '''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none">
  <defs>
    <style id="current-color-scheme" type="text/css">
      .ColorScheme-Text { color:#cbbeff; }
      .ColorScheme-Highlight { color:#e6deff; }
    </style>
  </defs>
  <path d="M7.5 6.5L16 13.5L11.5 17.5V6.5L16 10.5L7.5 17.5" stroke="#cbbeff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="5" cy="12" r="1.3" fill="#e6deff"/>
  <circle cx="19" cy="12" r="1.3" fill="#e6deff"/>
</svg>'''

wifi_100_svg = '''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none">
  <defs><style type="text/css">.ColorScheme-Text { color:#cbbeff; }</style></defs>
  <path d="M3 8.5C5.5 6 8.6 4.5 12 4.5C15.4 4.5 18.5 6 21 8.5" stroke="#cbbeff" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M6 12C7.7 10.3 9.8 9.2 12 9.2C14.2 9.2 16.3 10.3 18 12" stroke="#cbbeff" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M9 15.5C9.9 14.5 10.9 14 12 14C13.1 14 14.1 14.5 15 15.5" stroke="#cbbeff" stroke-width="1.8" stroke-linecap="round"/>
  <circle cx="12" cy="19" r="1.2" fill="#cbbeff"/>
</svg>'''

wifi_75_svg = '''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none">
  <path d="M3 8.5C5.5 6 8.6 4.5 12 4.5C15.4 4.5 18.5 6 21 8.5" stroke="#cbbeff" stroke-width="1.8" stroke-linecap="round" opacity="0.25"/>
  <path d="M6 12C7.7 10.3 9.8 9.2 12 9.2C14.2 9.2 16.3 10.3 18 12" stroke="#cbbeff" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M9 15.5C9.9 14.5 10.9 14 12 14C13.1 14 14.1 14.5 15 15.5" stroke="#cbbeff" stroke-width="1.8" stroke-linecap="round"/>
  <circle cx="12" cy="19" r="1.2" fill="#cbbeff"/>
</svg>'''

wifi_50_svg = '''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none">
  <path d="M3 8.5C5.5 6 8.6 4.5 12 4.5C15.4 4.5 18.5 6 21 8.5" stroke="#cbbeff" stroke-width="1.8" stroke-linecap="round" opacity="0.25"/>
  <path d="M6 12C7.7 10.3 9.8 9.2 12 9.2C14.2 9.2 16.3 10.3 18 12" stroke="#cbbeff" stroke-width="1.8" stroke-linecap="round" opacity="0.25"/>
  <path d="M9 15.5C9.9 14.5 10.9 14 12 14C13.1 14 14.1 14.5 15 15.5" stroke="#cbbeff" stroke-width="1.8" stroke-linecap="round"/>
  <circle cx="12" cy="19" r="1.2" fill="#cbbeff"/>
</svg>'''

wifi_25_svg = '''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none">
  <path d="M3 8.5C5.5 6 8.6 4.5 12 4.5C15.4 4.5 18.5 6 21 8.5" stroke="#cbbeff" stroke-width="1.8" stroke-linecap="round" opacity="0.25"/>
  <path d="M6 12C7.7 10.3 9.8 9.2 12 9.2C14.2 9.2 16.3 10.3 18 12" stroke="#cbbeff" stroke-width="1.8" stroke-linecap="round" opacity="0.25"/>
  <path d="M9 15.5C9.9 14.5 10.9 14 12 14C13.1 14 14.1 14.5 15 15.5" stroke="#cbbeff" stroke-width="1.8" stroke-linecap="round" opacity="0.25"/>
  <circle cx="12" cy="19" r="1.2" fill="#cbbeff"/>
</svg>'''

wifi_00_svg = '''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none">
  <path d="M3 8.5C5.5 6 8.6 4.5 12 4.5C15.4 4.5 18.5 6 21 8.5" stroke="#cbbeff" stroke-width="1.8" stroke-linecap="round" opacity="0.25"/>
  <path d="M6 12C7.7 10.3 9.8 9.2 12 9.2C14.2 9.2 16.3 10.3 18 12" stroke="#cbbeff" stroke-width="1.8" stroke-linecap="round" opacity="0.25"/>
  <circle cx="12" cy="19" r="1.2" fill="#cbbeff" opacity="0.25"/>
  <line x1="4" y1="20" x2="20" y2="4" stroke="#ffa8a8" stroke-width="1.8" stroke-linecap="round"/>
</svg>'''

mapping = {
    'wired_connected': [
        'gnome-dev-ethernet.svg', 'nm-device-wired.svg', 'network-wired.svg',
        'network-wired-activated.svg', 'network-wired-connected.svg',
        'notification-network-ethernet-connected.svg', 'notification-network-wired.svg'
    ],
    'wired_disconnected': [
        'notification-network-ethernet-disconnected.svg', 'network-wired-disconnected.svg',
        'network-wired-disconected.svg', 'network-wired-offline.svg', 'network-wired-no-route.svg',
        'network-wired-disconnected-symbolic.svg', 'network-disconnected.svg', 'network-offline.svg',
        'nm-no-connection.svg'
    ],
    'bluetooth_disabled': [
        'blueman-disabled.svg', 'blueman-tray-disabled.svg', 'bluetooth-disabled.svg',
        'preferences-system-bluetooth-inactive.svg', 'bluetooth-offline.svg'
    ],
    'bluetooth_active': [
        'blueman.svg', 'blueman-tray.svg', 'blueman-tray-active.svg', 'blueman-active.svg',
        'bluetooth.svg', 'bluetooth-active.svg', 'preferences-system-bluetooth.svg',
        'preferences-bluetooth.svg', 'cs-bluetooth.svg', 'gnome-bluetooth.svg',
        'preferences-system-bluetooth-active.svg', 'bluetooth-48.svg'
    ],
    'bluetooth_connected': [
        'bluetooth-paired.svg', 'blueman-connected.svg'
    ],
    'wifi_100': [
        'nm-signal-100.svg', 'network-wireless-100.svg', 'network-wireless-connected-100.svg',
        'network-wireless-signal-excellent.svg', 'network-wireless-secure-signal-excellent.svg',
        'nm-device-wireless.svg', 'network-wireless.svg', 'notification-network-wireless.svg'
    ],
    'wifi_75': [
        'nm-signal-75.svg', 'network-wireless-75.svg', 'network-wireless-connected-75.svg',
        'network-wireless-signal-good.svg'
    ],
    'wifi_50': [
        'nm-signal-50.svg', 'network-wireless-50.svg', 'network-wireless-connected-50.svg',
        'network-wireless-signal-ok.svg'
    ],
    'wifi_25': [
        'nm-signal-25.svg', 'network-wireless-25.svg', 'network-wireless-connected-25.svg',
        'network-wireless-signal-low.svg', 'network-wireless-signal-weak.svg'
    ],
    'wifi_00': [
        'nm-signal-00.svg', 'network-wireless-00.svg', 'network-wireless-disconnected.svg',
        'network-wireless-offline.svg', 'notification-network-wireless-disconnected.svg'
    ]
}

content_map = {
    'wired_connected': wired_connected_svg,
    'wired_disconnected': wired_disconnected_svg,
    'bluetooth_disabled': bluetooth_disabled_svg,
    'bluetooth_active': bluetooth_active_svg,
    'bluetooth_connected': bluetooth_connected_svg,
    'wifi_100': wifi_100_svg,
    'wifi_75': wifi_75_svg,
    'wifi_50': wifi_50_svg,
    'wifi_25': wifi_25_svg,
    'wifi_00': wifi_00_svg
}

count = 0
for base in base_dirs:
    if not os.path.exists(base): continue
    for root, dirs, files in os.walk(base):
        for f in files:
            for category, names in mapping.items():
                if f in names:
                    target = os.path.join(root, f)
                    try:
                        with open(target, 'w') as fp:
                            fp.write(content_map[category])
                        count += 1
                    except Exception:
                        pass

EOF

for theme in Flat-Remix-Blue-Dark Flat-Remix-Blue-Light Tela-red Tela-red-dark Tela-red-light; do
  if [ -d "$HOME/.icons/$theme" ]; then
    gtk-update-icon-cache -f "$HOME/.icons/$theme" 2>/dev/null
  fi
done

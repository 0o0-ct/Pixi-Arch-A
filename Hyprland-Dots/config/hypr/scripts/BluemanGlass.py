#!/usr/bin/env python3
"""
BluemanGlass — Modern macOS Glassmorphism & Wallust Dynamic Theming Wrapper for Blueman Manager
Seamlessly styles Blueman Manager with frosted glass, smooth rounded cards, and dynamic Wallust palette.
"""
import os
import sys
import logging
import gettext
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gtk, Gdk, GLib, Gio

from blueman.main.Manager import Blueman
from blueman.Functions import set_proc_title, create_parser, create_logger

class GlassBlueman(Blueman):
    def do_activate(self) -> None:
        super().do_activate()
        if self.window:
            self.window.set_name("manager_window")
            ctx = self.window.get_style_context()
            ctx.add_class("blueman-manager")
            ctx.add_class("glass-window")

            # Style the DeviceList treeview
            if hasattr(self, "List") and self.List:
                list_ctx = self.List.get_style_context()
                list_ctx.add_class("blueman-devicelist")
                list_ctx.add_class("chicklet-list")

            # Load GTK-3 CSS with highest priority so it completely overrides MacTahoe default blue
            css_file = os.path.expanduser("~/.config/gtk-3.0/gtk.css")
            if os.path.exists(css_file):
                provider = Gtk.CssProvider()
                try:
                    provider.load_from_path(css_file)
                    screen = Gdk.Screen.get_default()
                    Gtk.StyleContext.add_provider_for_screen(
                        screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_USER + 200
                    )
                except Exception as e:
                    logging.error("Failed to load GTK3 CSS provider: %s", e)

gettext.textdomain("blueman")

if __name__ == '__main__':
    parser = create_parser()
    args = parser.parse_args()

    log_level = logging.WARNING
    if args.LEVEL:
        log_level = getattr(logging, args.LEVEL.upper(), logging.WARNING)

    create_logger(log_level, "blueman-manager", syslog=args.syslog)

    app = GlassBlueman()
    set_proc_title()
    app.run()

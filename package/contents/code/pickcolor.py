#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Steven <richardsarizandieta@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
"""Cuentagotas para seleccionar un color de pantalla."""
import os

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

PORTAL = "org.freedesktop.portal.Desktop"


def main():
    bus = Gio.bus_get_sync(Gio.BusType.SESSION)
    token = f"aiusage{os.getpid()}"
    sender = bus.get_unique_name()[1:].replace(".", "_")
    request_path = f"/org/freedesktop/portal/desktop/request/{sender}/{token}"
    loop = GLib.MainLoop()

    def on_response(_conn, _sender, _path, _iface, _signal, params):
        code, results = params.unpack()
        if code == 0 and "color" in results:
            r, g, b = results["color"]
            print("#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255)))
        loop.quit()

    # Suscripción a la respuesta
    bus.signal_subscribe(PORTAL, "org.freedesktop.portal.Request", "Response", request_path,
                         None, Gio.DBusSignalFlags.NONE, on_response)
    bus.call_sync(PORTAL, "/org/freedesktop/portal/desktop", "org.freedesktop.portal.Screenshot",
                  "PickColor", GLib.Variant("(sa{sv})", ("", {"handle_token": GLib.Variant("s", token)})),
                  None, Gio.DBusCallFlags.NONE, -1, None)
    GLib.timeout_add_seconds(120, loop.quit)
    loop.run()


if __name__ == "__main__":
    main()

#!/bin/bash
cd "$(dirname "$0")/.."

mkdir -p package/contents/locale/es/LC_MESSAGES
msgfmt translate/es.po -o package/contents/locale/es/LC_MESSAGES/plasma_applet_io.github.natstyles.aiusage.mo

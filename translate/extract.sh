#!/bin/bash
cd "$(dirname "$0")/.."

xgettext --from-code=UTF-8 -C -kde -ci18n -ki18n:1 -ki18nc:1c,2 -ki18np:1,2 -ki18ncp:1c,2,3 \
  --package-name="Token Usage" -o translate/template.pot package/contents/ui/*.qml package/contents/config/*.qml

if [ -f translate/es.po ]; then
    msgmerge -U translate/es.po translate/template.pot
else
    msginit -i translate/template.pot -o translate/es.po -l es --no-translator
fi

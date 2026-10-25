#!/bin/sh
# Syntax-checks every addon file and fails on globals outside the allowlist.
set -e
cd "$(dirname "$0")/.."
ALLOWED="SoulFoundDB SoulFoundCharDB SLASH_SOULFOUND1 SLASH_SOULFOUND2"
status=0
for f in addon/SoulFound/*.lua; do
    luac5.1 -p "$f"
    for g in $(luac5.1 -l -p "$f" | grep SETGLOBAL | awk '{print $NF}'); do
        case " $ALLOWED " in
            *" $g "*) ;;
            *) echo "lint: $f sets global $g"; status=1 ;;
        esac
    done
done
[ $status -eq 0 ] && echo "lint: ok"
exit $status

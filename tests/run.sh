#!/bin/sh
# Runs the add-on tests: lint, unit tests and the fake WoW UI integration tests.
# Needs lua5.1 and luac5.1 on PATH.
set -e
cd "$(dirname "$0")/.."
mkdir -p tests/out
sh tests/lint.sh
lua5.1 tests/addon_test.lua
lua5.1 tests/integration_test.lua

#!/bin/sh
# Testele logicii (AgendaKit) pe vectorii din docs/nativ/vectori/, rulate pe Mac.
# Build-ul stă în afara ~/Documents, altfel codesign refuză pachetul de teste.
cd "$(dirname "$0")/AgendaKit" && exec swift test --scratch-path "$HOME/Library/Caches/AgendaKit-build" "$@"

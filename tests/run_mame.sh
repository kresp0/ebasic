#!/bin/sh
# Headless MAME run: run_mame.sh <script.txt> <outdir> [seconds] [extra mame args...]
# Copyright (C) 2026 Santiago Crespo
# SPDX-License-Identifier: GPL-3.0-or-later
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
MAME=${MAME:-$HOME/PROYECTOS/genio2000/mame-upstream}
SCRIPT=$(realpath "$1"); OUT=$(realpath -m "$2"); SECS=${3:-60}; shift 3 || shift $#
mkdir -p "$OUT"
unset DISPLAY WAYLAND_DISPLAY
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
export BB_SCRIPT="$SCRIPT" BB_LOG="$OUT/drive.log"
cd "$MAME"
exec ./mame/genio genio2000 -rompath roms_local -cart "$HERE/ebasic_gl2000_mame_64K.bin" \
  -skip_gameinfo -nothrottle -seconds_to_run "$SECS" -snapshot_directory "$OUT" \
  -autoboot_script "$HERE/tests/drive.lua" -video none ${SOUND:--sound none} "$@"

#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
mkdir -p "$repo_dir/build/tests/ui"
cd "$repo_dir"
"${CC:-cc}" -std=c11 -Wall -Wextra -Werror -Isw/app -Isw/drivers -Isw/hal -Isw/common -Isw/graphics \
  "$repo_dir/tb/firmware/ui_partial_test.c" "$repo_dir/sw/app/ui_clock.c" \
  "$repo_dir/sw/graphics/ui_graphics.c" "$repo_dir/sw/graphics/ui_assets.c" \
  "$repo_dir/sw/graphics/font_8x8.c" "$repo_dir/sw/drivers/st7735_panel.c" \
  -o "$repo_dir/build/tests/ui_partial_test"
"$repo_dir/build/tests/ui_partial_test" "$repo_dir/build/tests/ui"

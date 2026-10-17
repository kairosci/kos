#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/test_lib.sh"
source "$SCRIPT_DIR/../modules/theme-previews/scripts/lib/theme-preview.sh"

test_section "Preview Window Geometry"
monitor='{"width":1920,"height":1080,"scale":1,"x":0,"y":0,"reserved":[0,32,0,0]}'
assert_true "left window occupies half the usable monitor" '[[ "$(theme_preview_window_geometry "$monitor" left)" == $'"'"'0\t32\t960\t1048'"'"' ]]'
assert_true "right window occupies the other half" '[[ "$(theme_preview_window_geometry "$monitor" right)" == $'"'"'960\t32\t960\t1048'"'"' ]]'
monitor='{"width":2562,"height":1440,"scale":2,"x":-1281,"y":100,"reserved":[10,20,11,30]}'
assert_true "scaled monitors preserve origins and odd width remainder" '[[ "$(theme_preview_window_geometry "$monitor" left)" == $'"'"'-1271\t120\t630\t670'"'"' && "$(theme_preview_window_geometry "$monitor" right)" == $'"'"'-641\t120\t630\t670'"'"' ]]'
monitor='{"width":1919,"height":1080,"scale":1,"x":0,"y":0}'
assert_true "odd monitor widths leave no missing column" '[[ "$(theme_preview_window_geometry "$monitor" right)" == $'"'"'959\t0\t960\t1080'"'"' ]]'
assert_false "invalid side fails" 'theme_preview_window_geometry "$monitor" middle'
monitor='{"width":1920,"height":1080,"scale":0,"x":0,"y":0}'
assert_false "invalid scale fails" 'theme_preview_window_geometry "$monitor" left'
if command -v magick >/dev/null; then
    SANDBOX=$(mktemp -d)
    trap 'rm -rf "$SANDBOX"' EXIT
    magick -size 2x2 xc:'#f0f0f0' -depth 16 "PNG64:$SANDBOX/rgba.png"
    assert_true "live color checks normalize 16 bit RGBA screenshots to RGB" '[[ $(theme_preview_pixel_rgb "$SANDBOX/rgba.png" 1 1) == f0f0f0 ]]'
    assert_false "live color checks reject invalid coordinates" 'theme_preview_pixel_rgb "$SANDBOX/rgba.png" invalid 1'
fi
test_summary

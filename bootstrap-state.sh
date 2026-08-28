#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/security.sh
source "$script_dir/lib/security.sh"

state_raw=""
current_theme=""

if state_dir=$(theme_modes_state_directory 2>/dev/null); then
  if [[ -f $theme_modes_state_file && ! -L $theme_modes_state_file ]]; then
    state_raw=$(safe_read_regular_file "$theme_modes_state_file" "$THEME_MODES_MAX_STATE_BYTES" 2>/dev/null || true)
  fi
fi

if current_dir=$(theme_modes_current_theme_directory 2>/dev/null); then
  if [[ -f $theme_modes_current_theme_file && ! -L $theme_modes_current_theme_file ]]; then
    current_theme=$(safe_read_regular_file "$theme_modes_current_theme_file" "$THEME_MODES_MAX_THEME_NAME_BYTES" 2>/dev/null || true)
    current_theme=${current_theme//$'\n'/}
    current_theme=${current_theme//$'\r'/}
  fi
fi

jq -cn \
  --arg state "$state_raw" \
  --arg currentTheme "$current_theme" \
  '{state:$state, currentTheme:$currentTheme}'

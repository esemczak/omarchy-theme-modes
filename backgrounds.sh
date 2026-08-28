#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/security.sh
source "$script_dir/lib/security.sh"

slug="${1:-}"
if ! is_valid_slug "$slug"; then
  printf '[]\n'
  exit 0
fi

mapfile -t roots < <(background_roots_for_slug "$slug")
if ((${#roots[@]} == 0)); then
  printf '[]\n'
  exit 0
fi

emit_entry() {
  local path="$1"
  local thumb="$2"
  local base label verified_path verified_thumb

  verified_path=$(verify_background_path "$slug" "$path" 2>/dev/null || true)
  [[ -n $verified_path ]] || return 0

  if [[ -n $thumb ]]; then
    verified_thumb=$(verify_thumbnail_path "$thumb" 2>/dev/null || verify_background_path "$slug" "$thumb" 2>/dev/null || true)
  fi
  [[ -n $verified_thumb ]] || verified_thumb="$verified_path"

  base=$(basename -- "$verified_path")
  label="${base%.*}"
  jq -cn \
    --arg path "$verified_path" \
    --arg name "$label" \
    --arg thumbnailPath "$verified_thumb" \
    '{path:$path, name:$name, thumbnailPath:$thumbnailPath}'
}

first=true
printf '['
for root in "${roots[@]}"; do
  [[ -n $root && -d $root && ! -L $root ]] || continue
  while IFS= read -r -d '' image; do
    [[ -n $image ]] || continue
    entry=$(emit_entry "$image" "$image" || true)
    [[ -n $entry ]] || continue
    if [[ $first == true ]]; then
      first=false
    else
      printf ','
    fi
    printf '%s' "$entry"
  done < <(find -P "$root" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.webp' \) \
    -print0 2>/dev/null)
done
printf ']\n'

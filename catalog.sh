#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/security.sh
source "$script_dir/lib/security.sh"

ensure_private_directory "$theme_modes_preview_dir" >/dev/null || exit 1

find_preview() {
  local slug="$1"
  local ext candidate verified theme_dir name

  is_valid_slug "$slug" || return 1
  for ext in png jpg jpeg webp gif bmp; do
    candidate="$theme_modes_preview_dir/$slug.$ext"
    [[ -e $candidate ]] || continue
    verified=$(verify_preview_path "$slug" "$candidate" 2>/dev/null || true)
    [[ -n $verified ]] || continue
    printf '%s' "$verified"
    return 0
  done

  theme_dir=$(theme_dir_for_slug "$slug" 2>/dev/null || true)
  [[ -n $theme_dir ]] || return 1
  for name in preview.png preview.jpg preview.jpeg preview.webp preview.gif preview.bmp; do
    candidate="$theme_dir/$name"
    [[ -e $candidate && ! -L $candidate ]] || continue
    verified=$(verify_preview_path "$slug" "$candidate" 2>/dev/null || true)
    [[ -n $verified ]] || continue
    printf '%s' "$verified"
    return 0
  done
  return 1
}

timeout 20s omarchy-theme-switcher --preload >/dev/null 2>&1 || true

first=true
printf '['
while IFS= read -r name; do
  [[ -n $name ]] || continue
  slug=$(slugify_name "$name" 2>/dev/null || true)
  [[ -n $slug ]] || continue
  preview=""
  preview=$(find_preview "$slug" 2>/dev/null || true)
  if [[ $first == true ]]; then
    first=false
  else
    printf ','
  fi
  jq -cn \
    --arg name "$name" \
    --arg slug "$slug" \
    --arg preview "$preview" \
    '{name:$name, slug:$slug, previewPath:$preview}'
done < <(timeout 20s omarchy theme list 2>/dev/null | head -n 512)
printf ']\n'

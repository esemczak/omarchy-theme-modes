#!/bin/bash

set -euo pipefail

preview_dir="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy/theme-selector/previews"

slugify() {
  echo "$1" | sed -E 's/<[^>]+>//g' | tr '[:upper:]' '[:lower:]' | tr ' ' '-'
}

find_preview() {
  local slug="$1"
  local ext candidate resolved

  for ext in png jpg jpeg webp gif bmp; do
    candidate="$preview_dir/$slug.$ext"
    [[ -e $candidate ]] || continue
    resolved=$(readlink -f "$candidate" 2>/dev/null || realpath "$candidate" 2>/dev/null || printf '%s' "$candidate")
    printf '%s' "$resolved"
    return 0
  done

  return 1
}

omarchy-theme-switcher --preload >/dev/null 2>&1

first=true
printf '['
while IFS= read -r name; do
  [[ -n $name ]] || continue
  slug=$(slugify "$name")
  preview=""
  preview=$(find_preview "$slug" || true)
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
done < <(omarchy theme list)
printf ']\n'

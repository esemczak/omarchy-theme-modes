#!/bin/bash

set -euo pipefail

slug="${1:-}"
if [[ -z $slug ]]; then
  printf '[]\n'
  exit 0
fi

theme_dir=""
if [[ -d $HOME/.config/omarchy/themes/$slug ]]; then
  theme_dir="$HOME/.config/omarchy/themes/$slug"
elif [[ -d ${OMARCHY_PATH:-/usr/share/omarchy}/themes/$slug ]]; then
  theme_dir="${OMARCHY_PATH:-/usr/share/omarchy}/themes/$slug"
fi

user_dir="$HOME/.config/omarchy/backgrounds/$slug"
dirs=""

if [[ -n $theme_dir && -d $theme_dir/backgrounds ]]; then
  dirs="$theme_dir/backgrounds"
fi

if [[ -d $user_dir ]]; then
  if [[ -n $dirs ]]; then
    dirs+=$'\n'"$user_dir"
  else
    dirs="$user_dir"
  fi
fi

if [[ -z $dirs ]]; then
  printf '[]\n'
  exit 0
fi

list_sh="/usr/share/omarchy/shell/plugins/image-picker/list.sh"
first=true
printf '['
while IFS=$'\t' read -r path thumb; do
  [[ -n $path ]] || continue
  base=$(basename "$path")
  label="${base%.*}"
  if [[ $first == true ]]; then
    first=false
  else
    printf ','
  fi
  jq -cn \
    --arg path "$path" \
    --arg name "$label" \
    --arg thumbnailPath "$thumb" \
    '{path:$path, name:$name, thumbnailPath:$thumbnailPath}'
done < <(bash "$list_sh" "$dirs")
printf ']\n'

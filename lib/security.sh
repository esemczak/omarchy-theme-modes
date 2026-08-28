#!/bin/bash

set -euo pipefail

readonly THEME_MODES_MAX_STATE_BYTES=65536
readonly THEME_MODES_MAX_THEME_NAME_BYTES=256
readonly THEME_MODES_MAX_SCRIPT_OUTPUT_BYTES=1048576
readonly THEME_MODES_MAX_IMAGE_BYTES=52428800
readonly THEME_MODES_IMAGE_EXTENSIONS='jpg jpeg png gif bmp webp'

theme_modes_home="${HOME:?HOME is required}"
theme_modes_state_file="$theme_modes_home/.local/state/omarchy/settings/theme-modes.json"
theme_modes_current_theme_file="$theme_modes_home/.local/state/omarchy/current/theme.name"
theme_modes_preview_dir="${XDG_CACHE_HOME:-$theme_modes_home/.cache}/omarchy/theme-selector/previews"
theme_modes_image_cache_dir="${XDG_CACHE_HOME:-$theme_modes_home/.cache}/omarchy/image-selector"
theme_modes_omarchy_path="${OMARCHY_PATH:-/usr/share/omarchy}"

is_valid_slug() {
  local slug="${1:-}"
  [[ -n $slug && $slug != "." && $slug != ".." ]] || return 1
  [[ $slug =~ ^[a-z0-9]+$ || $slug =~ ^[a-z0-9]+([_-][a-z0-9]+)*$ ]]
}

slugify_name() {
  local value="${1:-}"
  [[ $value != *"/"* && $value != *"\\"* && $value != *".."* ]] || return 1
  value=$(printf '%s' "$value" | sed -E 's/<[^>]+>//g; s/[[:space:]]+/-/g; y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/; s/[^a-z0-9_-]+//g')
  while [[ $value == [-_]* ]]; do value=${value#?}; done
  while [[ $value == *[-_] ]]; do value=${value%?}; done
  while [[ $value == *--* ]]; do value=${value//--/-}; done
  while [[ $value == *-_* ]]; do value=${value//-_/-}; done
  while [[ $value == *_-* ]]; do value=${value//_-/}; done
  is_valid_slug "$value" || return 1
  printf '%s' "$value"
}

path_is_under_root() {
  local root="$1"
  local target="$2"
  local resolved_root resolved_target

  [[ -n $root && -n $target ]] || return 1
  resolved_root=$(readlink -f -- "$root" 2>/dev/null) || return 1
  resolved_target=$(readlink -f -- "$target" 2>/dev/null) || return 1
  [[ $resolved_target == "$resolved_root" || $resolved_target == "$resolved_root/"* ]]
}

ensure_private_directory() {
  local dir="$1"
  local resolved parent

  [[ -n $dir ]] || return 1
  if [[ -e $dir && -L $dir ]]; then
    return 1
  fi
  mkdir -p -- "$dir" || return 1
  resolved=$(readlink -f -- "$dir" 2>/dev/null) || return 1
  if [[ -L $resolved ]]; then
    return 1
  fi
  chmod 700 -- "$resolved" 2>/dev/null || true
  parent=$(dirname -- "$resolved")
  while [[ $parent != "/" && -n $parent ]]; do
    if [[ -L $parent ]]; then
      return 1
    fi
    parent=$(dirname -- "$parent")
  done
  printf '%s' "$resolved"
}

theme_modes_state_directory() {
  ensure_private_directory "$(dirname -- "$theme_modes_state_file")"
}

theme_modes_current_theme_directory() {
  ensure_private_directory "$(dirname -- "$theme_modes_current_theme_file")"
}

safe_read_regular_file() {
  local path="$1"
  local max_bytes="${2:-4096}"
  python3 - "$path" "$max_bytes" <<'PY'
import os
import stat
import sys

path = sys.argv[1]
max_bytes = int(sys.argv[2])

try:
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
except OSError:
    sys.exit(1)

try:
    st = os.fstat(fd)
    if not stat.S_ISREG(st.st_mode):
        sys.exit(2)
    if st.st_size > max_bytes:
        sys.exit(3)
    data = os.read(fd, max_bytes + 1)
    if len(data) > max_bytes:
        sys.exit(3)
    sys.stdout.buffer.write(data)
finally:
    os.close(fd)
PY
}

safe_write_regular_file() {
  local path="$1"
  local max_bytes="${2:-65536}"
  python3 - "$path" "$max_bytes" <<'PY'
import os
import stat
import sys
import tempfile

path = sys.argv[1]
max_bytes = int(sys.argv[2])
data = sys.stdin.buffer.read(max_bytes + 1)
if len(data) > max_bytes:
    sys.exit(3)

directory = os.path.dirname(path) or "."
os.makedirs(directory, mode=0o700, exist_ok=True)

if os.path.lexists(path):
    try:
        st = os.lstat(path)
    except OSError:
        sys.exit(4)
    if stat.S_ISLNK(st.st_mode) or not stat.S_ISREG(st.st_mode):
        sys.exit(4)

fd, tmp_path = tempfile.mkstemp(prefix=".theme-modes.", dir=directory)
try:
    with os.fdopen(fd, "wb") as handle:
        handle.write(data)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(tmp_path, path)
except Exception:
    try:
        os.unlink(tmp_path)
    except OSError:
        pass
    raise
PY
}

image_extension_for() {
  local path="$1"
  local base ext
  base=$(basename -- "$path")
  ext=${base##*.}
  ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
  case " $THEME_MODES_IMAGE_EXTENSIONS " in
    *" $ext "*) printf '%s' "$ext" ;;
    *) return 1 ;;
  esac
}

verify_regular_image_under() {
  local path="$1"
  local root="$2"
  local max_bytes="${3:-$THEME_MODES_MAX_IMAGE_BYTES}"
  local resolved

  [[ -n $path && -n $root ]] || return 1
  image_extension_for "$path" >/dev/null || return 1
  safe_read_regular_file "$path" "$max_bytes" >/dev/null || return 1
  resolved=$(readlink -f -- "$path" 2>/dev/null) || return 1
  path_is_under_root "$root" "$resolved" || return 1
  printf '%s' "$resolved"
}

theme_dir_for_slug() {
  local slug="$1"
  local user_dir stock_dir

  is_valid_slug "$slug" || return 1
  user_dir="$theme_modes_home/.config/omarchy/themes/$slug"
  if [[ -d $user_dir && ! -L $user_dir ]]; then
    readlink -f -- "$user_dir"
    return 0
  fi
  stock_dir="$theme_modes_omarchy_path/themes/$slug"
  if [[ -d $stock_dir && ! -L $stock_dir ]]; then
    readlink -f -- "$stock_dir"
    return 0
  fi
  return 1
}

background_roots_for_slug() {
  local slug="$1"
  local theme_dir user_dir

  is_valid_slug "$slug" || return 1
  theme_dir=$(theme_dir_for_slug "$slug" 2>/dev/null || true)
  if [[ -n $theme_dir && -d $theme_dir/backgrounds && ! -L $theme_dir/backgrounds ]]; then
    readlink -f -- "$theme_dir/backgrounds"
  fi
  user_dir="$theme_modes_home/.config/omarchy/backgrounds/$slug"
  if [[ -d $user_dir && ! -L $user_dir ]]; then
    readlink -f -- "$user_dir"
  fi
}

verify_background_path() {
  local slug="$1"
  local path="$2"
  local root verified

  is_valid_slug "$slug" || return 1
  [[ -n $path ]] || return 1
  while IFS= read -r root; do
    [[ -n $root ]] || continue
    verified=$(verify_regular_image_under "$path" "$root" "$THEME_MODES_MAX_IMAGE_BYTES" 2>/dev/null || true)
    if [[ -n $verified ]]; then
      printf '%s' "$verified"
      return 0
    fi
  done < <(background_roots_for_slug "$slug")
  return 1
}

theme_preview_roots_for_slug() {
  local slug="$1"
  local theme_dir

  is_valid_slug "$slug" || return 1
  ensure_private_directory "$theme_modes_preview_dir" >/dev/null || true
  printf '%s\n' "$theme_modes_preview_dir"
  theme_dir=$(theme_dir_for_slug "$slug" 2>/dev/null || true)
  [[ -n $theme_dir ]] && printf '%s\n' "$theme_dir"
}

verify_preview_path() {
  local slug="$1"
  local path="$2"
  local root verified resolved

  is_valid_slug "$slug" || return 1
  [[ -n $path && -e $path ]] || return 1

  if [[ -L $path ]]; then
    resolved=$(readlink -f -- "$path" 2>/dev/null) || return 1
    path="$resolved"
  fi

  while IFS= read -r root; do
    [[ -n $root ]] || continue
    verified=$(verify_regular_image_under "$path" "$root" "$THEME_MODES_MAX_IMAGE_BYTES" 2>/dev/null || true)
    if [[ -n $verified ]]; then
      printf '%s' "$verified"
      return 0
    fi
  done < <(theme_preview_roots_for_slug "$slug")
  return 1
}

verify_thumbnail_path() {
  local path="$1"
  local verified

  [[ -n $path ]] || return 1
  ensure_private_directory "$theme_modes_image_cache_dir" >/dev/null || return 1
  verified=$(verify_regular_image_under "$path" "$theme_modes_image_cache_dir" "$THEME_MODES_MAX_IMAGE_BYTES" 2>/dev/null || true)
  [[ -n $verified ]] || return 1
  printf '%s' "$verified"
}

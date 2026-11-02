#!/bin/bash
set -euo pipefail

# OpenCore Configurator 2.78.2.0 automatic validator repair for OpenCore 1.0.8.
# Run as the normal user. The script does not access the EFI partition.

domain=org.altervista.mackie100projects.OpenCore-Configurator
app="${OCC_APP_PATH:-/Applications/OpenCore Configurator.app}"
cache="${OCC_CACHE_DIR:-$HOME/Library/Caches/$domain/Validation/Developer}"
backups="${OCC_BACKUP_ROOT:-$HOME/Library/Application Support/OpenCore Configurator Validator Fix/backups}"
expected_sha256=c76f907d5caad299889a2314ae68f03cd8538ad53f65a3c2c7c95ae0d0bb0b38

pause_at_end() {
  if [[ -t 0 ]]; then
    printf '\nНатисни Enter, за да затвориш прозореца...'
    read -r _
  fi
}
trap pause_at_end EXIT

if [[ $EUID -eq 0 ]]; then
  printf 'Стартирай като обикновен потребител, без sudo.\n' >&2
  exit 2
fi

if [[ ${1:-} == --restore ]]; then
  backup="${2:-$backups/latest}"
  if [[ ! -d "$backup" ]]; then
    printf 'Няма резервно копие: %s\n' "$backup" >&2
    exit 1
  fi
  mkdir -p "$cache"
  for name in ocvalidate ocvalidate.zip; do
    if [[ -f "$backup/$name" ]]; then
      cp -p "$backup/$name" "$cache/$name"
    else
      rm -f "$cache/$name"
    fi
  done
  if [[ -f "$backup/configProp" ]]; then
    defaults write "$domain" configProp -string "$(cat "$backup/configProp")"
  else
    defaults delete "$domain" configProp >/dev/null 2>&1 || true
  fi
  printf 'Върнах първоначалния кеш и настройка от: %s\n' "$backup"
  exit 0
fi

if (( $# > 1 )) || [[ ${1:-} == --* ]]; then
  printf 'Употреба: %s [OpenCore-1.0.8-RELEASE.zip]\n' "$0" >&2
  printf 'Връщане: %s --restore [път-до-резервно-копие]\n' "$0" >&2
  exit 2
fi

if [[ ! -d "$app" && -d "$HOME/Applications/OpenCore Configurator.app" ]]; then
  app="$HOME/Applications/OpenCore Configurator.app"
fi
if [[ ! -f "$app/Contents/Info.plist" ]]; then
  printf 'Не намерих OpenCore Configurator.app. За друг път използвай OCC_APP_PATH.\n' >&2
  exit 1
fi

app_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
app_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")
if [[ "$app_version" != 2.78.2.0 || "$app_id" != "$domain" ]]; then
  printf 'Скриптът е проверен за Configurator 2.78.2.0; намерих %s (%s). Нищо не промених.\n' "$app_version" "$app_id" >&2
  exit 1
fi

temporary=$(mktemp -d "${TMPDIR:-/tmp}/occ108fix.XXXXXX")
trap 'rm -rf "$temporary"; pause_at_end' EXIT
archive="$temporary/OpenCore-1.0.8-RELEASE.zip"
if (( $# == 1 )); then
  if [[ ! -f "$1" ]]; then
    printf 'Не намерих архива: %s\n' "$1" >&2
    exit 1
  fi
  cp "$1" "$archive"
else
  printf 'Изтеглям официалния OpenCore 1.0.8 Release...\n'
  curl --fail --location --silent --show-error --retry 2 --max-time 180 \
    'https://github.com/acidanthera/OpenCorePkg/releases/download/1.0.8/OpenCore-1.0.8-RELEASE.zip' \
    -o "$archive"
fi

unzip -p "$archive" Utilities/ocvalidate/ocvalidate > "$temporary/ocvalidate"
unzip -p "$archive" Docs/Sample.plist > "$temporary/Sample.plist"
chmod 755 "$temporary/ocvalidate"
actual_sha256=$(shasum -a 256 "$temporary/ocvalidate" | awk '{print $1}')
if [[ "$actual_sha256" != "$expected_sha256" ]]; then
  printf 'Официалният валидатор не съвпада с проверения SHA-256. Нищо не промених.\n' >&2
  exit 1
fi
"$temporary/ocvalidate" "$temporary/Sample.plist" > "$temporary/test.log" 2>&1

old_profile=$(defaults read "$domain" configProp 2>/dev/null || true)
defaults write "$domain" configProp -string development
if [[ ${OCC_TEST_MODE:-0} != 1 ]]; then
  printf 'Стартирам OpenCore Configurator и изчаквам ресурсите му...\n'
  open -a "$app"
fi
for ((i=0; i<20; i++)); do
  if [[ -f "$cache/ocvalidate" && -f "$cache/ocvalidate.zip" ]]; then
    break
  fi
  sleep 1
done
if [[ ! -f "$cache/ocvalidate" || ! -f "$cache/ocvalidate.zip" ]]; then
  if [[ -n "$old_profile" ]]; then
    defaults write "$domain" configProp -string "$old_profile"
  else
    defaults delete "$domain" configProp >/dev/null 2>&1 || true
  fi
  printf 'Кешът на Development валидатора още липсва. Отвори Advanced OpenCore Validator веднъж и стартирай скрипта пак.\n' >&2
  exit 1
fi
if [[ ${OCC_TEST_MODE:-0} != 1 ]]; then
  sleep 2
fi

cached_sha256=$(shasum -a 256 "$cache/ocvalidate" | awk '{print $1}')
cached_zip_sha256=$(unzip -p "$cache/ocvalidate.zip" ocvalidate 2>/dev/null | shasum -a 256 | awk '{print $1}' || true)
if [[ "$cached_sha256" == "$expected_sha256" && "$cached_zip_sha256" == "$expected_sha256" ]]; then
  printf 'Автоматичната проверка вече използва официалния OpenCore 1.0.8 валидатор.\n'
  printf 'Отвори config.plist през Configurator, за да я пуснеш. Advanced OpenCore Validator продължава да изтегля стария ресурс.\n'
  exit 0
fi

mkdir -p "$backups"
backup="$backups/$(date +%Y%m%d-%H%M%S)-$$"
mkdir "$backup"
cp -p "$cache/ocvalidate" "$backup/ocvalidate"
cp -p "$cache/ocvalidate.zip" "$backup/ocvalidate.zip"
if [[ -n "$old_profile" ]]; then
  printf '%s\n' "$old_profile" > "$backup/configProp"
fi
ln -sfn "$backup" "$backups/latest"

# Keep the vendor archive's modification time. The app refreshes the cache when
# this timestamp changes, even if the validator itself is correct.
( cd "$temporary" && zip -q ocvalidate.zip ocvalidate )
touch -r "$cache/ocvalidate.zip" "$temporary/ocvalidate.zip"
cp "$temporary/ocvalidate" "$cache/ocvalidate.new"
cp -p "$temporary/ocvalidate.zip" "$cache/ocvalidate.zip.new"
chmod 755 "$cache/ocvalidate.new"
mv -f "$cache/ocvalidate.new" "$cache/ocvalidate"
mv -f "$cache/ocvalidate.zip.new" "$cache/ocvalidate.zip"

"$cache/ocvalidate" "$temporary/Sample.plist" > "$temporary/installed-test.log" 2>&1
printf 'Готово. Автоматичната проверка на Configurator използва официалния OpenCore 1.0.8 Release валидатор.\n'
printf 'Резервно копие: %s\n' "$backup"
printf 'Връщане: %s --restore\n' "$0"
printf 'Отвори config.plist през Configurator, за да видиш автоматичната проверка.\n'
printf 'Advanced OpenCore Validator още изтегля остарелия ресурс и може да показва фалшиви грешки.\n'
printf 'Ако заглавието е 1.0.7 Release, избери 1.0.8 Development в Preferences.\n'

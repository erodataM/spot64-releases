#!/bin/bash

set -euo pipefail

APP_TAG="${SPOT64_APP_TAG:-v0.1.0-beta.10}"
CORPUS_TAG="${SPOT64_CORPUS_TAG:-v0.1.0-beta.7}"
APP_ASSET="Spot64_0.1.0-beta.10_aarch64.dmg"
APP_SHA256="352aaf62b69c99f47e5cc48b6f0f13bb5784854c18daf68da3f4fa58309e5e72"
GENERATION_ID="4deebdced6fe5e3a1982bd10b1c91379164bc0bd46eaa9ce5bb95e20dbc8b9cc"
RELEASE_ROOT="https://github.com/erodataM/spot64-releases/releases/download"
RESOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DATA="$HOME/Library/Application Support/org.libase.desktop"
CACHE_ROOT="$HOME/Library/Caches/Spot64/download-cache"
CORPUS_CACHE="$CACHE_ROOT/$GENERATION_ID"
WORK_ROOT="$APP_DATA/.spot64-install-$$"
STAGE="$WORK_ROOT/stage"
MOUNT_POINT="$WORK_ROOT/mount"
TARGET="$APP_DATA/libase-store"

VOLUME_NAMES=(
  "spot64-corpus-4deebdced6fe-part-01.zip"
  "spot64-corpus-4deebdced6fe-part-02.zip"
  "spot64-corpus-4deebdced6fe-part-03.zip"
  "spot64-corpus-4deebdced6fe-part-04.zip"
  "spot64-corpus-4deebdced6fe-part-05.zip"
  "spot64-corpus-4deebdced6fe-part-06.zip"
)
VOLUME_HASHES=(
  "2a756a64bf2d84c8077ebe63134e63d6409676189564db77487ecc4a03cdaf0a"
  "d94ce1e93bc342c7e0581a1e4ef823ec7c33909e51235c6ab859d1b3b1e81f8b"
  "4456ea1dce2aab0d7cfafab57eccaae5b80b12264c77341b93f2f9e9875247d6"
  "00e1b6c3a4b1bb99323f286d7d06ee5c715f4826f61b2ed7ad831ebbda86c6eb"
  "e4586b80003e85f7b0144e4828754a64e4b397eeda866e34702e4f09c704f3b8"
  "acb57804dc41db1c6c69366d4e79185fd5ece75ec9f158fe8da34ae552e05ca4"
)

mounted=0
APP_STAGE="/Applications/.Libase.app.spot64-$$"

cleanup() {
  if [[ "$mounted" -eq 1 ]]; then
    /usr/bin/hdiutil detach "$MOUNT_POINT" -quiet || true
  fi
  if [[ -e "$APP_STAGE" ]]; then
    /bin/rm -rf "$APP_STAGE" || true
  fi
  if [[ -d "$WORK_ROOT" ]]; then
    /bin/rm -rf "$WORK_ROOT"
  fi
}
trap cleanup EXIT INT TERM

fail() {
  printf "\nERREUR: %s\n" "$1" >&2
  printf "L'installation a ete interrompue sans remplacer la base active.\n" >&2
  read -r -p "Appuyez sur Entree pour fermer..." || true
  exit 1
}

sha256() {
  /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

download_verified() {
  local url="$1"
  local destination="$2"
  local expected="$3"
  local label="$4"
  local partial="${destination}.part"

  if [[ -f "$destination" ]] && [[ "$(sha256 "$destination")" == "$expected" ]]; then
    printf "Deja verifie: %s\n" "$label"
    return
  fi

  printf "\nTelechargement: %s\n" "$label"
  /usr/bin/curl \
    --fail \
    --location \
    --retry 8 \
    --retry-all-errors \
    --continue-at - \
    --progress-bar \
    --output "$partial" \
    "$url" || fail "telechargement impossible: $label"

  [[ "$(sha256 "$partial")" == "$expected" ]] ||
    fail "empreinte SHA-256 incorrecte: $label"
  /bin/mv -f "$partial" "$destination"
}

has_verified_corpus() {
  [[ -f "$TARGET/current.json" ]] || return 1

  local active_generation
  active_generation="$(
    /usr/bin/plutil -extract currentGenerationId raw -o - "$TARGET/current.json" 2>/dev/null
  )" || return 1
  [[ "$active_generation" == "$GENERATION_ID" ]] || return 1

  (
    cd "$TARGET"
    /usr/bin/shasum -a 256 -c "$RESOURCE_DIR/corpus-files.sha256" >/dev/null 2>&1
  )
}

install_application() {
  local dmg="$1"
  local target="/Applications/Libase.app"
  local installed=0

  /bin/mkdir -p "$MOUNT_POINT"
  /usr/bin/hdiutil attach "$dmg" -nobrowse -readonly -mountpoint "$MOUNT_POINT" -quiet ||
    fail "impossible d'ouvrir l'image disque"
  mounted=1
  [[ -d "$MOUNT_POINT/Libase.app" ]] || fail "Libase.app est absent de l'image disque"

  if [[ -w "/Applications" ]]; then
    /bin/rm -rf "$APP_STAGE"
    if /usr/bin/ditto "$MOUNT_POINT/Libase.app" "$APP_STAGE" &&
      /usr/bin/xattr -dr com.apple.quarantine "$APP_STAGE" &&
      /bin/rm -rf "$target" &&
      /bin/mv "$APP_STAGE" "$target"; then
      installed=1
    fi
    /bin/rm -rf "$APP_STAGE"
  fi

  if [[ "$installed" -eq 0 ]]; then
    /usr/bin/osascript - "$MOUNT_POINT/Libase.app" <<'APPLESCRIPT' ||
on run argv
  set sourceApp to item 1 of argv
  set commandText to "/bin/rm -rf /Applications/Libase.app && " & ¬
    "/usr/bin/ditto " & quoted form of sourceApp & " /Applications/Libase.app && " & ¬
    "/usr/bin/xattr -dr com.apple.quarantine /Applications/Libase.app"
  do shell script commandText with administrator privileges
end run
APPLESCRIPT
      fail "installation de l'application refusee"
  fi

  /usr/bin/codesign --verify --deep --strict "$target" ||
    fail "signature locale de l'application invalide"
}

printf "\nSpot64 Beta pour macOS\n"
printf "======================\n\n"

[[ "$(/usr/bin/uname -m)" == "arm64" ]] ||
  fail "cette beta exige un Mac Apple Silicon (M1 ou plus recent)"
[[ -f "$RESOURCE_DIR/corpus-files.sha256" ]] ||
  fail "le manifeste de verification manque dans l'installateur"

reuse_corpus=0
if has_verified_corpus; then
  reuse_corpus=1
  printf "Corpus existant verifie: il sera reutilise sans telechargement.\n"
fi

available_kb="$(/bin/df -Pk "$HOME" | /usr/bin/awk 'NR == 2 {print $4}')"
if [[ "$reuse_corpus" -eq 1 ]]; then
  required_kb=$((2 * 1024 * 1024))
else
  required_kb=$((24 * 1024 * 1024))
fi
[[ "$available_kb" -ge "$required_kb" ]] ||
  fail "$((required_kb / 1024 / 1024)) Go libres sont requis pendant l'installation"

/bin/mkdir -p "$CORPUS_CACHE" "$STAGE" "$MOUNT_POINT"

APP_DMG="$CACHE_ROOT/$APP_ASSET"
download_verified \
  "$RELEASE_ROOT/$APP_TAG/$APP_ASSET" \
  "$APP_DMG" \
  "$APP_SHA256" \
  "application Spot64"

if [[ "$reuse_corpus" -eq 0 ]]; then
  for index in "${!VOLUME_NAMES[@]}"; do
    name="${VOLUME_NAMES[$index]}"
    download_verified \
      "$RELEASE_ROOT/$CORPUS_TAG/$name" \
      "$CORPUS_CACHE/$name" \
      "${VOLUME_HASHES[$index]}" \
      "corpus $((index + 1))/${#VOLUME_NAMES[@]}"
  done

  printf "\nExtraction du corpus (environ 17 Go)...\n"
  for name in "${VOLUME_NAMES[@]}"; do
    /usr/bin/ditto -x -k "$CORPUS_CACHE/$name" "$STAGE" ||
      fail "extraction impossible: $name"
  done

  POSITION_DIR="$STAGE/libase-store/generations/$GENERATION_ID/segments/base-000000/position.dir"
  /bin/mkdir -p "$(dirname "$POSITION_DIR")"
  /bin/cat \
    "$STAGE/.spot64-parts/000016-part-001" \
    "$STAGE/.spot64-parts/000016-part-002" \
    "$STAGE/.spot64-parts/000016-part-003" \
    > "$POSITION_DIR" || fail "reconstruction de l'index de positions impossible"

  printf "\nVerification complete du corpus...\n"
  (
    cd "$STAGE/libase-store"
    /usr/bin/shasum -a 256 -c "$RESOURCE_DIR/corpus-files.sha256"
  ) || fail "verification du corpus echouee"

  if [[ -e "$TARGET" ]]; then
    backup="$APP_DATA/libase-store.backup-$(/bin/date +%Y%m%d-%H%M%S)"
    /bin/mv "$TARGET" "$backup" ||
      fail "impossible de mettre l'ancienne base en securite"
    printf "Ancienne base conservee dans: %s\n" "$backup"
  fi

  /bin/mv "$STAGE/libase-store" "$TARGET" ||
    fail "activation atomique du corpus impossible"
fi

/usr/bin/osascript -e 'tell application "Libase" to quit' >/dev/null 2>&1 || true
/bin/sleep 2

install_application "$APP_DMG"

printf "\nInstallation terminee.\n"
printf "Spot64 contient 11 157 455 parties et un arbre de 40 demi-coups.\n"
/usr/bin/open -a "/Applications/Libase.app"

/usr/bin/osascript -e \
  'display dialog "Spot64 Beta est installe et pret a etre teste." buttons {"OK"} default button "OK" with title "Spot64 Beta"' \
  >/dev/null 2>&1 || true

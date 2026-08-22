#!/usr/bin/env bash
# sync-config.sh - copy personal configs from $HOME into the ISO skeleton
# so the live session boots exactly like the source machine.
#
# Whitelist approach: only named dirs/files are copied. App data and
# credential stores (mozilla, helium, opencode, gh, ...) never leave home.
#
# Live-user adaptation: the ISO user is "hycac" (not "helheim"), and the
# wallpaper/avatar are the bundled HYCAC art in /usr/share/backgrounds/hycac.
# All machine-specific paths are rewritten below, AFTER the rsyncs.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${HOME}/.config"
SKEL="${REPO}/archiso/airootfs/etc/skel"
DST="${SKEL}/.config"

DIRS=(niri noctalia fish alacritty foot shelly micro mpv gtk-3.0 gtk-4.0)
FILES=(starship.toml mimeapps.list user-dirs.dirs user-dirs.locale)

mkdir -p "${DST}"

for d in "${DIRS[@]}"; do
    if [ -d "${SRC}/${d}" ]; then
        rsync -a --delete "${SRC}/${d}/" "${DST}/${d}/"
    else
        echo "skip (no dir): ${SRC}/${d}"
    fi
done

for f in "${FILES[@]}"; do
    if [ -f "${SRC}/${f}" ]; then
        cp "${SRC}/${f}" "${DST}/${f}"
    else
        echo "skip (no file): ${SRC}/${f}"
    fi
done

# --- Noctalia runtime state (settings.toml holds the whole look & feel) ---
NSRC="${HOME}/.local/state/noctalia"
NDST="${SKEL}/.local/state/noctalia"
if [ -d "${NSRC}" ]; then
    mkdir -p "${NDST}"
    rsync -a --delete \
        --exclude clipboard \
        --exclude plugin-cache \
        --exclude 'notification_history*' \
        --exclude usage_counts.json \
        --exclude screen_time.json \
        --exclude recently_used.json \
        "${NSRC}/" "${NDST}/"
fi

# user-level systemd units (e.g. shelly-notifications)
if [ -d "${HOME}/.config/systemd/user" ]; then
    mkdir -p "${DST}/systemd/user"
    rsync -a --delete "${HOME}/.config/systemd/user/" "${DST}/systemd/user/"
fi

# ---------------------------------------------------------------------
# Machine-specific rewrites (must run AFTER the copies above)
#   1. live user is hycac, not the source-machine user
#   2. wallpapers/avatar point at the bundled HYCAC art
# ----------------------------------------------------------------------
grep -rl '/home/helheim' "${SKEL}" --exclude-dir=.git 2>/dev/null \
    | xargs -r sed -i 's#/home/helheim/#/home/hycac/#g'

NOCT_CFG="${DST}/noctalia/config.toml"
[ -f "${NOCT_CFG}" ] && sed -i \
    -e 's#^avatar_path = .*#avatar_path = "/usr/share/icons/hicolor/256x256/apps/hycac.png"#' \
    -e 's#^directory = .*#directory = "/usr/share/backgrounds/hycac"#' \
    "${NOCT_CFG}"

NOCT_SET="${NDST}/settings.toml"
if [ -f "${NOCT_SET}" ]; then
    sed -i 's#/home/[a-z]*/Pictures/Wallpapers/[^"]*#/usr/share/backgrounds/hycac/hycac-wallpaper.png#g' \
        "${NOCT_SET}"
fi

echo "---- skel overlay contents ----"
du -sh "${SKEL}"
find "${SKEL}" -maxdepth 2 | sort | head -30

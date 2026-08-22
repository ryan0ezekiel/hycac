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
#
# Two destinations:
#   skel/                      -> plain dotfiles (no package owns these paths)
#   usr/share/hycac/skel-overrides/  -> configs ALSO shipped by packages into
#      /etc/skel (niri, noctalia, alacritty, fish). Placing them in skel makes
#      pacstrap abort with "exists in filesystem", so they live in an override
#      staging area applied at boot by hycac-home.service (always wins).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${HOME}/.config"
SKEL="${REPO}/archiso/airootfs/etc/skel"
DST="${SKEL}/.config"
OVDST="${REPO}/archiso/airootfs/usr/share/hycac/skel-overrides/.config"

# NOTE: Noctalia v5 keeps ALL settings in ~/.local/state/noctalia/settings.toml.
# It has no ~/.config/noctalia directory - that was a v4 leftover on the source
# machine and must NOT be shipped or synced.
OVERRIDE_DIRS=(niri fish alacritty)
DIRS=(foot shelly micro mpv gtk-3.0 gtk-4.0 opencode)
FILES=(starship.toml mimeapps.list user-dirs.dirs user-dirs.locale)

mkdir -p "${DST}" "${OVDST}"

# purge any stale v4-era noctalia config from earlier iterations
rm -rf "${OVDST}/noctalia" "${DST}/noctalia"

for d in "${OVERRIDE_DIRS[@]}"; do
    if [ -d "${SRC}/${d}" ]; then
        rsync -a --delete "${SRC}/${d}/" "${OVDST}/${d}/"
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
grep -rl '/home/helheim' \
    "${REPO}/archiso/airootfs/etc/skel" \
    "${REPO}/archiso/airootfs/usr/share/hycac/skel-overrides" \
    --exclude-dir=.git 2>/dev/null \
    | xargs -r sed -i 's#/home/helheim/#/home/hycac/#g'

NOCT_SET="${NDST}/settings.toml"
if [ -f "${NOCT_SET}" ]; then
    sed -i 's#/home/[a-z]*/Pictures/Wallpapers/[^"]*#/usr/share/backgrounds/hycac/hycac-wallpaper.png#g' \
        "${NOCT_SET}"
fi

# ISO-only tweak: noctalia retry wrapper (cold live boot may outrun the
# network; a plain spawn-at-startup would die before NM is ready).
AUTOK="${OVDST}/niri/cfg/autostart.kdl"
if [ -f "${AUTOK}" ] && ! grep -q 'noctalia-resilient' "${AUTOK}"; then
    sed -i 's#^    spawn-at-startup "noctalia".*#    # ISO: noctalia-resilient (retry wrapper for cold live boot)\n    spawn-sh-at-startup "for i in $(seq 1 30); do /usr/bin/noctalia \&\& break; sleep 2; done"#' \
        "${AUTOK}"
fi

echo "---- skel overlay contents ----"
du -sh "${SKEL}"
find "${SKEL}" -maxdepth 2 | sort | head -30

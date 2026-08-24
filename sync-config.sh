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
        extra=()
        # The host config.fish is machine-specific and accumulates duplicate
        # tool-init blocks over time (200+ copies of the bun block at last
        # count). Never ship it; a curated live-session config is installed
        # below instead. Everything else in ~/.config/fish syncs normally.
        if [ "${d}" = "fish" ]; then
            extra+=(--exclude config.fish)
        fi
        rsync -a --delete "${extra[@]}" "${SRC}/${d}/" "${OVDST}/${d}/"
    else
        echo "skip (no dir): ${SRC}/${d}"
    fi
done

# --- curated fish config for the live session -----------------------------
# Lives ONLY in skel-overrides: cachyos-fish-config owns
# /etc/skel/.config/fish/, so shipping ours via plain skel would abort
# pacstrap with "exists in filesystem".
mkdir -p "${OVDST}/fish"
cat > "${OVDST}/fish/config.fish" <<'FISHRC'
# HYCAC live session - curated fish config.
# Installed by sync-config.sh; the host machine's config.fish is
# intentionally NOT shipped (it is machine-specific and collects
# duplicate tool-initialization blocks over time).

# CachyOS base interactive config (prompt, aliases, keybindings)
if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

function fish_greeting
    fastfetch --logo none
end

# opencode CLI
fish_add_path $HOME/.opencode/bin

# bun runtime (single guarded block)
set --export BUN_INSTALL "$HOME/.bun"
if test -d "$BUN_INSTALL/bin"
    fish_add_path "$BUN_INSTALL/bin"
end
FISHRC

for f in "${FILES[@]}"; do
    if [ -f "${SRC}/${f}" ]; then
        cp "${SRC}/${f}" "${DST}/${f}"
    else
        echo "skip (no file): ${SRC}/${f}"
    fi
done

# MIME policy: the ISO standardizes on evince for PDFs. The host machine may
# drift (it currently ships okular as its own default); never let that leak.
# evince's real desktop file is org.gnome.Evince.desktop on current Arch -
# plain "evince.desktop" does not resolve, so normalize to the real name.
MIME="${DST}/mimeapps.list"
if [ -f "${MIME}" ]; then
    sed -i -e 's#okular[A-Za-z_]*\.desktop#org.gnome.Evince.desktop#g' \
           -e 's#=evince\.desktop#=org.gnome.Evince.desktop#g' \
           -e '/^x-scheme-handler\/\(fdm\|magnet\)=freedownloadmanager/d' \
           -e '/^application\/x-bittorrent=freedownloadmanager/d' \
        "${MIME}"
    gawk -i inplace '
        /^\[/       { sec=$0 }
        sec=="[Default Applications]" && /^application\/pdf=/ { print "application/pdf=org.gnome.Evince.desktop"; next }
                    { print }
    ' "${MIME}"
fi

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

# xhost grants in autostart.kdl name the source-machine user; live user is hycac
grep -rl 'localuser:helheim' \
    "${REPO}/archiso/airootfs/etc/skel" \
    "${REPO}/archiso/airootfs/usr/share/hycac/skel-overrides" \
    2>/dev/null \
    | xargs -r sed -i 's#localuser:helheim#localuser:hycac#g'

NOCT_SET="${NDST}/settings.toml"
if [ -f "${NOCT_SET}" ]; then
    sed -i 's#/home/[a-z]*/Pictures/Wallpapers/[^"]*#/usr/share/backgrounds/hycac/hycac-wallpaper.png#g' \
        "${NOCT_SET}"
    # ISO: reset the wallpaper generation scheme to noctalia's shipped default
    #      ("auto"). The host machine's personal pick (m3-monochrome) must not
    #      leak into the live image; with the key absent noctalia falls back
    #      to its built-in default on first run.
    # NOTE: do NOT touch [widget.cat] input_devices here - the bongocat
    #      plugin only spawns its evtest reader when that key is present.
    sed -i '/^wallpaper_scheme[[:space:]]*=/d' "${NOCT_SET}"
fi

# ISO-only tweak: noctalia retry wrapper (cold live boot may outrun the
# network; a plain spawn-at-startup would die before NM is ready).
AUTOK="${OVDST}/niri/cfg/autostart.kdl"
if [ -f "${AUTOK}" ] && ! grep -q 'noctalia-resilient' "${AUTOK}"; then
    sed -i 's|^    spawn-at-startup "noctalia".*|    // ISO: noctalia-resilient (retry wrapper for cold live boot)\n    spawn-sh-at-startup "for i in $(seq 1 30); do /usr/bin/noctalia \&\& break; sleep 2; done"|' \
        "${AUTOK}"
fi

echo "---- skel overlay contents ----"
du -sh "${SKEL}"
find "${SKEL}" -maxdepth 2 | sort | head -30

# AGENT.md — working notes for agents operating this repo

HYCAC is a custom CachyOS-based live ISO built with archiso. Desktop is
niri + Noctalia shell, with a matching plymouth boot theme and graphical
GRUB menu. This file records the build/test workflow and every trap that
cost someone an afternoon. Read it before changing anything.

## Layout

| Path | Purpose |
|---|---|
| `buildiso.sh` | main build entry (mkarchiso driver) |
| `sync-config.sh` | injects user config into airootfs (KDL fixes, mimeapps normalization, noctalia settings rsync, machine-user rewrite) |
| `archiso/pacman.conf` | ISO package sources — cachyos-v3 repos MUST stay first |
| `archiso/packages_hycac.x86_64` | package list |
| `archiso/grub/` | GRUB theme (`theme/hycac/{bg.png,theme.txt,*_c.png}`), `grub.cfg`, `fonts/unicode.pf2` |
| `archiso/airootfs/usr/share/plymouth/themes/hycac/` | boot splash theme |
| `archiso/airootfs/usr/share/backgrounds/hycac/hycac-wallpaper.png` | live-env wallpaper (3840×2160) |
| `tests/probe.sh` | post-boot verification battery (48 checks) |
| `out/hycac/` | build output (gitignored) |

## Build

```
/home/helheim/Projects/ISO/hycac/sync-config.sh   # ALWAYS run first - it
                                                  # generates the airootfs
                                                  # config files; buildiso
                                                  # does NOT call it
/home/helheim/Projects/ISO/build-launch.sh        # detached builder (~25-40 min)
```

* Takes ~35–40 min. Progress: `tr '\r' '\n' < /tmp/opencode/hycac-build.log | grep '%'`
* Output lands in `out/hycac/hycac-hycac-linux-<date>.iso`.
* `pacman.conf` resolves `Include=/etc/pacman.d/cachyos-v3-mirrorlist`
  against the BUILD HOST's mirrorlist — keep the v3 repos ordered before
  core/extra or you silently get older `-3` builds instead of `-3.1`
  (this bit us once with noctalia).

## VM test workflow

Harness lives outside the repo at `~/.cache/hycac-test/`
(`test-boot.sh`, `test-uefi.sh`, `test-debug.sh`, `verify-build4.sh`,
`scan.py`, cached kernel/initrd). `/tmp/opencode` gets tmp-cleaned —
never store anything durable there.

Per-build steps:

1. Mount the new ISO and extract kernel+initramfs to the cache dir.
2. **Refresh the UUID**: `basename /mnt/boot/*.uuid .uuid` and sed it into
   `test-boot.sh` / `test-debug.sh`. A stale `archisosearchuuid=` makes
   the boot hang forever on "Device not found" — it will look like a
   plymouth bug but isn't.
3. BIOS boot test: `~/.cache/hycac-test/test-boot.sh <initrd> <seconds>`
   (QEMU with `-kernel/-initrd`, serial monitor sockets at
   `/tmp/opencode/qemu-mon` and `/tmp/opencode/serial-ctl`).
4. UEFI/GRUB test: `test-uefi.sh <seconds>` (OVMF direct cdrom boot).
5. Frame analysis: screendump via monitor socket, inspect with
   `scan.py`/PIL. Track color `(38,38,44)` drains as red `(229,72,77)`
   grows. Transparency check = count exact `(16,16,21)` background
   pixels (must be 0). Glyph presence = `(236,236,241)`±25 pixels in the
   center band.
6. Serial-inject login (user `hycac`, empty password) then run
   `tests/probe.sh` — it orchestrates from the HOST over ssh port 2223.

### Guest shell is fish

POSIX `if/then` syntax fails over serial. Wrap anything non-trivial:

```
bash -lc '<script>'
```

## Known traps (do not rediscover these)

**Plymouth script engine**
* `[script]` section MUST define `ImageDir=` — missing it segfaults
  (`script_lib_image_setup` strdups NULL).
* `Image()`/`Sprite()` creation works ONLY at file scope. Inside `fun`
  bodies the calls parse and execute silently but produce nothing.
  Functions CAN reposition existing sprites and toggle `.opacity`.
* Therefore: create sprite pools at file scope, do all responsive layout
  inside `boot_progress_cb` where `Window.GetWidth/Height` are valid.

**GRUB**
* Archiso's embedded grub.cfg sets `$root` but NOT `$prefix` (prefix
  stays pointed at the memdisk). Anchor theme paths as
  `(${root})/boot/grub/theme/hycac/theme.txt`, and give `loadfont` a
  `${prefix}` attempt followed by a `(${root})` fallback.
* Theme fonts must be `loadfont`ed BEFORE `set theme` runs - boot_menu
  resolves font names at theme-apply time; an unloaded name aborts the
  whole theme back to console mode.
* `+ boot_menu` REQUIRES an explicit `height` WITH HEADROOM: height=210
  with 42px items shows only FOUR of five entries (GRUB's scroller needs
  strict slack). height=240 shows all five. Verify by COUNTING entries.
* A transparent bg.png composites over BLACK - `desktop-color:` is NOT
  what shows through alpha. To match plymouth's canvas exactly, bake the
  color opaque into the PNG (bg.png is solid #101015 + emblem).
* The brand mark in `theme/hycac/bg.png` is rendered from
  `branding/hycac.svg` via rsvg-convert (recolored #ECECF1), NOT upscaled
  raster. Current recipe: render at ~558×648, paste centered-x /
  center-y at 38% on a solid #101015 3840×2160 canvas.
* The menu is styled to mirror the plymouth tribar zone: unselected text
  #ECECF1 (emblem white), selected text #E5484D (bar red) over a faint
  red wash select_*.png rgba(229,72,77,50) - over #101015 that wash
  reads as ~(58,31,32) in screendumps. Font is JetBrains Mono Regular 18
  pre-rendered to pf2 (grub-mkfont, committed) - zero extra ISO packages.
* mkarchiso copies non-`.cfg` files under profile `grub/` recursively to
  ISO `/boot/grub/` — fonts and themes ship fine, just don't rename.
* GRUB and plymouth rasterize only png/jpeg/tga. No SVG at runtime. For
  high-res scaling ship big PNGs rendered FROM the SVG sources.

**Tooling**
* `pkill -f <pattern>` matches the tool-batch's own shell command line
  (launch text lives in argv). Use `pkill -x`, split patterns
  (`'qemu-sys''tem'`), or put commands in script files first.
* QEMU instances occasionally die from stray SIGTERMs sent to the whole
  process group — launch them under `setsid`.
* Local QEMU uses `-vga std` (bochs-drm) which provides NO
  `/dev/dri/renderD128`, and this QEMU build has no virtio-gpu. So niri
  sees zero outputs, the bar never renders, and the bongocat widget never
  instantiates → its probe must `vm-skip` locally. This is a limitation
  of the test rig, not an ISO bug.
* Noctalia bongocat spawns `evtest` only when `[widget.cat] input_devices`
  exists (NOT `[widget.bongocat]`), `evtest` is installed, and the user is
  in the `input` group. Do not strip the key.
* Root GUI apps (gparted, ventoy, btrfs-assistant) need `xorg-xhost`
  shipped — niri's autostart grants root access to the XWayland display
  via `xhost +SI:localuser:root`, and xwayland-satellite honors those
  grants. Without the binary the grant silently fails ("command not
  found") and elevated apps die with "Authorization required".
* gparted quirk: `/usr/bin/gparted` passes args straight to gpartedbin,
  which treats `--version` as a DEVICE argument and then runs its main
  loop. Don't use `--version` for liveness checks; check `pgrep
  gpartedbin` after launching instead.
* ssh into the VM from fish-remote shells: wrap everything in
  `bash -lc`, and remember remote commands inherit no descriptors —
  dbus-launch children keep stdout open and hang ssh; detach with
  `setsid ... >/file 2>&1 </dev/null &`.

## Definition of green

* probe battery: 48/48 PASS (bongocat may report vm-skip)
* UEFI: GRUB theme renders - big centered brand mark, header line, and
  ALL FIVE menu entries (count them; missing height = silent clipping)
* BIOS: plymouth shows glyphs steady, zero opaque-box pixels, tribar
  animates (track drains, red grows)
* live fish greeting runs plain `fastfetch` (logo shown)

## Git

Remote: `https://github.com/ryan0ezekiel/hycac.git`, branch `main`.
No global git identity on this machine — commit with:

```
git -c user.name=helheim -c user.email=helheim@hycac.local commit
```

Never commit `out/`, `work/`, `*.iso`, or `plugins/sources/` (all
gitignored).

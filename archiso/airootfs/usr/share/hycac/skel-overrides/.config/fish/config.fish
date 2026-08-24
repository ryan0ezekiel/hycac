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

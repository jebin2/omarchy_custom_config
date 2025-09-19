# Hyprland Custom Config

This repository contains my personal configuration files, scripts, and custom utilities for the Hyprland window manager and Waybar.

### Features

*   **Custom Waybar:** Modules for GPU memory, network ports, and a clickable window title.
*   **Rust Utilities:**
    *   `clock`: A terminal-based calendar application.
    *   `HyprlandWindowSwitcher`: A visual, terminal-based window switcher.
*   **Helper Scripts:** Various shell scripts for displaying system information and managing windows.

### Build

To build the custom Rust applications, navigate into the `clock` and `HyprlandWindowSwitcher` directories and run:

```bash
cargo build --release
```

The Waybar configuration expects the compiled binaries in their respective `target/release/` folders.
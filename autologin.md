# Headless Laptop VNC Setup (Linux Mint + Tailscale + x11vnc)

This document describes how a laptop was converted into a **headless, always-accessible server** using:

- Linux Mint (Cinnamon)
- x11vnc
- Tailscale
- Auto-login
- Screen dim/off (battery-friendly)
- Lid closed operation
- No auto-lock
- No SSH tunnel required for VNC

---

## Goals

- ✅ Always accessible via VNC
- ✅ No physical screen usage (battery saving)
- ✅ Auto-start on boot
- ✅ Works even when lid is closed
- ✅ Secure access (Tailscale)
- ❌ No suspend
- ❌ No auto-lock
- ❌ No SSH tunneling overhead

---

## 1. Auto-login (Required)

Auto-login is mandatory because **x11vnc attaches to a real desktop session (`:0`)**.

For GDM (most common on Mint):

```bash
sudo nano /etc/gdm3/custom.conf
````

```ini
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=homeserver
```

Reboot once to confirm auto-login works.

---

## 2. Disable Suspend on Lid Close

```bash
sudo nano /etc/systemd/logind.conf
```

Ensure these are set (uncommented):

```ini
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
LidSwitchIgnoreInhibited=yes
```

Apply:

```bash
sudo systemctl restart systemd-logind
```

---

## 3. Allow Auto-login Even When Lid Is Closed (Important)

### 3.1 Force lid state open at boot (ThinkPad fix)

```bash
sudo nano /etc/default/grub
```

```ini
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash button.lid_init_state=open"
```

Apply:

```bash
sudo update-grub
sudo reboot
```

---

### 3.2 Ignore lid state in Xorg

```bash
sudo mkdir -p /etc/X11/xorg.conf.d
sudo nano /etc/X11/xorg.conf.d/10-ignore-lid.conf
```

```ini
Section "ServerFlags"
    Option "IgnoreLidSwitch" "true"
EndSection
```

---

## 4. Disable Auto-Lock (Very Important)

```bash
gsettings set org.cinnamon.desktop.screensaver lock-enabled false
gsettings set org.cinnamon.desktop.screensaver idle-activation-enabled false
```

Verify:

```bash
gsettings get org.cinnamon.desktop.screensaver lock-enabled
# should be false
```

---

## 5. Install x11vnc

```bash
sudo apt install x11vnc
```

Set a VNC password (one time):

```bash
x11vnc -storepasswd
```

---

## 6. systemd Service for x11vnc (FINAL, WORKING VERSION)

```bash
sudo nano /etc/systemd/system/x11vnc.service
```

```ini
[Unit]
Description=x11vnc (user session, headless)
After=graphical.target
Wants=graphical.target

[Service]
Type=simple
User=homeserver
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/homeserver/.Xauthority
ExecStart=/usr/bin/x11vnc -forever -usepw -noxdamage
Restart=always
RestartSec=3

[Install]
WantedBy=graphical.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable x11vnc
sudo systemctl restart x11vnc
```

Verify:

```bash
ss -tulpn | grep 5900
# should show 0.0.0.0:5900
```

---

## 7. Tailscale Setup

Ensure Tailscale is installed and running:

```bash
tailscale status
tailscale ip
```

Use the **100.x.x.x** address to connect.

---

## 8. Connect via VNC (Fast, No SSH Tunnel)

From client machine:

```bash
gvncviewer <tailscale-ip>:5900
```

Example:

```bash
gvncviewer 100.126.254.91:5900
```

---

## 9. Screen Power Saving (Auto-Dim Instead of OFF)

### Recommended: Cinnamon Power Settings

* Menu → Preferences → Power Management
* Enable **Dim screen when inactive**
* Set brightness reduction (20–30%)
* Disable “Turn off screen” if not desired

---

### Optional: Auto-dim on login via `.xprofile`

```bash
nano ~/.xprofile
```

Example:

```bash
xrandr --output eDP-1 --brightness 0.3
```

(Find display name with `xrandr | grep connected`)

---

## 10. Optional Headless Alias

```bash
nano ~/.bashrc
```

```bash
alias headless='xrandr --output eDP-1 --brightness 0.3'
```

Reload:

```bash
source ~/.bashrc
```

---

## 11. Behavior Summary

| Action            | Result               |
| ----------------- | -------------------- |
| Reboot            | ✅ VNC auto-available |
| Lid closed        | ✅ Works              |
| Screen dimmed/off | ✅ Works              |
| Lock screen       | ❌ Disabled           |
| Logout            | ❌ Kills VNC          |
| Suspend           | ❌ Disabled           |
| Battery drain     | ~1–2% / hour         |

---

## 12. Key Rules (Do NOT Break These)

* ❌ Never log out
* ❌ Never suspend / hibernate
* ✅ Use lockless + auto-login
* ✅ Screen power saving only (DPMS / dim)
* ✅ Access only via Tailscale

---

## Result

🎉 The laptop now behaves like a **true headless server**:

* Always accessible
* Battery friendly
* Secure
* No physical interaction required
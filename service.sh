#!/bin/sh
# Keeps LawEditor's server always on, so the timers the chats set come due with no window open.
#
#   ./service.sh install   the computer starts the server when you log in, and starts it again if it stops
#   ./service.sh remove    back to starting it yourself (bun run start)
#   ./service.sh status    is it installed, and is the server answering
#
# The server keeps the clock (engine/CLOCK.bend): a timer comes due only while the server runs. On macOS
# this hands the server to launchd; on Linux, to systemd (your own services, no root). It is the same
# server as bun run start, in the same home (~/LawEditor, or LAWEDITOR_HOME), on the same port. A computer
# that sleeps runs nothing: a timer whose time passed meanwhile starts one turn when it wakes.
#
# Build first (bun run start builds everything), and stop a server you started by hand: two can't share a port.
set -e
root=$(cd "$(dirname "$0")" && pwd)
home=${LAWEDITOR_HOME:-$HOME/LawEditor}
port=${LAWEDITOR_PORT:-4280}
name=games.mage.laweditor
bin="$root/dist/laweditor-server"
log="$home/.server.log"

answers() { curl -s -m 3 "http://127.0.0.1:$port/api/told/HARNESS.md" 2>/dev/null | grep -q .; }

case "$(uname)" in
  Darwin) plist="$HOME/Library/LaunchAgents/$name.plist" ;;
  *)      unit="$HOME/.config/systemd/user/laweditor.service" ;;
esac

install() {
  [ -x "$bin" ] || { echo "Build it first: bun run build && bun run server && bun run cli"; exit 1; }
  if answers; then echo "A server already answers on port $port. Stop it first, then install."; exit 1; fi
  mkdir -p "$home"
  # The server starts the AIs' own commands (claude, codex) and bend: it needs the PATH this terminal has.
  if [ -n "$plist" ]; then
    mkdir -p "$(dirname "$plist")"
    cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$name</string>
  <key>ProgramArguments</key><array><string>$bin</string><string>$root</string></array>
  <key>WorkingDirectory</key><string>$home</string>
  <key>EnvironmentVariables</key><dict>
    <key>PATH</key><string>$PATH</string>
    <key>HOME</key><string>$HOME</string>
    <key>LAWEDITOR_PORT</key><string>$port</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$log</string>
  <key>StandardErrorPath</key><string>$log</string>
</dict></plist>
PLIST
    launchctl bootout "gui/$(id -u)/$name" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$plist"
  else
    mkdir -p "$(dirname "$unit")"
    cat > "$unit" <<UNIT
[Unit]
Description=LawEditor's server

[Service]
WorkingDirectory=$home
ExecStart=$bin $root
Environment=PATH=$PATH
Environment=LAWEDITOR_PORT=$port
Restart=always
RestartSec=3
StandardOutput=append:$log
StandardError=append:$log

[Install]
WantedBy=default.target
UNIT
    systemctl --user daemon-reload
    systemctl --user enable --now laweditor.service
    # Without this, a Linux computer stops your services when you log out.
    loginctl enable-linger "$(id -un)" 2>/dev/null || echo "Run once, so it keeps going after you log out: sudo loginctl enable-linger $(id -un)"
  fi
  i=0; while [ $i -lt 20 ] && ! answers; do sleep 0.5; i=$((i+1)); done
  if answers; then echo "LawEditor is always on: http://127.0.0.1:$port  (what it prints: $log)"
  else echo "Installed, but the server doesn't answer yet. Read $log"; exit 1; fi
}

remove() {
  if [ -n "$plist" ]; then
    launchctl bootout "gui/$(id -u)/$name" 2>/dev/null || true
    rm -f "$plist"
  else
    systemctl --user disable --now laweditor.service 2>/dev/null || true
    rm -f "$unit"; systemctl --user daemon-reload 2>/dev/null || true
  fi
  echo "Removed. Start LawEditor yourself with: bun run start"
}

status() {
  if [ -e "${plist:-$unit}" ]; then echo "Installed: ${plist:-$unit}"; else echo "Not installed."; fi
  if answers; then echo "The server answers on port $port."; else echo "No server answers on port $port."; fi
}

case "$1" in
  install) install ;;
  remove)  remove ;;
  status)  status ;;
  *) echo "usage: ./service.sh install | remove | status"; exit 1 ;;
esac

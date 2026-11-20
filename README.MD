# macOS *arr & Transmission Health Monitor (`arr_monitor`)

A lightweight, self-healing monitoring daemon (`launchd` + Bash) built for macOS (tested on Apple Silicon Mac mini M4) to continuously supervise **Sonarr**, **Radarr**, **Prowlarr**, and **Transmission**[span_5](start_span)[span_5](end_span)[span_6](start_span)[span_6](end_span).

## Overview

When running a headless media server accessed remotely over **Tailscale** via mobile companion apps (**Helmarr** and **Ruddar**) or **Screens 5**, an application can still appear "running" in macOS Activity Monitor while its internal web server is completely hung[span_7](start_span)[span_7](end_span)[span_8](start_span)[span_8](end_span). When that happens, API connections drop and remote queue management stalls[span_9](start_span)[span_9](end_span)[span_10](start_span)[span_10](end_span).

`arr_monitor` solves this by combining **OS-level process checks** with **HTTP API responsiveness checks** (`curl` with a 5-second timeout), automatically force-quitting and relaunching hung services and sending native macOS desktop alerts[span_11](start_span)[span_11](end_span)[span_12](start_span)[span_12](end_span).

---

## Features

- **Dual-Layer Health Detection:** Verifies both active process existence (`pgrep`) and HTTP server responsiveness (`curl --max-time 5`)[span_13](start_span)[span_13](end_span)[span_14](start_span)[span_14](end_span).
- **Self-Healing Recovery:** Automatically terminates (`killall -9`) missing or hung instances and relaunches them cleanly (`open -a`)[span_15](start_span)[span_15](end_span)[span_16](start_span)[span_16](end_span).
- **Native macOS Notifications:** Triggers desktop banner alerts via `osascript` whenever a service is restarted[span_17](start_span)[span_17](end_span)[span_18](start_span)[span_18](end_span).
- **Native `launchd` Orchestration:** Runs silently in the background as a user `LaunchAgent` with immediate startup on login (`RunAtLoad`) and scheduled hourly checks (`StartInterval = 3600`)[span_19](start_span)[span_19](end_span)[span_20](start_span)[span_20](end_span).
- **VPN & Tailscale Friendly:** Designed for headless setups running split-tunneled VPNs (e.g., ExpressVPN for Transmission) alongside Tailscale mesh access[span_21](start_span)[span_21](end_span).

---

## Installed File Locations

| Component | Installed Path |
| :--- | :--- |
| **Monitoring Script** | `~/Scripts/arr_monitor.sh` (`/Users/YOUR_USERNAME/Scripts/arr_monitor.sh`)[span_22](start_span)[span_22](end_span) |
| **`launchd` Agent Plist** | `~/Library/LaunchAgents/com.user.arrmonitor.plist`[span_23](start_span)[span_23](end_span) |
| **Standard Output Log** | `/tmp/arrmonitor.log`[span_24](start_span)[span_24](end_span) |
| **Error Log** | `/tmp/arrmonitor.err`[span_25](start_span)[span_25](end_span) |

---

## Monitored Services & Default Ports

| Service | Port | Local Endpoint Checked | Healthy HTTP Codes |
| :--- | :---: | :--- | :--- |
| **Sonarr** | `8989` | `http://127.0.0.1:8989/` | `200`, `301`, `302`, `401`[span_26](start_span)[span_26](end_span) |
| **Radarr** | `7878` | `http://127.0.0.1:7878/` | `200`, `301`, `302`, `401`[span_27](start_span)[span_27](end_span) |
| **Prowlarr** | `9696` | `http://127.0.0.1:9696/` | `200`, `301`, `302`, `401`[span_28](start_span)[span_28](end_span) |
| **Transmission** | `9091` | `http://127.0.0.1:9091/` | `200`, `301`, `302`, `401`[span_29](start_span)[span_29](end_span) |

---

## Source Files

### 1. `~/Scripts/arr_monitor.sh`

```bash
#!/bin/bash

# Configuration: App Names and their default API ports
APPS=("Sonarr" "Radarr" "Prowlarr" "Transmission")
PORTS=(8989 7878 9696 9091)

# Function to send macOS system notifications
send_notification() {
    local app_name="$1"
    local message="$2"
    osascript -e "display notification \"$message\" with title \"Service Monitor\" subtitle \"Restarted $app_name\""
}

# Loop through each application by index
for i in "${!APPS[@]}"; do
    APP_NAME="${APPS[$i]}"
    PORT="${PORTS[$i]}"
    
    # 1. Check if the application process is running at all
    if ! pgrep -xq "[A-Za-z0-9_-]*$APP_NAME[A-Za-z0-9_-]*"; then
        echo "$(date):$APP_NAME process not found. Restarting..."
        killall -9 "$APP_NAME" 2>/dev/null
        open -a "$APP_NAME"
        send_notification "$APP_NAME" "Process was missing. Relaunched successfully."
        continue
    fi

    # 2. HTTP API Health Check (with a 5-second timeout)
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "[http://127.0.0.1](http://127.0.0.1):$PORT/")

    # Consider 200, 301, 302, 401 as healthy web server responses
    if [[ "$HTTP_STATUS" =~ ^(200\vert{}301\vert{}302\vert{}401)$ ]]; then
        echo "$(date): $APP_NAME is healthy (HTTP Status:$HTTP_STATUS)."
    else
        echo "$(date): $APP_NAME failed health check (HTTP Status:$HTTP_STATUS). Force-quitting and restarting..."
        killall -9 "$APP_NAME" 2>/dev/null
        sleep 2
        open -a "$APP_NAME"
        send_notification "$APP_NAME" "Web server hung (Status: $HTTP_STATUS). Force-restarted."
    fi
done
```[span_30](start_span)[span_30](end_span)

### 2. `~/Library/LaunchAgents/com.user.arrmonitor.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "[http://www.apple.com/DTDs/PropertyList-1.0.dtd](http://www.apple.com/DTDs/PropertyList-1.0.dtd)">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.arrmonitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/YOUR_USERNAME/Scripts/arr_monitor.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StartInterval</key>
    <integer>3600</integer>
    <key>StandardOutPath</key>
    <string>/tmp/arrmonitor.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/arrmonitor.err</string>
</dict>
</plist>
```[span_31](start_span)[span_31](end_span)[span_32](start_span)[span_32](end_span)

---

## Installation

1. **Create the script directory and make `arr_monitor.sh` executable:**
   ```bash
   mkdir -p ~/Scripts
   cp arr_monitor.sh ~/Scripts/arr_monitor.sh
   chmod +x ~/Scripts/arr_monitor.sh

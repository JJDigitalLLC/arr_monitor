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
        echo "$(date): $APP_NAME process not found. Restarting..."
        killall -9 "$APP_NAME" 2>/dev/null
        open -a "$APP_NAME"
        send_notification "$APP_NAME" "Process was missing. Relaunched successfully."
        continue
    fi

    # 2. HTTP API Health Check (with a 5-second timeout)
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://127.0.0.1:$PORT/")

    # Consider 200, 301, 302, 401 as healthy web server responses
    if [[ "$HTTP_STATUS" =~ ^(200|301|302|401)$ ]]; then
        echo "$(date): $APP_NAME is healthy (HTTP Status: $HTTP_STATUS)."
    else
        echo "$(date): $APP_NAME failed health check (HTTP Status: $HTTP_STATUS). Force-quitting and restarting..."
        killall -9 "$APP_NAME" 2>/dev/null
        sleep 2
        open -a "$APP_NAME"
        send_notification "$APP_NAME" "Web server hung (Status: $HTTP_STATUS). Force-restarted."
    fi
done

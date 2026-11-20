
# Technical Documentation & Operations Guide (`USAGE.md`)

This guide covers day-to-day testing, failure simulation, desktop notification verification, log inspection, `launchd` service management, and headless server uptime practices for **`arr_monitor`**[span_4](start_span)[span_4](end_span)[span_5](start_span)[span_5](end_span)[span_6](start_span)[span_6](end_span)[span_7](start_span)[span_7](end_span).

---

## 1. Manual Testing

Execute the monitoring script directly in Terminal at any time to perform an immediate health sweep across **Sonarr**, **Radarr**, **Prowlarr**, and **Transmission**[span_8](start_span)[span_8](end_span):

```bash
~/Scripts/arr_monitor.sh


Expected Healthy Output

Thu Nov 12 09:48:50 CST 2026: Sonarr is healthy (HTTP Status: 302).
Thu Nov 12 09:48:50 CST 2026: Radarr is healthy (HTTP Status: 302).
Thu Nov 12 09:48:50 CST 2026: Prowlarr is healthy (HTTP Status: 302).
Thu Nov 12 09:48:50 CST 2026: Transmission is healthy (HTTP Status: 401).


(Note: HTTP 302 redirects to the login page for *arr services and HTTP 401 authentication prompts from Transmission confirm each service's internal web server is awake and responsive.)

Logging a Manual Test Run

Running ~/Scripts/arr_monitor.sh directly in Terminal prints output to your screen rather than /tmp/arrmonitor.log. To record a manual test run in the standard log file as well:

~/Scripts/arr_monitor.sh >> /tmp/arrmonitor.log 2>&1


2. Simulating Failures (Crash & Hang Tests)

Test A: Simulating a Crashed / Missing Process

Verify that arr_monitor detects a stopped service, relaunches it, and sends a macOS desktop alert:

1. Force-stop one of the monitored apps (for example, Prowlarr):
   killall -9 Prowlarr
   
2. Confirm the process is stopped (should return nothing):
   pgrep -l Prowlarr
   
3. Run the monitoring script manually:
   ~/Scripts/arr_monitor.sh
   
   Expected result: Terminal outputs Prowlarr process not found. Restarting..., relaunches Prowlarr, and triggers a macOS desktop notification.
4. Confirm recovery:
   pgrep -l Prowlarr
   
   Running ~/Scripts/arr_monitor.sh a second time should report Prowlarr as healthy (HTTP Status: 302).

Test B: Simulating a Frozen / Hung Web Server (SIGSTOP)

Verify Layer 2 detection—where an app process still exists in Activity Monitor (pgrep succeeds) but its web API refuses to respond within the 5-second curl timeout (HTTP Status: 000):

1. Pause the process without killing it (e.g., Prowlarr):
   killall -STOP Prowlarr
   
2. Run the monitoring script:
   ~/Scripts/arr_monitor.sh
   
   Expected result: After waiting 5 seconds for the HTTP timeout, the script outputs Prowlarr failed health check (HTTP Status: 000). Force-quitting and restarting..., terminates the frozen process, relaunches Prowlarr, and sends a desktop notification.

3. Verifying macOS Desktop Notifications

Trigger the script's exact osascript alert command directly in Terminal to test notification delivery without stopping a live service:

osascript -e 'display notification "Web server hung. Force-restarted." with title "Service Monitor" subtitle "Restarted Sonarr"'


Troubleshooting Missing Banners

If no notification banner slides into view at the top-right corner of your screen:

1. Check Focus / Do Not Disturb: Open Control Center in the macOS menu bar and confirm Do Not Disturb or any active Focus mode is turned off.
2. Check Notification Permissions: Go to System Settings → Notifications, select Terminal (and Script Editor, if listed), and confirm Allow Notifications is toggled ON with Banners or Alerts enabled.

4. Inspecting & Clearing Logs

Automated runs triggered by launchd pipe stdout and stderr to /tmp/arrmonitor.log and /tmp/arrmonitor.err. (Note: macOS automatically clears /tmp/ whenever the Mac reboots.)

Action	Terminal Command
View standard health-check log	cat /tmp/arrmonitor.log
View error log (empty when healthy)	cat /tmp/arrmonitor.err
Stream logs in real time	tail -f /tmp/arrmonitor.log
Truncate logs to 0 bytes	> /tmp/arrmonitor.log && > /tmp/arrmonitor.err
Delete log files completely	rm -f /tmp/arrmonitor.log /tmp/arrmonitor.err

5. Managing the launchd Background Service

⚬ Check service registration, run count, and interval:
  launchctl print gui/$(id -u)/com.user.arrmonitor
  
  (Note: state = not running between scheduled runs is normal for interval-based launchd agents.)
⚬ Stop & unload the background agent:
  launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.user.arrmonitor.plist
  
⚬ Load / reload the background agent after making edits:
  launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.arrmonitor.plist
  

6. Customizing Check Intervals

By default, com.user.arrmonitor.plist executes immediately on login (RunAtLoad) and repeats every 3600 seconds (1 hour). To change how often it checks your services:

1. Open your installed plist file:
   nano ~/Library/LaunchAgents/com.user.arrmonitor.plist
   
2. Update the <integer> value beneath <key>StartInterval</key>:
  ⚬ 300 — Every 5 minutes
  ⚬ 900 — Every 15 minutes
  ⚬ 1800 — Every 30 minutes
  ⚬ 3600 — Every 1 hour (default)
3. Save (Ctrl + O, Enter, Ctrl + X) and reload the service:
   launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.user.arrmonitor.plist
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.arrmonitor.plist
   

7. Headless Mac Mini Uptime & Remote Stack Notes

For unattended operation on a headless Mac mini accessed remotely over Tailscale via Screens 5, Helmarr, and Ruddar:

1. Enable Automatic Login: Because ~/Library/LaunchAgents/ runs inside the user GUI session (gui/501), go to System Settings → Users & Groups → Automatically log in as and select your user account so services start automatically after a power event or reboot. (Requires FileVault to be disabled.)
2. Allow Background Execution: In System Settings → General → Login Items & Extensions → Allow in the Background, confirm arr_monitor.sh / bash is toggled ON.
3. Keep Tailscale Set to Auto-Launch: Ensure Tailscale is enabled under Open at Login and Network Extensions so your 100.x.y.z mesh IP stays reachable across reboots.
4. VPN Split-Tunneling Isolation: Keep only your download client (Transmission) and link-grabbing browser (Safari) routed through your privacy VPN (ExpressVPN / WireGuard), leaving *arr apps, Plex, Screens 5, and Tailscale on the native network interface.
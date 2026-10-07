#!/bin/bash
set -e

echo "🚀 Installing Salesforce ETL Watcher..."

# Define paths dynamically based on the colleague's Home folder
APP_DIR="$HOME/Library/Application Support/ETLWatcher"
BIN_PATH="$APP_DIR/sf_watcher"
PLIST_PATH="$HOME/Library/LaunchAgents/com.ram-service-excellence.etlwatcher.plist"
LOG_DIR="$HOME/Library/Logs/ETLWatcher"

# Create necessary directories
mkdir -p "$APP_DIR"
mkdir -p "$HOME/Library/LaunchAgents"
mkdir -p "$LOG_DIR"

# Download the compiled binary directly from GitHub
echo "⬇️  Downloading background service..."
curl -sSL -o "$BIN_PATH" "https://github.com/jtashiro-ga-tech/etl-sf-watcher/raw/refs/heads/main/sf_watcher"

# Make the binary executable
chmod +x "$BIN_PATH"

# Generate the LaunchAgent .plist file natively
echo "⚙️  Configuring launchd daemon..."
cat << EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ram-service-excellence.etlwatcher</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BIN_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/sf_watcher.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/sf_watcher_error.log</string>
</dict>
</plist>
EOF

# Restart the service (unloads it first just in case they are updating)
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo "✅ Installation complete! The watcher is now running silently in the background."

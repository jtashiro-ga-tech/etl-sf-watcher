Write-Host "🚀 Installing Salesforce ETL Watcher (Windows)..." -ForegroundColor Cyan

# Define Paths
$AppDir = "$env:APPDATA\ETLWatcher"
$BinPath = "$AppDir\sf_watcher.exe"
$EnvPath = "$AppDir\.env"
$LogFile = "$AppDir\sf_watcher.log"
$TaskName = "RAM_Service_Excellence_ETLWatcher"
$DefaultServerUrl = "https://etl.ram-service-excellence.com/api/upload"

# Create Directory
if (-not (Test-Path $AppDir)) {
    New-Item -ItemType Directory -Path $AppDir | Out-Null
}

# Handle SECRET_TOKEN
$IncomingToken = $env:SECRET_TOKEN
if ([string]::IsNullOrWhiteSpace($IncomingToken) -and (Test-Path $EnvPath)) {
    # Try extracting from existing .env
    $existing = Get-Content $EnvPath | Where-Object { $_ -match "^SECRET_TOKEN=" }
    if ($existing) {
        $IncomingToken = $existing.Split('=', 2)[1].Trim('"', "'")
    }
}

if ([string]::IsNullOrWhiteSpace($IncomingToken)) {
    Write-Host "❌ Error: SECRET_TOKEN is required for new installations." -ForegroundColor Red
    Write-Host "Run: `$env:SECRET_TOKEN='YOUR_TOKEN'; irm https://github.com/jtashiro-ga-tech/etl-sf-watcher/raw/refs/heads/main/install.ps1 | iex"
    exit 1
}

# Write .env file
Write-Host "🔐 Configuring environment variables..."
@"
SERVER_URL="$DefaultServerUrl"
SECRET_TOKEN="$IncomingToken"
"@ | Out-File -FilePath $EnvPath -Encoding UTF8

# Download the compiled binary
Write-Host "⬇️  Downloading background service..."
$DownloadUrl = "https://github.com/jtashiro-ga-tech/etl-sf-watcher/raw/refs/heads/main/sf_watcher.exe"
Invoke-WebRequest -Uri $DownloadUrl -OutFile $BinPath

# Configure Scheduled Task to run silently in the background at Logon
Write-Host "⚙️  Configuring background task..."
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

$Action = New-ScheduledTaskAction -Execute $BinPath -WorkingDirectory $AppDir
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden

Register-ScheduledTask -Action $Action -Trigger $Trigger -Settings $Settings -TaskName $TaskName -Description "Watches Downloads folder for Salesforce reports" -User $env:USERNAME | Out-Null

# Start the task immediately for the current session
Start-ScheduledTask -TaskName $TaskName

Write-Host "✅ Installation complete! The watcher is now running silently in the background." -ForegroundColor Green

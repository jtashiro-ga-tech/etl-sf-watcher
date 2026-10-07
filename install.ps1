Write-Host "🚀 Installing Salesforce ETL Watcher for Windows..."

# Define permanent installation directory (Local AppData)
$InstallDir = "$env:LOCALAPPDATA\ETLWatcher"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$DestExe = Join-Path$InstallDir "sf_watcher.exe"

# Download the executable directly from GitHub
Write-Host "⬇️  Downloading background service..."
$DownloadUrl = "https://github.com/jtashiro-ga-tech/etl-sf-watcher/raw/refs/heads/main/sf_watcher.exe"
Invoke-WebRequest -Uri $DownloadUrl -OutFile$DestExe

# Add to Windows Registry to run on startup
Write-Host "⚙️  Configuring Windows Startup..."
$RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Set-ItemProperty -Path $RegPath -Name "ETLWatcher" -Value "`"$DestExe`""

# Kill existing process if they are updating, then start the new one
Get-Process -Name "sf_watcher" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Process -FilePath $DestExe

Write-Host "✅ Installation complete! The watcher is now running silently in the background." -ForegroundColor Green
Start-Sleep -Seconds 5

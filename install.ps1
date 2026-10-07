Write-Host "🚀 Installing Salesforce ETL Watcher for Windows..."
$InstallDir = "$env:LOCALAPPDATA\ETLWatcher"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$DestExe = Join-Path$InstallDir "sf_watcher.exe"
Write-Host "⬇️  Downloading background service..."
$DownloadUrl = "https://github.com/jtashiro-ga-tech/etl-sf-watcher/raw/refs/heads/main/sf_watcher.exe"
Invoke-WebRequest -Uri $DownloadUrl -OutFile$DestExe
Write-Host "⚙️  Configuring Windows Startup..."
$RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Set-ItemProperty -Path $RegPath -Name "ETLWatcher" -Value "`"$DestExe`""
Get-Process -Name "sf_watcher" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Process -FilePath $DestExe
Write-Host "✅ Installation complete! The watcher is now running silently in the background." -ForegroundColor Green

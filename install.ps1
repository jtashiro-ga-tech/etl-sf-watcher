
Write-Host "🚀 Installing Salesforce ETL Watcher (Windows)..." -ForegroundColor Cyan

$ErrorActionPreference = "Stop"

# --------------------------------------------------
# 1. Define Paths and Configuration
# --------------------------------------------------

$AppDir = Join-Path $env:APPDATA "ETLWatcher"
$BinPath = Join-Path $AppDir "sf_watcher.exe"
$EnvPath = Join-Path $AppDir ".env"
$TaskName = "RAM_Service_Excellence_ETLWatcher"

$DefaultServerUrl = "https://etl.ram-service-excellence.com/api/upload"

# Get the current Windows user, including domain/computer name
$CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

try {

    # --------------------------------------------------
    # 2. Create Application Directory
    # --------------------------------------------------

    if (-not (Test-Path $AppDir)) {
        New-Item -ItemType Directory -Path $AppDir -Force | Out-Null
    }

    # --------------------------------------------------
    # 3. Handle SECRET_TOKEN
    # --------------------------------------------------

    Write-Host "🔐 Configuring environment variables..."

    $IncomingToken = $env:SECRET_TOKEN

    # Reuse existing token if no new token was provided
    if ([string]::IsNullOrWhiteSpace($IncomingToken) -and (Test-Path $EnvPath)) {

        $ExistingEnv = Get-Content -Path $EnvPath

        $TokenLine = $ExistingEnv | Where-Object {
            $_ -match '^SECRET_TOKEN='
        } | Select-Object -First 1

        if ($TokenLine) {
            $IncomingToken = ($TokenLine -replace '^SECRET_TOKEN=', '').Trim('"', "'")
        }
    }

    if ([string]::IsNullOrWhiteSpace($IncomingToken)) {

        Write-Host "❌ Error: SECRET_TOKEN is required." -ForegroundColor Red

        Write-Host "Run:"
        Write-Host "`$env:SECRET_TOKEN='YOUR_TOKEN'; irm https://github.com/jtashiro-ga-tech/etl-sf-watcher/raw/refs/heads/main/install.ps1 | iex"

        exit 1
    }

    # Write environment variables
    @"
SERVER_URL="$DefaultServerUrl"
SECRET_TOKEN="$IncomingToken"
"@ | Out-File -FilePath $EnvPath -Encoding UTF8

    # --------------------------------------------------
    # 4. Download Compiled Executable
    # --------------------------------------------------

    Write-Host "⬇️ Downloading background service..."

    $DownloadUrl = "https://github.com/jtashiro-ga-tech/etl-sf-watcher/raw/refs/heads/main/sf_watcher.exe"

    Invoke-WebRequest `
        -Uri $DownloadUrl `
        -OutFile $BinPath `
        -UseBasicParsing

    # Verify download
    if (-not (Test-Path $BinPath)) {
        throw "The executable was not downloaded."
    }

    if ((Get-Item $BinPath).Length -eq 0) {
        throw "The downloaded executable is empty."
    }

    Write-Host "✅ Executable downloaded successfully." -ForegroundColor Green

    # --------------------------------------------------
    # 5. Configure Scheduled Task
    # --------------------------------------------------

    Write-Host "⚙️ Configuring background task..."

    # Remove existing task if present
    $ExistingTask = Get-ScheduledTask `
        -TaskName $TaskName `
        -ErrorAction SilentlyContinue

    if ($ExistingTask) {
        Unregister-ScheduledTask `
            -TaskName $TaskName `
            -Confirm:$false `
            -ErrorAction Stop
    }

    # Define task action
    $Action = New-ScheduledTaskAction `
        -Execute $BinPath `
        -WorkingDirectory $AppDir

    # Run whenever the current user logs in
    $Trigger = New-ScheduledTaskTrigger -AtLogOn -User $CurrentUser

    # Task settings
    $Settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -Hidden

    # Explicitly run under the current user's interactive session
    $Principal = New-ScheduledTaskPrincipal `
        -UserId $CurrentUser `
        -LogonType Interactive `
        -RunLevel Limited

    # Create scheduled task
    $Task = New-ScheduledTask `
        -Action $Action `
        -Trigger $Trigger `
        -Settings $Settings `
        -Principal $Principal `
        -Description "Watches Downloads folder for Salesforce reports"

    Register-ScheduledTask `
        -TaskName $TaskName `
        -InputObject $Task `
        -Force `
        -ErrorAction Stop | Out-Null

    Write-Host "✅ Background task registered successfully." -ForegroundColor Green

    # --------------------------------------------------
    # 6. Start Immediately
    # --------------------------------------------------

    Write-Host "▶️ Starting background service..."

    Start-ScheduledTask `
        -TaskName $TaskName `
        -ErrorAction Stop

    # Verify that the task exists
    $RegisteredTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "✅ Installation completed successfully!" -ForegroundColor Green
    Write-Host "Salesforce ETL Watcher is configured." -ForegroundColor Green
    Write-Host "Windows User: $CurrentUser"
    Write-Host "Installation: $AppDir"
    Write-Host "============================================" -ForegroundColor Green

}
catch {

    Write-Host ""
    Write-Host "❌ INSTALLATION FAILED" -ForegroundColor Red
    Write-Host "--------------------------------------------"
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "--------------------------------------------"

    Write-Host ""
    Write-Host "Possible causes:" -ForegroundColor Yellow
    Write-Host "1. Windows permissions or Scheduled Task restrictions."
    Write-Host "2. Corporate Group Policy restrictions."
    Write-Host "3. Network restrictions preventing executable downloads."
    Write-Host ""
    Write-Host "Please contact IT or the application developer."

    exit 1
}

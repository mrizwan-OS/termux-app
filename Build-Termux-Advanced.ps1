# ============================================
# TERMUX ADVANCED BUILDER
# ============================================

$ErrorActionPreference = "Stop"
$ProjectDir = "C:\Users\rizwan\termux-app"
$LogDir = "$ProjectDir\build_logs"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Create log directory
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

# Start logging
$LogFile = "$LogDir\build_$Timestamp.log"
Start-Transcript -Path $LogFile -Append

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "TERMUX BUILD - $Timestamp" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

cd $ProjectDir

# Function to run command with error handling
function Invoke-BuildCommand {
    param($Command, $Description)
    
    Write-Host "`n▶ $Description" -ForegroundColor Yellow
    Write-Host "Command: $Command" -ForegroundColor Gray
    
    Invoke-Expression $Command
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Command failed with exit code: $LASTEXITCODE" -ForegroundColor Red
        exit $LASTEXITCODE
    }
    
    Write-Host "✓ $Description completed" -ForegroundColor Green
}

# Clean
Invoke-BuildCommand -Command ".\gradlew.bat clean" -Description "Cleaning project"

# Build native if needed
if (Test-Path "native\build-all.bat") {
    Push-Location native
    Invoke-BuildCommand -Command ".\build-all.bat" -Description "Building native libraries"
    Pop-Location
}

# Build debug APK
Invoke-BuildCommand -Command ".\gradlew.bat assembleDebug" -Description "Building Debug APK"

# Build release APK
Invoke-BuildCommand -Command ".\gradlew.bat assembleRelease" -Description "Building Release APK"

# Show results
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "BUILD SUCCESSFUL!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

$apks = @(
    "app\build\outputs\apk\debug\app-debug.apk",
    "app\build\outputs\apk\release\app-release.apk"
)

foreach ($apk in $apks) {
    if (Test-Path $apk) {
        $file = Get-Item $apk
        Write-Host "✓ $($file.Name) - $([math]::Round($file.Length/1MB,2)) MB" -ForegroundColor Green
        Write-Host "  Location: $($file.FullName)" -ForegroundColor Gray
    }
}

Write-Host "`nLog file: $LogFile" -ForegroundColor Gray

Stop-Transcript
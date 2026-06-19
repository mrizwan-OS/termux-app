# ============================================
# TERMUX APK BUILDER - PowerShell Version
# ============================================

param(
    [switch]$Debug = $true,
    [switch]$Release = $true,
    [switch]$Clean = $true,
    [switch]$Install = $false,
    [switch]$SkipNative = $false
)

# Configuration
$ProjectDir = "C:\Users\rizwan\termux-app"
$GradleWrapper = "gradlew.bat"
$BuildLog = "build.log"

# Colors for output
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Error { Write-Host $args -ForegroundColor Red }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }
function Write-Step { Write-Host "`n[STEP] $args" -ForegroundColor Magenta }
function Write-Section { Write-Host "`n" + "="*60 -ForegroundColor White; Write-Host $args -ForegroundColor White; Write-Host "="*60 -ForegroundColor White }

# ============================================
# START BUILD PROCESS
# ============================================

Clear-Host
Write-Section "TERMUX APK BUILDER - CLEAN BUILD"
Write-Info "Project Directory: $ProjectDir"
Write-Info "Build Time: $(Get-Date)"
Write-Info "PowerShell Version: $($PSVersionTable.PSVersion)"

# Change to project directory
Set-Location $ProjectDir

# ============================================
# STEP 1: Check Prerequisites
# ============================================

Write-Step "Checking Prerequisites..."

# Check Java
try {
    $javaVersion = java -version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Java not found! Please install JDK 17+"
        exit 1
    }
    Write-Success "Java found"
} catch {
    Write-Error "Java not found! Please install JDK 17+"
    exit 1
}

# Check Gradle Wrapper
if (-not (Test-Path $GradleWrapper)) {
    Write-Error "gradlew.bat not found in $ProjectDir"
    exit 1
}
Write-Success "Gradle wrapper found"

# Check Android SDK
$AndroidSdk = $env:ANDROID_HOME
if (-not $AndroidSdk) {
    $AndroidSdk = $env:ANDROID_SDK_ROOT
}
if (-not $AndroidSdk) {
    $AndroidSdk = "C:\Users\$env:USERNAME\AppData\Local\Android\Sdk"
}
if (-not (Test-Path $AndroidSdk)) {
    Write-Warning "Android SDK not found at $AndroidSdk"
    Write-Warning "Make sure ANDROID_HOME is set correctly"
}

Write-Success "Android SDK: $AndroidSdk"

# ============================================
# STEP 2: Clean Previous Builds
# ============================================

if ($Clean) {
    Write-Step "Cleaning previous builds..."
    
    Write-Info "Running gradlew clean..."
    & .\gradlew.bat clean --no-daemon 2>&1 | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Clean failed! Check gradlew.bat"
        exit 1
    }
    
    # Remove build directories
    $buildDirs = @(
        "app\build",
        "build",
        ".gradle"
    )
    
    foreach ($dir in $buildDirs) {
        if (Test-Path $dir) {
            Write-Info "Removing $dir..."
            Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Write-Success "Clean completed"
}

# ============================================
# STEP 3: Build Native Libraries
# ============================================

if (-not $SkipNative) {
    Write-Step "Building Native Libraries..."
    
    if (Test-Path "native\build-all.bat") {
        Push-Location native
        Write-Info "Running build-all.bat..."
        & .\build-all.bat 2>&1 | Out-Null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Native build failed or partial. Trying individual builds..."
            
            # Try individual architecture builds
            $archs = @("arm64", "armv7", "x86_64")
            foreach ($arch in $archs) {
                $buildScript = "build-$arch.bat"
                if (Test-Path $buildScript) {
                    Write-Info "Building $arch..."
                    & .\$buildScript 2>&1 | Out-Null
                }
            }
        }
        Pop-Location
        Write-Success "Native libraries build completed"
    } else {
        Write-Warning "native\build-all.bat not found. Skipping native build."
        Write-Info "If you see errors, run: scripts\build-native.bat"
    }
} else {
    Write-Warning "Skipping native library build (--SkipNative used)"
}

# ============================================
# STEP 4: Build Debug APK
# ============================================

if ($Debug) {
    Write-Step "Building DEBUG APK..."
    
    Write-Info "Running gradlew assembleDebug..."
    $debugBuild = & .\gradlew.bat assembleDebug --no-daemon 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Debug APK built successfully!"
        
        $debugApk = "app\build\outputs\apk\debug\app-debug.apk"
        if (Test-Path $debugApk) {
            $fileInfo = Get-Item $debugApk
            Write-Info "Location: $debugApk"
            Write-Info "Size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB"
            Write-Info "Modified: $($fileInfo.LastWriteTime)"
        }
    } else {
        Write-Error "Debug build failed!"
        Write-Error "Error output:"
        $debugBuild | Select-Object -Last 20
    }
}

# ============================================
# STEP 5: Build Release APK
# ============================================

if ($Release) {
    Write-Step "Building RELEASE APK..."
    
    Write-Info "Running gradlew assembleRelease..."
    $releaseBuild = & .\gradlew.bat assembleRelease --no-daemon 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Release APK built successfully!"
        
        $releaseApk = "app\build\outputs\apk\release\app-release.apk"
        if (Test-Path $releaseApk) {
            $fileInfo = Get-Item $releaseApk
            Write-Info "Location: $releaseApk"
            Write-Info "Size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB"
            Write-Info "Modified: $($fileInfo.LastWriteTime)"
        }
    } else {
        Write-Error "Release build failed!"
        Write-Error "Error output:"
        $releaseBuild | Select-Object -Last 20
    }
}

# ============================================
# STEP 6: Install on Device (Optional)
# ============================================

if ($Install) {
    Write-Step "Installing APK on device..."
    
    # Check ADB
    $adbPath = "$AndroidSdk\platform-tools\adb.exe"
    if (-not (Test-Path $adbPath)) {
        Write-Error "ADB not found at $adbPath"
        Write-Warning "Skipping installation"
    } else {
        # Check if device is connected
        $devices = & $adbPath devices
        if ($devices -match "device$") {
            Write-Success "Device found"
            
            if ($Debug -and (Test-Path "app\build\outputs\apk\debug\app-debug.apk")) {
                Write-Info "Installing Debug APK..."
                & $adbPath install -r "app\build\outputs\apk\debug\app-debug.apk"
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Debug APK installed successfully!"
                }
            }
            
            if ($Release -and (Test-Path "app\build\outputs\apk\release\app-release.apk")) {
                Write-Info "Installing Release APK..."
                & $adbPath install -r "app\build\outputs\apk\release\app-release.apk"
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Release APK installed successfully!"
                }
            }
        } else {
            Write-Error "No Android device connected. Please connect a device or start an emulator."
        }
    }
}

# ============================================
# STEP 7: Show Summary
# ============================================

Write-Section "BUILD SUMMARY"
Write-Success "Build completed at: $(Get-Date)"

# Show APK information
Write-Host "`nGenerated APKs:" -ForegroundColor Cyan

$apks = @(
    @{Path = "app\build\outputs\apk\debug\app-debug.apk"; Type = "Debug"},
    @{Path = "app\build\outputs\apk\release\app-release.apk"; Type = "Release"}
)

foreach ($apk in $apks) {
    if (Test-Path $apk.Path) {
        $file = Get-Item $apk.Path
        Write-Host "  [$($apk.Type)] $($file.Name)" -ForegroundColor Green
        Write-Host "    Size: $([math]::Round($file.Length / 1MB, 2)) MB" -ForegroundColor Gray
        Write-Host "    Path: $($apk.Path)" -ForegroundColor Gray
        Write-Host "    Modified: $($file.LastWriteTime)" -ForegroundColor Gray
    }
}

Write-Host "`nTo install with ADB:" -ForegroundColor Cyan
if (Test-Path "app\build\outputs\apk\debug\app-debug.apk") {
    Write-Host "  adb install -r app\build\outputs\apk\debug\app-debug.apk" -ForegroundColor Gray
}

Write-Host "`nBuild logs saved to: $BuildLog" -ForegroundColor Gray
Write-Host "`n" + "="*60 -ForegroundColor White

# ============================================
# END
# ============================================
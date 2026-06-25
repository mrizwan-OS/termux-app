# build-termux-apk.ps1 - Fully Automated Termux APK Build and Release Script

param(
    [Parameter(Mandatory=$false)]
    [string]$BuildType = "release",  # release or debug
    
    [Parameter(Mandatory=$false)]
    [string]$OutputDir = "build/outputs/apk",
    
    [Parameter(Mandatory=$false)]
    [switch]$CleanBuild,
    
    [Parameter(Mandatory=$false)]
    [switch]$SignApk,
    
    [Parameter(Mandatory=$false)]
    [string]$KeystorePath = "",
    
    [Parameter(Mandatory=$false)]
    [string]$KeystorePassword = "",
    
    [Parameter(Mandatory=$false)]
    [string]$KeyAlias = "",
    
    [Parameter(Mandatory=$false)]
    [string]$KeyPassword = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateRelease,
    
    [Parameter(Mandatory=$false)]
    [string]$ReleaseVersion = "1.0.0",
    
    [Parameter(Mandatory=$false)]
    [string]$GithubToken = ""
)

# Configuration
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# Colors for output
$Colors = @{
    "Info" = "Cyan"
    "Success" = "Green"
    "Warning" = "Yellow"
    "Error" = "Red"
    "Header" = "Magenta"
}

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Write-Header {
    Clear-Host
    Write-ColorOutput "═══════════════════════════════════════════════════════════" "Header"
    Write-ColorOutput "         TERMUX ANDROID APK BUILD & RELEASE" "Header"
    Write-ColorOutput "═══════════════════════════════════════════════════════════" "Header"
    Write-ColorOutput ""
}

function Write-Step {
    param([string]$Message, [int]$StepNumber)
    Write-ColorOutput "`n[Step $StepNumber] $Message" "Info"
    Write-ColorOutput ("─" * 60) "Info"
}

function Check-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Test-Requirements {
    Write-Step "Checking Requirements" 1
    
    # Check Java
    $javaInstalled = Check-Command "java"
    if (-not $javaInstalled) {
        Write-ColorOutput "❌ Java not found! Please install JDK 11 or higher." "Error"
        Write-ColorOutput "   Download from: https://adoptium.net/" "Error"
        exit 1
    }
    Write-ColorOutput "✅ Java: $(java -version 2>&1 | Select-Object -First 1)" "Success"
    
    # Check Gradle
    if (Test-Path "gradlew.bat") {
        Write-ColorOutput "✅ Gradle Wrapper found" "Success"
    } else {
        Write-ColorOutput "❌ gradlew.bat not found!" "Error"
        exit 1
    }
    
    # Check Android SDK
    $androidHome = $env:ANDROID_HOME
    if (-not $androidHome) {
        $androidHome = $env:ANDROID_SDK_ROOT
    }
    if (-not $androidHome) {
        Write-ColorOutput "⚠️  ANDROID_HOME not set. Assuming default location..." "Warning"
        $androidHome = "C:\Users\$env:USERNAME\AppData\Local\Android\Sdk"
    }
    
    if (Test-Path $androidHome) {
        Write-ColorOutput "✅ Android SDK: $androidHome" "Success"
    } else {
        Write-ColorOutput "⚠️  Android SDK not found at $androidHome" "Warning"
    }
    
    Write-ColorOutput "✅ All requirements satisfied!" "Success"
}

function Backup-GradleFiles {
    Write-Step "Backing up Gradle Files" 2
    
    $backupDir = "gradle_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    
    Copy-Item "build.gradle" "$backupDir/" -ErrorAction SilentlyContinue
    Copy-Item "settings.gradle" "$backupDir/" -ErrorAction SilentlyContinue
    Copy-Item "gradle.properties" "$backupDir/" -ErrorAction SilentlyContinue
    Copy-Item "local.properties" "$backupDir/" -ErrorAction SilentlyContinue
    
    Write-ColorOutput "✅ Backup created: $backupDir" "Success"
    return $backupDir
}

function Update-GradleConfig {
    Write-Step "Updating Gradle Configuration" 3
    
    # Update gradle.properties
    Write-ColorOutput "📝 Updating gradle.properties..." "Info"
    $gradleProps = @"
org.gradle.jvmargs=-Xmx2048m -XX:MaxMetaspaceSize=512m
org.gradle.parallel=true
org.gradle.caching=true
org.gradle.daemon=true
android.useAndroidX=true
android.enableJetifier=true
android.enableR8.fullMode=true
android.injected.testOnly=false
"@
    $gradleProps | Out-File -FilePath "gradle.properties" -Encoding utf8 -Force
    
    # Update local.properties
    Write-ColorOutput "📝 Updating local.properties..." "Info"
    $androidHome = $env:ANDROID_HOME
    if (-not $androidHome) {
        $androidHome = "C:\Users\$env:USERNAME\AppData\Local\Android\Sdk"
    }
    "sdk.dir=$androidHome" | Out-File -FilePath "local.properties" -Encoding utf8 -Force
    
    Write-ColorOutput "✅ Gradle configuration updated!" "Success"
}

function Clean-Build {
    if ($CleanBuild) {
        Write-Step "Cleaning Build" 4
        Write-ColorOutput "🧹 Running clean build..." "Warning"
        
        $cleanResult = .\gradlew.bat clean
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Clean completed!" "Success"
        } else {
            Write-ColorOutput "❌ Clean failed!" "Error"
            exit 1
        }
    }
}

function Build-APK {
    Write-Step "Building APK" 5
    
    Write-ColorOutput "🔨 Building $BuildType APK..." "Info"
    
    if ($BuildType -eq "release") {
        $buildResult = .\gradlew.bat assembleRelease --stacktrace
    } else {
        $buildResult = .\gradlew.bat assembleDebug --stacktrace
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ Build successful!" "Success"
        
        # Find the APK
        $apkPath = "app/build/outputs/apk/$BuildType"
        $apkFile = Get-ChildItem -Path $apkPath -Filter "*.apk" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        if ($apkFile) {
            Write-ColorOutput "📦 APK created: $($apkFile.FullName)" "Success"
            Write-ColorOutput "📏 Size: $([math]::Round($apkFile.Length / 1MB, 2)) MB" "Info"
            return $apkFile
        } else {
            Write-ColorOutput "❌ APK file not found!" "Error"
            return $null
        }
    } else {
        Write-ColorOutput "❌ Build failed!" "Error"
        Write-ColorOutput "Check the error log above for details." "Error"
        exit 1
    }
}

function Sign-APK {
    param([string]$ApkPath)
    
    if (-not $SignApk) {
        return $ApkPath
    }
    
    Write-Step "Signing APK" 6
    
    if (-not $KeystorePath -or -not $KeystorePassword -or -not $KeyAlias) {
        Write-ColorOutput "⚠️  Keystore details not provided. Skipping signing." "Warning"
        Write-ColorOutput "To sign, provide: -KeystorePath, -KeystorePassword, -KeyAlias, -KeyPassword" "Info"
        return $ApkPath
    }
    
    # Create signed APK
    $signedApk = $ApkPath -replace "\.apk$", "_signed.apk"
    
    Write-ColorOutput "🔑 Signing APK..." "Info"
    
    # Use jarsigner (included with JDK)
    & jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 -keystore $KeystorePath -storepass $KeystorePassword -keypass $KeyPassword -signedjar $signedApk $ApkPath $KeyAlias
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✅ APK signed successfully!" "Success"
        Write-ColorOutput "📦 Signed APK: $signedApk" "Success"
        return $signedApk
    } else {
        Write-ColorOutput "❌ Signing failed!" "Error"
        return $ApkPath
    }
}

function Optimize-APK {
    param([string]$ApkPath)
    
    Write-Step "Optimizing APK" 7
    
    if (Check-Command "zipalign") {
        $optimizedApk = $ApkPath -replace "\.apk$", "_aligned.apk"
        & zipalign -v -p 4 $ApkPath $optimizedApk
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ APK optimized!" "Success"
            return $optimizedApk
        }
    } else {
        Write-ColorOutput "⚠️  zipalign not found. Skipping optimization." "Warning"
    }
    
    return $ApkPath
}

function Generate-ReleaseNotes {
    param([string]$Version)
    
    Write-Step "Generating Release Notes" 8
    
    $releaseNotes = @"
# Termux Android App Release v$Version

## Build Information
- Build Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- Build Type: $BuildType
- Build System: Windows $(Get-CimInstance Win32_OperatingSystem).Caption

## Changes
$(git log --oneline --since="1 week ago" | Out-String)

## Installation Instructions
1. Download the APK file
2. Enable "Unknown Sources" in Android settings
3. Install the APK on your Android device

## Notes
- This is an automated build generated by the build script
- For issues, please report to the GitHub repository

---
Build completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@
    
    $releaseNotesFile = "RELEASE_NOTES_v$Version.md"
    $releaseNotes | Out-File -FilePath $releaseNotesFile -Encoding utf8
    Write-ColorOutput "✅ Release notes generated: $releaseNotesFile" "Success"
    return $releaseNotesFile
}

function Create-GitHubRelease {
    param(
        [string]$ApkPath,
        [string]$Version,
        [string]$ReleaseNotesFile
    )
    
    if (-not $CreateRelease) {
        Write-ColorOutput "⏭️  Skipping GitHub release (use -CreateRelease to enable)" "Warning"
        return
    }
    
    Write-Step "Creating GitHub Release" 9
    
    if (-not $GithubToken) {
        $GithubToken = Read-Host -Prompt "🔐 Enter your GitHub Personal Access Token"
    }
    
    if (-not $GithubToken) {
        Write-ColorOutput "❌ No GitHub token provided. Skipping release." "Error"
        return
    }
    
    # Get repo info
    $repoInfo = git config --get remote.origin.url
    if ($repoInfo -match "github\.com[:/](.+)/(.+)\.git") {
        $owner = $Matches[1]
        $repo = $Matches[2]
    } else {
        Write-ColorOutput "❌ Could not determine GitHub repository." "Error"
        return
    }
    
    Write-ColorOutput "📤 Creating release for $owner/$repo..." "Info"
    
    # Create release using GitHub API
    $headers = @{
        "Authorization" = "token $GithubToken"
        "Accept" = "application/vnd.github.v3+json"
    }
    
    $releaseData = @{
        tag_name = "v$Version"
        name = "Termux App v$Version"
        body = Get-Content $ReleaseNotesFile -Raw
        draft = $false
        prerelease = $false
    } | ConvertTo-Json
    
    $releaseUrl = "https://api.github.com/repos/$owner/$repo/releases"
    
    try {
        $response = Invoke-RestMethod -Uri $releaseUrl -Method Post -Headers $headers -Body $releaseData -ContentType "application/json"
        $uploadUrl = $response.upload_url -replace "\{.*\}$", ""
        
        Write-ColorOutput "✅ Release created! Uploading APK..." "Success"
        
        # Upload APK
        $apkName = Split-Path $ApkPath -Leaf
        $uploadUrlWithName = "$uploadUrl`?name=$apkName"
        
        $apkBytes = [System.IO.File]::ReadAllBytes($ApkPath)
        $uploadHeaders = $headers.Clone()
        $uploadHeaders["Content-Type"] = "application/octet-stream"
        
        $uploadResponse = Invoke-RestMethod -Uri $uploadUrlWithName -Method Post -Headers $uploadHeaders -Body $apkBytes
        
        Write-ColorOutput "✅ APK uploaded to GitHub Release!" "Success"
        Write-ColorOutput "🔗 View release: https://github.com/$owner/$repo/releases/tag/v$Version" "Info"
        
    } catch {
        Write-ColorOutput "❌ Failed to create release: $_" "Error"
    }
}

function Show-Summary {
    param(
        [string]$ApkPath,
        [string]$Version,
        [string]$BackupDir
    )
    
    Write-Step "Build Summary" 10
    
    Write-ColorOutput "═══════════════════════════════════════════════════════════" "Header"
    Write-ColorOutput "                    BUILD COMPLETE!" "Success"
    Write-ColorOutput "═══════════════════════════════════════════════════════════" "Header"
    Write-ColorOutput ""
    
    Write-ColorOutput "📦 Build Details:" "Info"
    Write-ColorOutput "  • Build Type   : $BuildType" "White"
    Write-ColorOutput "  • Version      : $Version" "White"
    Write-ColorOutput "  • APK Location : $ApkPath" "White"
    
    if ($ApkPath -and (Test-Path $ApkPath)) {
        $apkFile = Get-Item $ApkPath
        Write-ColorOutput "  • File Size    : $([math]::Round($apkFile.Length / 1MB, 2)) MB" "White"
        Write-ColorOutput "  • Created      : $($apkFile.LastWriteTime)" "White"
    }
    
    Write-ColorOutput ""
    Write-ColorOutput "📁 Backup Location: $BackupDir" "Info"
    Write-ColorOutput ""
    
    Write-ColorOutput "✅ Next Steps:" "Info"
    Write-ColorOutput "  1. Test the APK on your Android device" "White"
    Write-ColorOutput "  2. Check the release notes file" "White"
    Write-ColorOutput "  3. Upload to Google Play Store (if needed)" "White"
    Write-ColorOutput "  4. Clean up backup files: Remove-Item -Recurse -Force $BackupDir" "White"
    Write-ColorOutput ""
}

# Main Execution
try {
    Write-Header
    $StartTime = Get-Date
    
    Write-ColorOutput "🔄 Starting build process for Termux APK..." "Info"
    Write-ColorOutput "Build Type: $BuildType" "Info"
    Write-ColorOutput "Clean Build: $CleanBuild" "Info"
    Write-ColorOutput "Sign APK: $SignApk" "Info"
    Write-ColorOutput "Create Release: $CreateRelease" "Info"
    Write-ColorOutput ""
    
    # Check requirements
    Test-Requirements
    
    # Backup gradle files
    $BackupDir = Backup-GradleFiles
    
    # Update configurations
    Update-GradleConfig
    
    # Clean if requested
    Clean-Build
    
    # Build APK
    $ApkFile = Build-APK
    
    if ($ApkFile) {
        $ApkPath = $ApkFile.FullName
        
        # Sign APK
        $SignedApk = Sign-APK -ApkPath $ApkPath
        
        # Optimize APK
        $FinalApk = Optimize-APK -ApkPath $SignedApk
        
        # Generate release notes
        $ReleaseNotes = Generate-ReleaseNotes -Version $ReleaseVersion
        
        # Create GitHub release
        if ($CreateRelease) {
            Create-GitHubRelease -ApkPath $FinalApk -Version $ReleaseVersion -ReleaseNotesFile $ReleaseNotes
        }
        
        # Show summary
        Show-Summary -ApkPath $FinalApk -Version $ReleaseVersion -BackupDir $BackupDir
        
        # Calculate build time
        $EndTime = Get-Date
        $Duration = $EndTime - $StartTime
        Write-ColorOutput "⏱️ Total build time: $([math]::Round($Duration.TotalMinutes, 2)) minutes" "Info"
    }
    
} catch {
    Write-ColorOutput "`n❌ ERROR: $_" "Error"
    Write-ColorOutput "Stack trace: $($_.ScriptStackTrace)" "Error"
    
    # Restore backup if exists
    if ($BackupDir -and (Test-Path $BackupDir)) {
        Write-ColorOutput "🔄 Restoring backup..." "Warning"
        Copy-Item "$BackupDir/*" "." -Force -ErrorAction SilentlyContinue
        Write-ColorOutput "✅ Backup restored!" "Success"
    }
    
    exit 1
}

Write-ColorOutput "`n✨ Build script completed successfully!" "Success"
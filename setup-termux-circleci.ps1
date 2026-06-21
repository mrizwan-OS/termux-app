# ============================================
# TERMUX-APP CircleCI Automation Setup
# Author: Rizwan
# Purpose: Automate CircleCI configuration for termux-app
# ============================================

# Set strict error handling
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ============================================
# CONFIGURATION
# ============================================
$RepoRoot = "C:\Users\rizwan\termux-app"
$CircleCIDir = Join-Path $RepoRoot ".circleci"
$ConfigFile = Join-Path $CircleCIDir "config.yml"
$GitIgnoreFile = Join-Path $RepoRoot ".gitignore"

# Colors for console output
$Green = "Green"
$Yellow = "Yellow"
$Red = "Red"
$Cyan = "Cyan"

function Write-Step {
    param([string]$Message)
    Write-Host "`n[STEP] $Message" -ForegroundColor $Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor $Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Yellow
}

# ============================================
# STEP 1: Create .circleci directory
# ============================================
Write-Step "Creating .circleci directory..."

if (-not (Test-Path $CircleCIDir)) {
    New-Item -Path $CircleCIDir -ItemType Directory -Force | Out-Null
    Write-Success "Created $CircleCIDir"
} else {
    Write-Info "$CircleCIDir already exists"
}

# ============================================
# STEP 2: Generate config.yml
# ============================================
Write-Step "Generating config.yml..."

$ConfigContent = @'
version: 2.1

# ============================================
# WORKFLOW: Daily build and test
# Runs every morning at 06:00 UTC
# ============================================
workflows:
  # Workflow for daily automated builds
  daily_build:
    triggers:
      - schedule:
          # Every day at 06:00 UTC
          cron: "0 6 * * *"
          filters:
            branches:
              only:
                - main
    jobs:
      - build-and-test:
          name: daily-build
          context: termux-build

  # Workflow for mandatory releases
  # Triggered when a new release is required
  release_workflow:
    jobs:
      - build-and-test:
          name: release-build
          context: termux-build
          filters:
            tags:
              # Only run when a tag matching v* is pushed
              only: /^v.*/
      - create-release:
          name: create-github-release
          context: termux-build
          requires:
            - release-build
          filters:
            tags:
              only: /^v.*/

# ============================================
# JOBS
# ============================================
jobs:
  # Main build job for Termux Android app
  build-and-test:
    machine:
      image: ubuntu-2204:current
    resource_class: arm.large  # ARM64 required for Termux builds 
    environment:
      ARCH: aarch64
      TERMUX_APK_BUILD: "true"
    steps:
      - checkout

      # Setup Android build environment
      - run:
          name: Setup Android SDK and NDK
          command: |
            sudo apt-get update
            sudo apt-get install -y openjdk-17-jdk
            echo "ANDROID_HOME=/opt/android-sdk" >> $BASH_ENV
            echo "ANDROID_NDK=/opt/android-sdk/ndk/26.3.11579264" >> $BASH_ENV

      # Grant execute permissions
      - run:
          name: Grant execute permission for gradlew
          command: chmod +x gradlew

      # Build debug APK
      - run:
          name: Build Debug APK
          command: |
            ./gradlew assembleDebug

      # Run tests
      - run:
          name: Run tests
          command: |
            ./gradlew test

      # Store APK artifacts
      - store_artifacts:
          path: app/build/outputs/apk/debug/
          destination: apks/debug

      # Store test results
      - store_test_results:
          path: app/build/test-results/

      # Persist artifacts for release job
      - persist_to_workspace:
          root: .
          paths:
            - app/build/outputs/apk/debug/
            - app/build/outputs/apk/release/

  # Release job - creates GitHub Release with APKs
  create-release:
    machine:
      image: ubuntu-2204:current
    steps:
      - attach_workspace:
          at: .

      # Install GitHub CLI
      - run:
          name: Install GitHub CLI
          command: |
            sudo apt-get update
            sudo apt-get install -y gh

      # Create GitHub Release
      - run:
          name: Create GitHub Release
          command: |
            TAG=${CIRCLE_TAG:-$(git describe --tags --abbrev=0)}
            RELEASE_NAME="Termux $TAG"
            
            gh release create "$TAG" \
              app/build/outputs/apk/debug/*.apk \
              app/build/outputs/apk/release/*.apk \
              --title "$RELEASE_NAME" \
              --notes "Automated release from CircleCI" \
              --repo "$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME"
        environment:
          GITHUB_TOKEN: GITHUB_TOKEN  # Set in CircleCI context

      # Store release artifacts
      - store_artifacts:
          path: app/build/outputs/apk/
          destination: apks
'@

# Write config file
$ConfigContent | Set-Content -Path $ConfigFile -Encoding utf8
Write-Success "Created $ConfigFile"

# ============================================
# STEP 3: Update .gitignore
# ============================================
Write-Step "Updating .gitignore..."

$GitIgnoreEntries = @(
    "# CircleCI local builds",
    ".circleci/local-build/",
    ".circleci/workspace/"
)

if (Test-Path $GitIgnoreFile) {
    $CurrentContent = Get-Content $GitIgnoreFile -Raw
    $NeedsUpdate = $false
    
    foreach ($Entry in $GitIgnoreEntries) {
        if ($CurrentContent -notmatch [regex]::Escape($Entry)) {
            $NeedsUpdate = $true
            break
        }
    }
    
    if ($NeedsUpdate) {
        Add-Content -Path $GitIgnoreFile -Value "`n$($GitIgnoreEntries -join "`n")"
        Write-Success "Updated .gitignore"
    } else {
        Write-Info ".gitignore already contains CircleCI entries"
    }
} else {
    $GitIgnoreEntries | Set-Content -Path $GitIgnoreFile -Encoding utf8
    Write-Success "Created .gitignore"
}

# ============================================
# STEP 4: Create helper scripts
# ============================================
Write-Step "Creating helper scripts..."

# Script: trigger-daily-build.ps1
$DailyBuildScript = @'
# ============================================
# Trigger Daily Build manually
# ============================================

Write-Host "Triggering daily build for termux-app..." -ForegroundColor Cyan

# Option 1: Using CircleCI API (requires API token)
# $CIRCLECI_TOKEN = "your-circleci-token"
# Invoke-RestMethod -Method POST -Uri "https://circleci.com/api/v2/project/gh/mrizwan-OS/termux-app/pipeline" -Headers @{ "Circle-Token" = $CIRCLECI_TOKEN } -Body '{"branch":"main"}'

# Option 2: Push an empty commit to trigger the daily build
git commit --allow-empty -m "Trigger daily build [skip tests]"
git push origin main

Write-Host "Daily build triggered successfully!" -ForegroundColor Green
'@
$DailyBuildScript | Set-Content -Path (Join-Path $RepoRoot "trigger-daily-build.ps1") -Encoding utf8
Write-Success "Created trigger-daily-build.ps1"

# Script: create-release.ps1
$ReleaseScript = @'
# ============================================
# Create a new release for termux-app
# ============================================

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    [string]$Message = "Automated release from CircleCI"
)

# Validate version format
if ($Version -notmatch '^v\d+\.\d+\.\d+$') {
    Write-Error "Version must be in format: v1.0.0"
    exit 1
}

Write-Host "Creating release $Version for termux-app..." -ForegroundColor Cyan

# Check if tag already exists
$ExistingTag = git tag -l $Version
if ($ExistingTag) {
    Write-Error "Tag $Version already exists!"
    exit 1
}

# Create and push tag
git tag -a $Version -m $Message
git push origin $Version

Write-Host "Release $Version created successfully! CircleCI will now build and release." -ForegroundColor Green
Write-Host "Monitor progress at: https://app.circleci.com/pipelines/github/mrizwan-OS/termux-app" -ForegroundColor Yellow
'@
$ReleaseScript | Set-Content -Path (Join-Path $RepoRoot "create-release.ps1") -Encoding utf8
Write-Success "Created create-release.ps1"

# Script: validate-config.ps1
$ValidateScript = @'
# ============================================
# Validate CircleCI configuration
# ============================================

Write-Host "Validating CircleCI configuration..." -ForegroundColor Cyan

# Check if CircleCI CLI is installed
$CircleCIExe = Get-Command "circleci" -ErrorAction SilentlyContinue
if (-not $CircleCIExe) {
    Write-Error "CircleCI CLI not found. Please install: https://circleci.com/docs/local-cli/"
    exit 1
}

# Validate config
circleci config validate .circleci/config.yml

if ($LASTEXITCODE -eq 0) {
    Write-Host "Configuration is valid!" -ForegroundColor Green
} else {
    Write-Error "Configuration validation failed!"
    exit 1
}
'@
$ValidateScript | Set-Content -Path (Join-Path $RepoRoot "validate-config.ps1") -Encoding utf8
Write-Success "Created validate-config.ps1"

# ============================================
# STEP 5: Commit and push changes
# ============================================
Write-Step "Committing and pushing changes..."

Set-Location $RepoRoot

# Stage changes
git add .circleci/config.yml
git add .gitignore
git add *.ps1

# Check if there are changes to commit
$Status = git status --porcelain
if ($Status) {
    git commit -m "ci: Add CircleCI automation for daily builds and releases"
    Write-Success "Committed changes locally"
    
    # Push to remote
    Write-Info "Pushing to remote repository..."
    git push origin main
    Write-Success "Pushed changes to GitHub"
} else {
    Write-Info "No changes to commit"
}

# ============================================
# STEP 6: Display summary
# ============================================
Write-Host "`n" + ("=" * 60) -ForegroundColor $Cyan
Write-Host "  TERMUX-APP CIRCLE CI SETUP COMPLETED" -ForegroundColor $Cyan
Write-Host ("=" * 60) -ForegroundColor $Cyan
Write-Host ""
Write-Host "📁 Generated Files:" -ForegroundColor $Green
Write-Host "  - .circleci/config.yml (CircleCI configuration)" -ForegroundColor $White
Write-Host "  - .gitignore (Updated with CircleCI entries)" -ForegroundColor $White
Write-Host "  - trigger-daily-build.ps1 (Manual daily build trigger)" -ForegroundColor $White
Write-Host "  - create-release.ps1 (Create new release)" -ForegroundColor $White
Write-Host "  - validate-config.ps1 (Validate CircleCI config)" -ForegroundColor $White
Write-Host ""
Write-Host "🚀 Next Steps:" -ForegroundColor $Yellow
Write-Host "  1. Login to CircleCI: https://circleci.com/login" -ForegroundColor $White
Write-Host "  2. Add your repository to CircleCI" -ForegroundColor $White
Write-Host "  3. Create context 'termux-build' with GITHUB_TOKEN" -ForegroundColor $White
Write-Host "  4. Test: ./validate-config.ps1" -ForegroundColor $White
Write-Host "  5. Trigger release: ./create-release.ps1 -Version v1.0.0" -ForegroundColor $White
Write-Host "  6. Trigger daily build: ./trigger-daily-build.ps1" -ForegroundColor $White
Write-Host ""
Write-Host "📊 Monitor builds:" -ForegroundColor $Yellow
Write-Host "  https://app.circleci.com/pipelines/github/mrizwan-OS/termux-app" -ForegroundColor $White
Write-Host ""
Write-Host "=" * 60 -ForegroundColor $Cyan
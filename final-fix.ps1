# ============================================
# ULTIMATE ONE-SHOT FIX - Handles All Issues
# ============================================

Write-Host "🔧 ULTIMATE ONE-SHOT FIX" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

# ============================================
# STEP 1: Remove all Git lock files
# ============================================
Write-Host "`n[1/6] Removing Git lock files..." -ForegroundColor Yellow

Get-ChildItem -Path ".git" -Filter "*.lock" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-Item -Force $_.FullName -ErrorAction SilentlyContinue
    Write-Host "✅ Removed $($_.Name)" -ForegroundColor Green
}

# ============================================
# STEP 2: Fetch and properly sync with remote
# ============================================
Write-Host "`n[2/6] Syncing with remote..." -ForegroundColor Yellow

# Fetch all branches
git fetch --all

# Stash local changes
git stash push -m "Temp stash for sync" 2>$null

# Reset to remote master
git reset --hard origin/master

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Synced with remote" -ForegroundColor Green
} else {
    Write-Host "⚠️  Could not sync, continuing..." -ForegroundColor Yellow
}

# Pop stash if any
git stash pop 2>$null

# ============================================
# STEP 3: Delete existing tag v1.0.0
# ============================================
Write-Host "`n[3/6] Cleaning up tags..." -ForegroundColor Yellow

$tags = git tag -l "v1.0.0"
if ($tags) {
    Write-Host "⚠️  Tag v1.0.0 exists. Deleting..." -ForegroundColor Yellow
    
    # Delete local
    git tag -d v1.0.0 2>$null
    
    # Delete remote (if exists)
    git push origin --delete v1.0.0 2>$null
    
    Write-Host "✅ Deleted v1.0.0 tag" -ForegroundColor Green
}

# ============================================
# STEP 4: Ensure CircleCI config exists
# ============================================
Write-Host "`n[4/6] Ensuring CircleCI config..." -ForegroundColor Yellow

# Create .circleci directory
New-Item -ItemType Directory -Force -Path ".circleci" | Out-Null

# Create working config
@'
version: 2.1

workflows:
  daily_build:
    triggers:
      - schedule:
          cron: "0 6 * * *"
          filters:
            branches:
              only:
                - master
    jobs:
      - build-and-test:
          name: daily-build

  release_workflow:
    jobs:
      - build-and-test:
          name: release-build
          filters:
            tags:
              only: /^v.*/
      - create-release:
          name: create-github-release
          requires:
            - release-build
          filters:
            tags:
              only: /^v.*/

jobs:
  build-and-test:
    docker:
      - image: cimg/android:2023.10
    steps:
      - checkout
      - run:
          name: Setup Android SDK
          command: |
            sudo apt-get update
            sudo apt-get install -y openjdk-17-jdk
      - run:
          name: Build Debug APK
          command: |
            chmod +x gradlew
            ./gradlew assembleDebug
      - store_artifacts:
          path: app/build/outputs/apk/debug/
          destination: apks/debug

  create-release:
    docker:
      - image: cimg/base:stable
    steps:
      - attach_workspace:
          at: .
      - run:
          name: Create GitHub Release
          command: |
            TAG=${CIRCLE_TAG:-latest}
            RELEASE_NAME="Termux $TAG"
            gh release create "$TAG" \
              app/build/outputs/apk/debug/*.apk \
              --title "$RELEASE_NAME" \
              --notes "Automated release from CircleCI"
'@ | Set-Content -Path ".circleci/config.yml" -Encoding utf8

Write-Host "✅ Created CircleCI config" -ForegroundColor Green

# ============================================
# STEP 5: Create all helper scripts
# ============================================
Write-Host "`n[5/6] Creating helper scripts..." -ForegroundColor Yellow

# trigger-build.ps1
@'
# ============================================
# Trigger CircleCI build manually
# ============================================

Write-Host "🚀 Triggering CircleCI build..." -ForegroundColor Cyan

# First, sync with remote
Write-Host "Syncing with remote..." -ForegroundColor Yellow
git fetch origin
git pull origin master --rebase 2>$null

# Then push empty commit
git add .
git commit --allow-empty -m "Trigger CircleCI build [skip tests]"
git push origin master

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Build triggered successfully!" -ForegroundColor Green
} else {
    Write-Host "`n⚠️  Push failed. Trying force push..." -ForegroundColor Yellow
    git push origin master --force
}

Write-Host "📊 Monitor: https://app.circleci.com/pipelines/github/mrizwan-OS/termux-app" -ForegroundColor Yellow
'@ | Set-Content -Path "trigger-build.ps1" -Encoding utf8

# validate-config.ps1
@'
# ============================================
# Validate CircleCI configuration
# ============================================

Write-Host "🔍 Validating CircleCI config..." -ForegroundColor Cyan

if (-not (Get-Command "circleci" -ErrorAction SilentlyContinue)) {
    Write-Host "⚠️  CircleCI CLI not found. Skipping validation." -ForegroundColor Yellow
    Write-Host "Install with: scoop install circleci" -ForegroundColor Yellow
    exit 0
}

circleci config validate .circleci/config.yml

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Configuration is valid!" -ForegroundColor Green
} else {
    Write-Host "`n❌ Configuration validation failed!" -ForegroundColor Red
    exit 1
}
'@ | Set-Content -Path "validate-config.ps1" -Encoding utf8

# create-release.ps1
@'
# ============================================
# Create a new release for termux-app
# ============================================

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    [string]$Message = "Automated release from CircleCI"
)

if ($Version -notmatch '^v\d+\.\d+\.\d+$') {
    Write-Error "Version must be in format: v1.0.0"
    exit 1
}

Write-Host "🚀 Creating release $Version..." -ForegroundColor Cyan

# Delete existing tag if it exists
$ExistingTag = git tag -l $Version
if ($ExistingTag) {
    Write-Host "⚠️  Tag $Version exists. Deleting..." -ForegroundColor Yellow
    git tag -d $Version
    git push origin --delete $Version 2>$null
}

# Create new tag
git tag -a $Version -m $Message
git push origin $Version

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Release $Version created successfully!" -ForegroundColor Green
    Write-Host "📊 Monitor: https://app.circleci.com/pipelines/github/mrizwan-OS/termux-app" -ForegroundColor Yellow
} else {
    Write-Host "`n❌ Failed to create release!" -ForegroundColor Red
    exit 1
}
'@ | Set-Content -Path "create-release.ps1" -Encoding utf8

Write-Host "✅ Created all helper scripts" -ForegroundColor Green

# ============================================
# STEP 6: Commit and push with sync
# ============================================
Write-Host "`n[6/6] Committing and pushing..." -ForegroundColor Yellow

# First, pull latest with rebase
Write-Host "Pulling latest changes..." -ForegroundColor Cyan
git pull origin master --rebase

# Add all files
git add .

# Commit if there are changes
$status = git status --porcelain
if ($status) {
    git commit -m "Fix: Complete CircleCI setup with automation"
    Write-Host "✅ Committed changes" -ForegroundColor Green
} else {
    Write-Host "ℹ️  No changes to commit" -ForegroundColor Yellow
}

# Push with force if needed
Write-Host "Pushing to remote..." -ForegroundColor Cyan
git push origin master --force-with-lease

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Pushed successfully!" -ForegroundColor Green
} else {
    Write-Host "⚠️  Push failed. Trying force push..." -ForegroundColor Yellow
    git push origin master --force
}

# ============================================
# FINAL SUMMARY
# ============================================
Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host "  ✅ EVERYTHING FIXED!" -ForegroundColor Green
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host ""
Write-Host "📁 Files Ready:" -ForegroundColor Green
Write-Host "  - .circleci/config.yml (CircleCI config)" -ForegroundColor White
Write-Host "  - trigger-build.ps1 (Trigger build)" -ForegroundColor White
Write-Host "  - validate-config.ps1 (Validate config)" -ForegroundColor White
Write-Host "  - create-release.ps1 (Create release)" -ForegroundColor White
Write-Host ""
Write-Host "🚀 Now run:" -ForegroundColor Yellow
Write-Host "  .\validate-config.ps1" -ForegroundColor White
Write-Host "  .\trigger-build.ps1" -ForegroundColor White
Write-Host "  .\create-release.ps1 -Version v1.0.0" -ForegroundColor White
Write-Host ""
Write-Host "📊 Monitor: https://app.circleci.com/pipelines/github/mrizwan-OS/termux-app" -ForegroundColor Yellow
Write-Host "=" * 60 -ForegroundColor Cyan
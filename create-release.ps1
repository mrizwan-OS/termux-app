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

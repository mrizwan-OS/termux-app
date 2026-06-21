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

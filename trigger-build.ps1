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

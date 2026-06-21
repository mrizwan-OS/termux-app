# ============================================
# Trigger Daily Build manually
# ============================================

Write-Host "Triggering daily build for termux-app..." -ForegroundColor Cyan

# Push an empty commit to trigger the daily build
git commit --allow-empty -m "Trigger daily build [skip tests]"
git push origin master

Write-Host "Daily build triggered successfully!" -ForegroundColor Green
Write-Host "Monitor progress: https://app.circleci.com/pipelines/github/termux/termux-app" -ForegroundColor Yellow

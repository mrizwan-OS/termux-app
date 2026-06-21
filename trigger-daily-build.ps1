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

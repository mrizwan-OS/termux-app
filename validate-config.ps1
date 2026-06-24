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

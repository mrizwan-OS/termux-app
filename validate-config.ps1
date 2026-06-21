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
    Write-Host "✅ Configuration is valid!" -ForegroundColor Green
} else {
    Write-Error "❌ Configuration validation failed!"
    exit 1
}

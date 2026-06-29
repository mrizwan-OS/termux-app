# Setup-Termux.ps1 - Complete setup script
param(
    [string]$FirebaseKeyPath = "C:\Users\a-mri\Downloads\service-account-key.json"
)

Write-Host "🔧 Setting up Termux Project" -ForegroundColor Cyan
Write-Host "============================`n" -ForegroundColor Cyan

# 1. Clean the project
Write-Host "Step 1: Cleaning project..." -ForegroundColor Yellow
.\gradlew clean --no-daemon

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Clean failed!" -ForegroundColor Red
    exit 1
}

# 2. Build the project (skip checkstyle for now)
Write-Host "`nStep 2: Building project..." -ForegroundColor Yellow
.\gradlew build -x checkstyleMain -x checkstyleTest --no-daemon

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Build successful!" -ForegroundColor Green
} else {
    Write-Host "❌ Build failed. Check the errors above." -ForegroundColor Red
    exit 1
}

# 3. Setup Firebase
Write-Host "`nStep 3: Setting up Firebase..." -ForegroundColor Yellow
$targetDir = "src/main/resources"
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

if (Test-Path $FirebaseKeyPath) {
    Copy-Item $FirebaseKeyPath "$targetDir/service-account-key.json" -Force
    Write-Host "✅ Firebase key copied to: $targetDir/service-account-key.json" -ForegroundColor Green
} else {
    Write-Host "ℹ️  Firebase key not found at: $FirebaseKeyPath" -ForegroundColor Yellow
    Write-Host "   Creating sample placeholder..." -ForegroundColor Yellow
    @"
{
  "type": "service_account",
  "project_id": "your-project-id",
  "private_key_id": "your-private-key-id",
  "private_key": "-----BEGIN PRIVATE KEY-----\nYour Private Key Here\n-----END PRIVATE KEY-----\n",
  "client_email": "your-service-account@your-project.iam.gserviceaccount.com",
  "client_id": "your-client-id",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/your-service-account%40your-project.iam.gserviceaccount.com"
}
"@ | Out-File -FilePath "$targetDir/service-account-key.sample.json" -Encoding UTF8
    Write-Host "✅ Sample placeholder created at: $targetDir/service-account-key.sample.json" -ForegroundColor Green
}

# 4. Run the application
Write-Host "`nStep 4: Running application..." -ForegroundColor Yellow
.\gradlew run --no-daemon

# 5. Create fat JAR
Write-Host "`nStep 5: Creating fat JAR..." -ForegroundColor Yellow
.\gradlew fatJar --no-daemon

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "✅ Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`n📋 Available commands:" -ForegroundColor Yellow
Write-Host "  ./gradlew run          - Run the application" -ForegroundColor White
Write-Host "  ./gradlew build        - Build the application" -ForegroundColor White
Write-Host "  ./gradlew fatJar       - Create executable JAR" -ForegroundColor White
Write-Host "  ./gradlew quickRun     - Run without checkstyle" -ForegroundColor White
Write-Host "  ./gradlew setupFirebase - Firebase setup instructions" -ForegroundColor White
Write-Host "`n📦 To run the standalone JAR:" -ForegroundColor Yellow
Write-Host "  java -jar build/libs/termux-app-1.0.0-SNAPSHOT-all.jar" -ForegroundColor White
Write-Host "`n🔑 For Firebase with Java:" -ForegroundColor Yellow
Write-Host "  1. Get service account key from Firebase Console" -ForegroundColor White
Write-Host "  2. Place in: src/main/resources/service-account-key.json" -ForegroundColor White
Write-Host "  3. Or set: `$env:GOOGLE_APPLICATION_CREDENTIALS = 'path/to/key.json'" -ForegroundColor White
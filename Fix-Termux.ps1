# Fix-Termux.ps1 - Complete fix for Termux project

Write-Host "🔧 Fixing Termux Project" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan

# 1. Backup original build.gradle
if (Test-Path "build.gradle") {
    Copy-Item "build.gradle" "build.gradle.backup" -Force
    Write-Host "✅ Created backup: build.gradle.backup" -ForegroundColor Green
}

# 2. Check if we're in the right directory
if (-not (Test-Path "src/main/java")) {
    Write-Host "❌ Not in project root directory!" -ForegroundColor Red
    Write-Host "Please run this script from the termux-app directory" -ForegroundColor Yellow
    exit 1
}

# 3. Create Firebase service account directory
$firebaseDir = "src/main/resources"
if (-not (Test-Path $firebaseDir)) {
    New-Item -ItemType Directory -Path $firebaseDir -Force | Out-Null
    Write-Host "✅ Created: $firebaseDir" -ForegroundColor Green
}

# 4. Create a sample Firebase service account placeholder
$sampleKey = @"
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
"@

$sampleKeyPath = "$firebaseDir/service-account-key.sample.json"
if (-not (Test-Path $sampleKeyPath)) {
    $sampleKey | Out-File -FilePath $sampleKeyPath -Encoding UTF8
    Write-Host "✅ Created sample: $sampleKeyPath" -ForegroundColor Green
}

# 5. Create a Firebase test class
$firebaseTestDir = "src/main/java/com/termux"
if (-not (Test-Path $firebaseTestDir)) {
    New-Item -ItemType Directory -Path $firebaseTestDir -Force | Out-Null
}

$firebaseTestContent = @"
package com.termux;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import java.io.FileInputStream;
import java.io.IOException;

public class FirebaseTest {
    
    public static boolean initialize() {
        try {
            // Try to load service account
            String keyPath = System.getenv("GOOGLE_APPLICATION_CREDENTIALS");
            if (keyPath == null) {
                keyPath = "src/main/resources/service-account-key.json";
            }
            
            FileInputStream serviceAccount = new FileInputStream(keyPath);
            
            FirebaseOptions options = FirebaseOptions.builder()
                .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                .build();
            
            FirebaseApp.initializeApp(options);
            System.out.println("✅ Firebase initialized successfully!");
            return true;
            
        } catch (IOException e) {
            System.err.println("⚠️  Firebase not initialized: " + e.getMessage());
            System.err.println("To use Firebase, place your service account key in:");
            System.err.println("  src/main/resources/service-account-key.json");
            System.err.println("Or set GOOGLE_APPLICATION_CREDENTIALS environment variable");
            return false;
        }
    }
    
    public static void main(String[] args) {
        initialize();
    }
}
"@

$firebaseTestPath = "$firebaseTestDir/FirebaseTest.java"
if (-not (Test-Path $firebaseTestPath)) {
    $firebaseTestContent | Out-File -FilePath $firebaseTestPath -Encoding UTF8
    Write-Host "✅ Created: $firebaseTestPath" -ForegroundColor Green
}

# 6. Get SHA-1 (for Java keystore)
Write-Host "`n🔑 Getting SHA-1 for Java keystore..." -ForegroundColor Yellow
$keystorePath = "$env:USERPROFILE\.keystore"

if (-not (Test-Path $keystorePath)) {
    Write-Host "Creating Java keystore..." -ForegroundColor Yellow
    keytool -genkey -v -keystore $keystorePath -alias termux -keyalg RSA -keysize 2048 -validity 10000 -storepass termux123 -keypass termux123 -dname "CN=Termux, OU=Dev, O=Termux, L=City, S=State, C=US"
}

$output = keytool -list -v -keystore $keystorePath -alias termux -storepass termux123 -keypass termux123 2>$null
if ($LASTEXITCODE -eq 0) {
    $sha1 = $output | Select-String "SHA1:" 
    if ($sha1) {
        Write-Host "✅ SHA-1: $($sha1 -replace 'SHA1: ', '')" -ForegroundColor Green
    }
}

# 7. Check Java version
$javaVersion = java -version 2>&1
Write-Host "`n☕ Java version:" -ForegroundColor Yellow
Write-Host $javaVersion[0] -ForegroundColor Gray

# 8. Run gradle clean
Write-Host "`n🧹 Running gradle clean..." -ForegroundColor Yellow
.\gradlew clean --no-daemon

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "✅ Fix Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "`n📋 Next Steps:" -ForegroundColor Yellow
Write-Host "1. For Firebase: Get a service account key from Firebase Console" -ForegroundColor White
Write-Host "   Place it in: src/main/resources/service-account-key.json" -ForegroundColor White
Write-Host "2. Or set environment variable:" -ForegroundColor White
Write-Host "   `$env:GOOGLE_APPLICATION_CREDENTIALS = 'path/to/key.json'" -ForegroundColor Cyan
Write-Host "3. Test Firebase: .\gradlew run -PmainClass=com.termux.FirebaseTest" -ForegroundColor White
Write-Host "4. Build the project: .\gradlew build" -ForegroundColor White
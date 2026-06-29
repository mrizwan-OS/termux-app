package com.termux;

import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.auth.oauth2.GoogleCredentials;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;

public class Main {
    
    public static void main(String[] args) {
        System.out.println("🚀 Termux Application Starting...");
        System.out.println("📂 Working directory: " + System.getProperty("user.dir"));
        
        // Try multiple locations for Firebase credentials
        boolean firebaseInitialized = false;
        String[] possiblePaths = {
            "src/main/resources/service-account-key.json",
            "service-account-key.json",
            System.getenv("GOOGLE_APPLICATION_CREDENTIALS")
        };
        
        for (String path : possiblePaths) {
            if (path != null && !path.isEmpty()) {
                File keyFile = new File(path);
                if (keyFile.exists()) {
                    try {
                        FileInputStream serviceAccount = new FileInputStream(keyFile);
                        FirebaseOptions options = FirebaseOptions.builder()
                            .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                            .build();
                        FirebaseApp.initializeApp(options);
                        firebaseInitialized = true;
                        System.out.println("✅ Firebase initialized successfully!");
                        System.out.println("   Using credentials from: " + path);
                        System.out.println("   Project: " + FirebaseApp.getInstance().getName());
                        break;
                    } catch (IOException e) {
                        System.err.println("⚠️  Could not load Firebase credentials from: " + path);
                        System.err.println("   Error: " + e.getMessage());
                    }
                }
            }
        }
        
        if (!firebaseInitialized) {
            System.out.println("ℹ️  Firebase credentials not found.");
            System.out.println("   Run './gradlew setupFirebase' for instructions");
            System.out.println("⚠️  Running without Firebase (offline mode)");
        }
        
        System.out.println("✅ Application ready!");
        System.out.println("📋 Type 'exit' to quit");
    }
}
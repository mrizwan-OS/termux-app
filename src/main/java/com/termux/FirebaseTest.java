package com.termux;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseToken;
import com.google.firebase.cloud.FirestoreClient;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.CollectionReference;
import com.google.cloud.firestore.DocumentSnapshot;

import java.io.FileInputStream;
import java.io.IOException;

public class FirebaseTest {
    
    public static void initialize() {
        try {
            // Initialize Firebase with service account
            FileInputStream serviceAccount = new FileInputStream(
                "src/main/resources/service-account-key.json"
            );
            
            FirebaseOptions options = FirebaseOptions.builder()
                .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                .build();
            
            FirebaseApp.initializeApp(options);
            System.out.println("✅ Firebase initialized successfully!");
            
        } catch (IOException e) {
            System.err.println("❌ Failed to initialize Firebase: " + e.getMessage());
            System.err.println("Make sure service-account-key.json exists in src/main/resources/");
        }
    }
    
    public static void main(String[] args) {
        initialize();
    }
}
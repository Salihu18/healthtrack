# Firebase Auth
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firestore
-keep class com.google.firestore.** { *; }
-dontwarn com.google.firestore.**

# Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Your app
-keep class com.example.healthtrack_app.** { *; }
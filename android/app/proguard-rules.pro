# Flutter
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }

# AppAuth / flutter_appauth (OAuth redirect + token exchange)
-keep class net.openid.appauth.** { *; }
-keep class androidx.browser.** { *; }

# OkHttp / Okio (used by Auth0)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# WebView InAppWebView
-keep class com.pichillilorenzo.flutter_inappwebview_android.** { *; }

# Gson / JSON serialization safety
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Kotlin metadata
-keep class kotlin.Metadata { *; }

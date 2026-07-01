# Google Play Core — Flutter's embedding references deferred-component classes
# even when we don't use them. Without these keeps, `flutter build apk --release`
# fails at :app:minifyReleaseWithR8 with "Missing class com.google.android.play.core.*".
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-keep interface com.google.android.play.core.** { *; }

# ota_update (self-update) — keep plugin classes referenced from the manifest.
-keep class sk.fourq.otaupdate.** { *; }
-dontwarn sk.fourq.otaupdate.**

# Flutter embedding
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

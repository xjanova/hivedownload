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

# ExoPlayer / Media3 (video_player backend). R8 was obfuscating/stripping the
# HTTP data source + MP4 extractor, causing ExoPlayer "Source error" (z0.k) on
# release builds even though the URL is valid. Keep the whole media3 stack.
-keep class androidx.media3.** { *; }
-keep interface androidx.media3.** { *; }
-dontwarn androidx.media3.**
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

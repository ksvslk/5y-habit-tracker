# Keep MediaPipe classes for flutter_gemma
-keep class com.google.mediapipe.** { *; }
-keepclassmembers class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

# Keep protocol buffer classes
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite {
  <fields>;
}

# Keep TensorFlow Lite
-keep class org.tensorflow.lite.** { *; }
-keepclassmembers class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# Keep Google AI Edge classes
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Keep all native methods (required for JNI)
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Flutter Gemma classes
-keep class com.xaviernewswire.flutter_gemma.** { *; }
-keepclassmembers class com.xaviernewswire.flutter_gemma.** { *; }
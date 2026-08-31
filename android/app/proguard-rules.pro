# R8/ProGuard Keep-Regeln.

# --- JNA (Java Native Access) ---
# Vosk lädt seine native Bibliothek über JNA. Die native Lib (libjnidispatch.so)
# sucht Klassen/Felder wie com.sun.jna.Pointer#peer zur Laufzeit per JNI über die
# ORIGINALNAMEN. R8 darf diese daher nicht umbenennen oder entfernen – sonst:
#   java.lang.UnsatisfiedLinkError: Can't obtain peer field ID for class com.sun.jna.Pointer
-keep class com.sun.jna.** { *; }
-keepclassmembers class com.sun.jna.** { *; }
-keep class * implements com.sun.jna.Library { *; }
-keep class * extends com.sun.jna.Structure { *; }
-dontwarn com.sun.jna.**
-dontwarn java.awt.**

# --- Vosk ---
-keep class org.vosk.** { *; }
-dontwarn org.vosk.**

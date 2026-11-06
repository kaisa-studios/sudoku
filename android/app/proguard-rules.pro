# Release build (R8): keep classes that libraries create via reflection.
#
# WorkManager (pulled in by the Google Mobile Ads SDK) opens its Room database through
# Class.forName("…WorkDatabase_Impl"). Without these rules R8 removes the generated
# class and the app crashes at start ("Failed to create an instance of
# androidx.work.impl.WorkDatabase") – found in the Mandala emulator test, 5 Nov 2026.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }

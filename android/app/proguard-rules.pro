# WorkManager (used by flutter_downloader) instantiates its Room database
# reflectively; R8 full mode strips the generated implementation otherwise.
-keep class androidx.work.** { *; }
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.room.** { *; }
-keep class vn.hunghd.flutterdownloader.** { *; }

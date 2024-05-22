-keep class com.sun.jna.** { *; }
-keepclassmembers class * extends com.sun.jna.Structure {
   public *;
   protected *;
}

-dontwarn java.awt.**
-dontwarn com.sun.jna.Native$AWT
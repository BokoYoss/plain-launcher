mkdir addons

cd plain-launcher-android-plugin

cmd /C .\gradlew assemble

cd ..

robocopy plain-launcher-android-plugin\plugin\build\outputs\addons addons /e

#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"

mkdir -p addons

(cd plain-launcher-android-plugin && sh ./gradlew assemble)

cp -r plain-launcher-android-plugin/plugin/build/outputs/addons/. addons/

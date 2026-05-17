#!/bin/bash
set -e

echo ">>> Installazione Android SDK..."
ANDROID_SDK_ROOT=$HOME/android-sdk
mkdir -p $ANDROID_SDK_ROOT/cmdline-tools

wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O /tmp/cmdtools.zip
unzip -q /tmp/cmdtools.zip -d /tmp/cmdtools
mkdir -p $ANDROID_SDK_ROOT/cmdline-tools/latest
mv /tmp/cmdtools/cmdline-tools/* $ANDROID_SDK_ROOT/cmdline-tools/latest/

echo "export ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT" >> ~/.bashrc
echo "export ANDROID_HOME=$ANDROID_SDK_ROOT" >> ~/.bashrc
echo "export PATH=\$PATH:\$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:\$ANDROID_SDK_ROOT/platform-tools" >> ~/.bashrc
source ~/.bashrc

echo ">>> Accettazione licenze e installazione API 33..."
yes | $ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager --licenses
$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager \
    "platforms;android-33" \
    "build-tools;33.0.2" \
    "platform-tools"

echo ">>> Setup completato!"

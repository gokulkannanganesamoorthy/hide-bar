#!/bin/bash
set -e

echo "Building HideBar..."
swift build -c release

echo "Setting up app bundle..."
mkdir -p HideBar.app/Contents/MacOS
cp .build/release/HideBar HideBar.app/Contents/MacOS/HideBar
cp Info.plist HideBar.app/Contents/Info.plist

echo "Codesigning app bundle..."
codesign --force --deep -s - HideBar.app

echo "Running HideBar from App Bundle..."
open HideBar.app

#!/bin/bash
set -e

APP_NAME="MiniKeys"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"

echo "Building ${APP_NAME}..."
swift build -c release

echo "Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp Resources/Info.plist "${APP_BUNDLE}/Contents/"

# Ad-hoc sign so macOS allows execution
codesign -s - --force "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

echo "Done! Run with: open ${APP_BUNDLE}"

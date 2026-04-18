APP_NAME := CodexUsageViewer
BUILD_DIR := .build/release
APP_DIR := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS := $(APP_DIR)/Contents
MACOS := $(CONTENTS)/MacOS

.PHONY: build run test app clean

build:
	swift build -c release

run:
	swift run $(APP_NAME)

test:
	swift build

app: build
	rm -rf "$(APP_DIR)"
	mkdir -p "$(MACOS)"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(MACOS)/$(APP_NAME)"
	printf '%s\n' \
	'<?xml version="1.0" encoding="UTF-8"?>' \
	'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
	'<plist version="1.0">' \
	'<dict>' \
	'  <key>CFBundleExecutable</key>' \
	'  <string>$(APP_NAME)</string>' \
	'  <key>CFBundleIdentifier</key>' \
	'  <string>local.codex.usage-viewer</string>' \
	'  <key>CFBundleName</key>' \
	'  <string>$(APP_NAME)</string>' \
	'  <key>CFBundlePackageType</key>' \
	'  <string>APPL</string>' \
	'  <key>CFBundleShortVersionString</key>' \
	'  <string>1.0</string>' \
	'  <key>CFBundleVersion</key>' \
	'  <string>1</string>' \
	'  <key>LSMinimumSystemVersion</key>' \
	'  <string>14.0</string>' \
	'</dict>' \
	'</plist>' > "$(CONTENTS)/Info.plist"

clean:
	rm -rf .build

APP_NAME := TokenScope
BUILD_DIR := .build/release
APP_DIR := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS := $(APP_DIR)/Contents
MACOS := $(CONTENTS)/MacOS
RESOURCES := $(CONTENTS)/Resources
ICON_FILE := Assets/AppIcon.icns
ICON_SCRIPT := scripts/generate_app_icon.swift

.PHONY: build run test app clean

build:
	swift build -c release

run:
	swift run $(APP_NAME)

test:
	swift run UsageTests

$(ICON_FILE): $(ICON_SCRIPT)
	swift "$(ICON_SCRIPT)" "$(ICON_FILE)"

app: build $(ICON_FILE)
	rm -rf "$(APP_DIR)"
	mkdir -p "$(MACOS)" "$(RESOURCES)"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(MACOS)/$(APP_NAME)"
	cp "$(ICON_FILE)" "$(RESOURCES)/AppIcon.icns"
	printf '%s\n' \
	'<?xml version="1.0" encoding="UTF-8"?>' \
	'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
	'<plist version="1.0">' \
	'<dict>' \
	'  <key>CFBundleExecutable</key>' \
	'  <string>$(APP_NAME)</string>' \
	'  <key>CFBundleIdentifier</key>' \
	'  <string>local.tokenscope.app</string>' \
	'  <key>CFBundleName</key>' \
	'  <string>$(APP_NAME)</string>' \
	'  <key>CFBundleIconFile</key>' \
	'  <string>AppIcon</string>' \
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

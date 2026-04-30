APP_NAME := Runbook
BUNDLE := $(APP_NAME).app
INSTALL_DIR := /Applications

build:
	swift build -c release

bundle: build icon
	@mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	command cp .build/release/RunbookMac $(BUNDLE)/Contents/MacOS/$(APP_NAME)
	command cp AppIcon.icns $(BUNDLE)/Contents/Resources/AppIcon.icns
	command cp Info.plist $(BUNDLE)/Contents/Info.plist

icon:
	@test -f AppIcon.icns || swift scripts/generate-icon.swift

deploy: bundle
	pkill -9 -f "$(APP_NAME)" 2>/dev/null || true
	@sleep 1
	command rm -rf $(INSTALL_DIR)/$(BUNDLE)
	ditto $(BUNDLE) $(INSTALL_DIR)/$(BUNDLE)
	@osascript -e 'use framework "AppKit"' \
		-e 'set iconImage to current application'\''s NSImage'\''s alloc()'\''s initWithContentsOfFile:"$(INSTALL_DIR)/$(BUNDLE)/Contents/Resources/AppIcon.icns"' \
		-e 'current application'\''s NSWorkspace'\''s sharedWorkspace()'\''s setIcon:iconImage forFile:"$(INSTALL_DIR)/$(BUNDLE)" options:0'
	@killall Dock 2>/dev/null || true
	@echo "Deployed to $(INSTALL_DIR)/$(BUNDLE)"
	open $(INSTALL_DIR)/$(BUNDLE)

clean:
	rm -rf .build $(BUNDLE)

test:
	swift test

release:
	@if [ -z "$(VERSION)" ]; then echo "Usage: make release VERSION=1.2.0"; exit 1; fi
	@if ! git diff --quiet || ! git diff --cached --quiet; then \
	    echo "Working tree is dirty. Commit or stash first."; exit 1; fi
	@if git rev-parse "v$(VERSION)" >/dev/null 2>&1; then \
	    echo "Tag v$(VERSION) already exists. Pick a different VERSION or delete the tag."; exit 1; fi
	swift test
	swift build -c release
	sed -i '' 's/MARKETING_VERSION: ".*"/MARKETING_VERSION: "$(VERSION)"/' project.yml
	sed -i '' 's/CURRENT_PROJECT_VERSION: ".*"/CURRENT_PROJECT_VERSION: "$(VERSION)"/' project.yml
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(VERSION)" Info.plist
	git add project.yml Info.plist
	git commit -m "Bump version to $(VERSION)"
	git tag -a "v$(VERSION)" -m "v$(VERSION)"
	@echo "Tagged v$(VERSION). Push with: git push --follow-tags"

.PHONY: build bundle icon deploy clean test release

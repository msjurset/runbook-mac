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
	sed -i '' 's/MARKETING_VERSION: ".*"/MARKETING_VERSION: "$(VERSION)"/' project.yml
	sed -i '' 's/CURRENT_PROJECT_VERSION: ".*"/CURRENT_PROJECT_VERSION: "$(VERSION)"/' project.yml
	git add project.yml
	git commit -m "Bump version to $(VERSION)"
	git tag "v$(VERSION)"
	@echo "Tagged v$(VERSION). Push with: git push && git push --tags"

.PHONY: build bundle icon deploy clean test release

APP := Eremos Terminal
DERIVED := build
XCB := xcodebuild -project EremosTerminal.xcodeproj -scheme EremosTerminal -derivedDataPath $(DERIVED) \
	-clonedSourcePackagesDirPath .build/spm \
	-skipPackagePluginValidation

.PHONY: project open build test run install dist clean

project: ## generate EremosTerminal.xcodeproj from project.yml
	xcodegen -q

open: project ## open in Xcode
	open EremosTerminal.xcodeproj

build: project ## Release build → build/Build/Products/Release/Eremos Terminal.app
	$(XCB) -configuration Release build -quiet

test: project
	$(XCB) -configuration Debug test -quiet

run: build ## build and launch
	open "$(DERIVED)/Build/Products/Release/$(APP).app"

install: build ## copy to /Applications
	rm -rf "/Applications/$(APP).app"
	cp -R "$(DERIVED)/Build/Products/Release/$(APP).app" /Applications/
	@echo "Installed: /Applications/$(APP).app"

VERSION := $(shell sed -n 's/.*MARKETING_VERSION: "\(.*\)"/\1/p' project.yml)
ZIP := dist/Eremos-Terminal-$(VERSION).zip

dist: build ## zip for a GitHub release → dist/Eremos-Terminal-<version>.zip (universal, ad-hoc signed)
	mkdir -p dist
	rm -f "$(ZIP)"
	ditto -c -k --keepParent "$(DERIVED)/Build/Products/Release/$(APP).app" "$(ZIP)"
	@shasum -a 256 "$(ZIP)"

clean:
	rm -rf $(DERIVED) dist

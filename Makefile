APP := Eremos Terminal
DERIVED := build
XCB := xcodebuild -project EremosTerminal.xcodeproj -scheme EremosTerminal -derivedDataPath $(DERIVED) \
	-clonedSourcePackagesDirPath .build/spm \
	-skipPackagePluginValidation

.PHONY: project open build test run install clean

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

clean:
	rm -rf $(DERIVED)

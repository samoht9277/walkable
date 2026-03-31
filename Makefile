.PHONY: generate build build-watch test test-ui test-all clean

SIMULATOR = platform=iOS Simulator,name=iPhone 16
WATCH_SIM = platform=watchOS Simulator,name=Apple Watch Ultra 3 (49mm)
PROJECT = Walkable.xcodeproj

# Generate Xcode project from project.yml
generate:
	xcodegen generate

# Build iOS app
build: generate
	xcodebuild -project $(PROJECT) -scheme WalkableApp -destination '$(SIMULATOR)' build

# Build watchOS app
build-watch: generate
	xcodebuild -project $(PROJECT) -scheme WalkableWatch -destination '$(WATCH_SIM)' build

# Run unit tests
test:
	xcodebuild test -project $(PROJECT) -scheme WalkableApp -destination '$(SIMULATOR)' -only-testing:WalkableTests

# Run UI tests
test-ui:
	xcodebuild test -project $(PROJECT) -scheme WalkableApp -destination '$(SIMULATOR)' -only-testing:WalkableUITests

# Run all tests
test-all:
	xcodebuild test -project $(PROJECT) -scheme WalkableApp -destination '$(SIMULATOR)'

# Open in Xcode
open:
	open $(PROJECT)

# Clean build artifacts
clean:
	xcodebuild -project $(PROJECT) -scheme WalkableApp clean
	rm -rf ~/Library/Developer/Xcode/DerivedData/Walkable-*

# Count lines of code
loc:
	@find WalkableKit WalkableApp WalkableWatch WalkableWidgets WalkableTests WalkableUITests -name "*.swift" | xargs wc -l | tail -1
	@echo "Files:" && find WalkableKit WalkableApp WalkableWatch WalkableWidgets WalkableTests WalkableUITests -name "*.swift" | wc -l

# Maestro UI tests (visual, takes screenshots)
maestro:
	./scripts/maestro-test.sh

# Run a specific maestro flow
maestro-flow:
	./scripts/maestro-test.sh $(FLOW)

# Install on connected device (run from Xcode instead for signing)
device:
	@echo "Use Xcode: select your device and press Cmd+R"
	@echo "Make sure signing team is set in Signing & Capabilities"

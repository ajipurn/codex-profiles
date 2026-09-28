.PHONY: project build test run package release release-local open icons signing-key

project:
	xcodegen generate

icons:
	swift scripts/make-icons.swift "$(CURDIR)"

build:
	zsh -c 'source scripts/swift-env.sh && swift build "$${SWIFT_FLAGS[@]}" --product CodexProfiles'

test:
	./scripts/test.sh

package: test
	chmod +x scripts/package-app.sh
	./scripts/package-app.sh debug

run: package
	open "dist/Codex Profiles.app"

open: project
	open CodexProfiles.xcodeproj

release:
	python3 scripts/release.py --version "$(VERSION)" --bump "$(BUMP)"

release-local: test
	./scripts/build-release.sh

signing-key:
	./scripts/setup-update-signing.sh

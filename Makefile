.PHONY: project build test run package release open icons signing-key

project:
	xcodegen generate

icons:
	swift scripts/make-icons.swift "$(CURDIR)"

build:
	swift build --product CodexProfiles

test:
	swift run CodexProfilesCheck

package: test
	chmod +x scripts/package-app.sh
	./scripts/package-app.sh debug

run: package
	open "dist/Codex Profiles.app"

open: project
	open CodexProfiles.xcodeproj

release: test
	./scripts/build-release.sh

signing-key:
	./scripts/setup-update-signing.sh

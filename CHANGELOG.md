# Changelog

## 1.3.3

- Redesign the app icon and menu bar icon as a stacked profile cards mark
- Draw both icons in code so they regenerate deterministically with `make icons`
- Menu bar mark keeps a clear two-card silhouette at 22 px

## 1.3.2

- Fix stretched footer buttons by applying content-hugging size outside the button and menu styles

## 1.3.1

- Fix app window closing when confirming account removal by replacing the modal dialog with an inline confirmation banner
- Fix stretched footer buttons so Refresh and Settings hug their content

## 1.3.0

- Polish panel visual hierarchy and readability
- Add shared design tokens, gradient account avatars, and card styling
- Fix truncated account text with wider panel and middle-truncation tooltips
- Clarify row action menu and unify search, favorites, and sort controls
- Thicken quota bars with gradient fill and pill badges for plan, Active, and Live status

## 1.2.1

- Improve usage quota fetching and live refresh

## 1.2.0

- feat: support semantic release version increments
- feat: add one-command GitHub release publishing
- fix: hide routine success notifications
- fix: refresh cached release badge

## 1.1.0

First public release.

### Added

- Sparkle update checks, signed appcasts, and optional automatic installation.
- Universal macOS release builds through GitHub Actions.
- Repository hygiene checks, release validation, contributor documentation, and issue templates.
- Search, favorites, quota sorting, hidden email labels, and menu-bar quota display.

### Fixed

- Stale usage refreshes cannot overwrite an account replaced by an earlier operation.
- Each quota window retains its own remaining percentage when another window is exhausted.
- Packaged apps include their resource bundle and embedded update framework.

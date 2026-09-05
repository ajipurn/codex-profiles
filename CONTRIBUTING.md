# Contributing

Requires macOS 14+, Swift 6+, and Python 3. Full Xcode is required for universal builds. XcodeGen is only needed when regenerating the Xcode project.

```sh
make build
make test
python3 -m unittest discover -s scripts/tests -v
python3 scripts/release_metadata.py check
python3 scripts/check-repository.py
make package
open -n "dist/Codex Profiles.app" --args --demo
```

Keep account tests isolated using the temporary stores and sample identities already used by the regression suite. Do not use real authentication tokens in fixtures, logs, issues, or screenshots.

Use conventional commit prefixes such as `feat:`, `fix:`, `docs:`, or `chore:`. Explain behavior changes and validation in the pull request. Preserve keyboard accessibility and reduced-motion support for UI changes.

`Config/release.json` is the release metadata source. After changing it, run `python3 scripts/release_metadata.py sync`. After changing dependencies or target settings in `project.yml`, run `make project`. Commit `Package.resolved` and the regenerated Xcode project.

The update signing key is not required for development or CI pull-request checks. Only maintainers creating distributable update archives need the private signing key. See [docs/RELEASING.md](docs/RELEASING.md).

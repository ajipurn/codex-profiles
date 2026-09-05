# Release guide

## Distribution model

A version tag triggers GitHub Actions to build a universal app (arm64 and x86_64), run regression tests, code-sign the bundle, optionally notarize it, sign the update archive and appcast, verify the signatures, and create a **draft** GitHub release.

Publishing the draft activates the new update. The stable feed URL is:

```
https://github.com/ajipurn/codex-profiles/releases/latest/download/appcast.xml
```

Each stable release includes:

- `CodexProfiles-<version>.zip`: the application and embedded Sparkle framework.
- `appcast.xml`: the signed Sparkle update feed with the archive's Ed25519 signature.
- `CodexProfiles-<version>.md`: release notes.
- `SHA256SUMS`: checksums for these files.

Pre-releases are not distributed by this stable workflow. Published release assets are immutable in the release scripts; use a new version and build number for corrections.

## First-time signing setup

The public key in `Config/release.json` is already assigned to this project. **Do not generate a replacement key for an existing release.** The corresponding private key is stored in the maintainer's login Keychain under Sparkle's `dev.aji.CodexProfiles.release` account.

On the original signing Mac, this command reuses that key and verifies the public key matches:

```sh
make signing-key
```

For a new fork, choose a distinct Keychain account in the signing scripts, clear the fork's public key in its release configuration, and generate its own key. Change the repository in `Config/release.json`, synchronize metadata, and update documentation/security-report links before publishing the fork.

GitHub Actions needs a repository secret named **SPARKLE_PRIVATE_KEY**. Export the existing private key to a temporary protected file and send it directly to the GitHub secret store:

```sh
umask 077
signing_file="$(mktemp)"
# generate_keys refuses to overwrite an existing file; remove the empty mktemp file first.
rm "$signing_file"
trap 'rm -f "$signing_file"' EXIT
.build/artifacts/sparkle/Sparkle/bin/generate_keys --account dev.aji.CodexProfiles.release -x "$signing_file"
gh secret set SPARKLE_PRIVATE_KEY --repo ajipurn/codex-profiles < "$signing_file"
rm "$signing_file"
trap - EXIT
```

macOS may require approval in Keychain. Do not paste the private key into an issue, chat, command argument, or repository file. Keep an encrypted recovery backup outside the repository: losing the key can break the update path for existing installations. See [Sparkle key rotation](https://sparkle-project.org/documentation/#rotating-signing-keys) before making any key changes.

## Optional Apple Developer ID signing and notarization

Sparkle signatures authenticate update files; Apple Developer ID signing and notarization address Gatekeeper distribution. Without the Apple secrets, the workflow produces an ad-hoc signed, non-notarized build and the README explains the first-launch limitation.

Add these repository secrets to enable Apple signing:

| Secret | Value |
| --- | --- |
| `APPLE_CERTIFICATE_P12` | Base64-encoded exported Developer ID Application certificate and private key |
| `APPLE_CERTIFICATE_PASSWORD` | Password used to export the P12 |
| `APPLE_SIGNING_IDENTITY` | Full Developer ID Application identity, including team ID |

Also add these to enable notarization:

| Secret | Value |
| --- | --- |
| `APPLE_NOTARY_KEY_P8` | Contents of the App Store Connect API private key |
| `APPLE_NOTARY_KEY_ID` | API key ID |
| `APPLE_NOTARY_ISSUER_ID` | API issuer ID |

CI uses a temporary signing Keychain, notarizes the archive, staples the app, regenerates the archive, and only then creates Sparkle signatures and checksums. Temporary credentials are removed at the end of the job. Update the README and release notes when notarization is enabled and verified.

## Publish a new version

1. Update `version` and increase `build` in `Config/release.json`. Use a stable `MAJOR.MINOR.PATCH` version. Keep `repository` and `sparkle_public_key` unchanged.
2. Add `docs/releases/<version>.md` and update `CHANGELOG.md`.
3. Synchronize and validate metadata, run the tests, and commit:

   ```sh
   python3 scripts/release_metadata.py sync
   python3 scripts/release_metadata.py check --require-key
   python3 -m unittest discover -s scripts/tests -v
   make test
   git add Config/release.json CodexProfiles/Info.plist docs/releases CHANGELOG.md
   git commit -m "chore: prepare release 1.1.1"
   git push origin main
   ```

4. Create and push the matching tag, for example:

   ```sh
   git tag -a v1.1.1 -m "Release 1.1.1"
   git push origin v1.1.1
   ```

5. Wait for the **Release** workflow. It rejects mismatched tags, non-increasing build numbers, missing signing keys, invalid signatures, and non-universal release archives.
6. Review the draft, download and smoke-test its ZIP, then publish it as the latest stable release:

   ```sh
   gh release edit v1.1.1 --draft=false --latest --repo ajipurn/codex-profiles
   ```

7. Verify the stable feed URL returns the new version and test **Check for Updates…** from the previous released app.

The first release must be installed manually; there is no previous published build to upgrade. A real old-to-new installation test should be performed before each later release.

If a workflow fails while the release is still a draft, fix the cause and rerun the workflow. Existing published release assets are never overwritten. A workflow can also be started manually for an existing tag.

## Local release validation

```sh
make release
```

This builds for the current Mac architecture and signs using the dedicated Keychain key. It verifies the update signature against the public key embedded in the app and checks that a modified archive is rejected. Local output is in `dist/releases/<version>`.

For universal output on a Mac with full Xcode:

```sh
BUILD_ARCHS="arm64 x86_64" make release
```

`publish-draft.sh` requires a universal archive and a remote version tag. Native local archives are for development verification. The automatic pipeline creates the distributable universal archive.

For local notarization, configure a Developer ID identity and a stored notarytool profile, then pass `CODE_SIGN_IDENTITY` and `NOTARY_KEYCHAIN_PROFILE` to `make release`.

## Updater troubleshooting

- **Disabled updater:** run the packaged release app, rather than the raw Swift executable or preview mode.
- **Feed unavailable:** confirm a stable release is published and its assets include `appcast.xml`.
- **No newer version:** both the semantic version and numeric build number must increase.
- **Invalid signature:** check the release's public key matches the private key used by CI. Do not replace the public key to silence the error.
- **Cannot install:** move the app into Applications, launch that copy, and confirm it is writable for the current user.
- **GitHub release creation failed:** check Actions has `contents: write` and that the configured repository matches this repository.

The signed appcast and update-archive format follow [Sparkle's publishing guide](https://sparkle-project.org/documentation/publishing/).

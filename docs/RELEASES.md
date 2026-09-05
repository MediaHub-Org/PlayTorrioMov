# Building and releases

CI builds every platform. Pull requests run analysis, the test suite and an
Android APK; merges to `main` run the same checks and refresh the shared
build cache.

To cut a downloadable build without tagging a release, dispatch the
**Build and Release** workflow with a `release_tag` such as `v1.2.0` — it
publishes all six platforms. Leave `release_tag` empty to build every
platform and upload artifacts only.

Dispatched builds default to `dev_build`, which titles the release `(dev)`
and publishes it as a GitHub prerelease; the app shows the same marker next
to its version. Untick it once a build has been verified on a device. Tags
matching `v*` publish a full release; a tag carrying a semver prerelease
suffix (`v1.2.0-rc.1`) publishes as a prerelease. Release artifact filenames
are stamped with the app version.

## Release signing

Only **Android** requires signing for the in-app updater to work. `OtaUpdate`
downloads the APK and hands it to the system package installer inside the
app, and Android refuses to replace an installed app whose signature does
not match — so an unsigned (debug-keyed) build cannot update a previous one.
Every CI run mints a fresh debug key, so without a stable release key each
build is a different signer and each update needs an uninstall.

Two repository secrets are required:

| Secret | Required | Notes |
|:--|:--|:--|
| `ANDROID_KEYSTORE_BASE64` | yes | The `.jks` keystore, base64-encoded |
| `ANDROID_KEYSTORE_PASSWORD` | yes | Store password |
| `ANDROID_KEY_ALIAS` | no | Defaults to `playtorriomov` |
| `ANDROID_KEY_PASSWORD` | no | Defaults to the store password |

## All repository secrets

Every secret `build.yml` reads, across all platforms:

| Secret | Used for |
|:--|:--|
| `ANDROID_KEYSTORE_BASE64` | Release signing, see above |
| `ANDROID_KEYSTORE_PASSWORD` | Release signing, see above |
| `ANDROID_KEY_ALIAS` | Release signing, see above |
| `ANDROID_KEY_PASSWORD` | Release signing, see above |
| `ENV_FILE` | Contents written to `.env` before every build (`--dart-define-from-file=.env`); checked first |
| `DOTENV` | Same as `ENV_FILE`, used only if `ENV_FILE` is unset |

List secret **names** (GitHub never returns a secret's value once set, by
design — there is no `gh` command or API call that reveals it, only who set
it and when):

```sh
gh secret list -R MediaHub-Org/PlayTorrioMov
```

To set or rotate one (overwrites silently, no confirmation prompt):

```sh
gh secret set ANDROID_KEYSTORE_BASE64 -R MediaHub-Org/PlayTorrioMov < keystore.b64
```

If you don't have the original value (a keystore password, a generated
`.env`), it must come from wherever it was first created — there's no way
to recover it from GitHub.

`keytool` allows one password to cover both the store and the key, and the
alias is fixed by convention, so the last two are only needed for a
keystore created with different values.

```bash
keytool -genkey -v -keystore playtorriomov-release.jks \
  -keyalg RSA -keysize 4096 -validity 10000 -alias playtorriomov
base64 -w0 playtorriomov-release.jks > keystore.b64   # macOS: base64 -i
```

Add the secrets under Settings → Secrets and variables → Actions. **Keep
the `.jks` backed up** — without it no future build can update an existing
install, and the only recovery is changing `applicationId`, which orphans
every install.

With no secrets set the build still succeeds using the debug key and emits
a warning annotation, so forks and local checkouts are never blocked.

### Other platforms

None of them need signing for updates, because none of them self-install:

| Platform | Updater behaviour | Signing buys |
|:--|:--|:--|
| Windows | Downloads the `.exe`, opens Explorer at it | An Authenticode certificate only removes the SmartScreen warning |
| Linux | Downloads the `.AppImage`, opens the folder | Nothing — AppImages are not signed |
| macOS | Opens the release page in a browser | Developer ID + notarization only removes the Gatekeeper warning |
| iOS | Opens the release page in a browser | iOS cannot self-install; distribution is sideload or the App Store |

There is no single credential that covers several of these: Android uses a
Java keystore, Windows an Authenticode certificate issued by a CA, and Apple
platforms a Developer ID tied to a paid Apple account. They are separate
public key infrastructures, so each would need its own secret if ever added.

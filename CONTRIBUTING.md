# Contributing to ConfDDL

Bug reports, small fixes, translations, and UX improvements are welcome. English and Chinese are both fine for issues and pull requests.

## Report a problem or suggest an improvement

Check [existing issues](https://github.com/Valkqs/ConfDDL/issues) first. For bugs, include your macOS version, Mac architecture, app version, reproduction steps, and expected versus actual behavior. Screenshots help; remove private conference notes or file paths first.

For an incorrect deadline, check the conference's official website and the [CCFDDL source repository](https://github.com/ccfddl/ccf-deadlines). If the error is in the source data, correcting it upstream helps all CCFDDL users. If the source is correct and ConfDDL imports it incorrectly, please report it here.

## Build locally

Requirements: macOS 13+, Xcode Command Line Tools, Swift 5.9+.

```sh
git clone https://github.com/Valkqs/ConfDDL.git
cd ConfDDL
swift build
swift run DeadlineCoreChecks
bash scripts/build.sh
```

Open `dist/ConfDDL.app` to run the packaged menu bar app. Running the raw executable through `swift run ConfDDL` is not the supported launch path: system notification integration requires an application bundle.

Optional network integration check:

```sh
swift run DeadlineCoreChecks --fetch-ccf
```

Core checks use deterministic fixtures and do not depend on a live website. Run live checks when changing CCFDDL downloads or parsing.

## Project layout

| Path | Responsibility |
| --- | --- |
| `Sources/DeadlineCore` | Models, date conversion, CCFDDL parsing and merging, reminder planning |
| `Sources/ConfDDL` | AppKit lifecycle, SwiftUI panels, persistence and system integrations |
| `Tests/DeadlineCoreTests` | Executable core check runner, including CCFDDL fixtures |
| `scripts` | Packaging and native app icon generation |
| `Vendor/Yams` | Unmodified Yams 6.2.2 source; preserve its licenses |
| `docs` | User guide, screenshots, and release preparation |

For UI previews with isolated demo data:

```sh
swift build
.build/debug/ConfDDL --render-previews "$PWD/dist/screenshots"
```

You may append `--ccf-file /path/to/allconf.yml` to render the catalog and sourced editor too. Preview rendering uses temporary storage and does not edit your real tracked conferences.

## Submit a pull request

1. Discuss substantial changes in an issue before implementation.
2. Keep the change focused and preserve the existing JSON archive format.
3. Run checks relevant to the change. Include a regression case for date parsing, identity matching, or persistence fixes; screenshots are useful for UI changes.
4. Explain the user-visible result and how you verified it. Update both READMEs when installation or supported features change.

Contributions are provided under the project's MIT license. Preserve notices for third-party code and data.

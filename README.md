# MD阅读器

MD阅读器 is a local-first iPhone and iPad reader/editor for Markdown, HTML, and plain text documents.

The app is designed for developers who need to quickly open README, CHANGELOG, Markdown notes, simple HTML pages, and TXT files from the iOS Files app. It works without accounts, cloud sync, analytics, advertising SDKs, or a backend service.

## Features

- Open `.md`, `.markdown`, `.html`, `.htm`, and `.txt` files from Files.
- Create local Markdown, HTML, and plain text documents.
- Edit source text with autosave.
- Preview Markdown with headings, tables, code blocks, task lists, links, search, and a table of contents.
- Preview HTML and plain text locally.
- Confirm external links before opening them in the system browser.
- Export rendered documents as HTML or PDF.
- Use iPhone single-pane mode or iPad split/fullscreen reading and editing layouts.

## Privacy

MD阅读器 keeps document contents on device unless the user explicitly exports or shares through iOS system features. Settings and recent document references are stored locally using `UserDefaults`.

See [docs/privacy-policy.md](docs/privacy-policy.md).

## App Store Preparation

Static release checks:

```bash
bash scripts/validate_app_store_ready.sh
```

Build checks used during development:

```bash
xcodebuild build-for-testing -project mdreader.xcodeproj -scheme mdreader -configuration Debug -sdk iphonesimulator -derivedDataPath ./DerivedData CODE_SIGNING_ALLOWED=NO
xcodebuild build -project mdreader.xcodeproj -scheme mdreader -configuration Release -sdk iphoneos -derivedDataPath ./DerivedData CODE_SIGNING_ALLOWED=NO
```

Simulator XCTest should be run through GitHub Actions or a local Xcode installation with a working CoreSimulator runtime.

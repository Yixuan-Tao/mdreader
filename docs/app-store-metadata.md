# MD阅读器 App Store Metadata Draft

## App Information

- Name: MD阅读器
- Subtitle: 本地开发者 Markdown 编辑器
- Category: Productivity
- Price: Free
- Bundle ID: com.tommy.mdreader

## Keywords

Markdown,README,HTML,TXT,开发者,编辑器,本地文档,PDF导出

## Description

MD阅读器 is a local-first Markdown, HTML, and plain text reader and editor for developers on iPhone and iPad.

Open README, CHANGELOG, Markdown notes, HTML pages, and plain text files from Files. Edit source text, use GitHub-style Markdown preview, browse document headings, find text, create new documents, and export previews as PDF or HTML.

The app works locally on your device. It has no account system, no cloud sync, no analytics SDK, no advertising SDK, and no backend service.

## Review Notes

MD阅读器 is a local developer document reader and editor. It has no account system, no backend service, no analytics SDK, no advertising SDK, and no in-app purchases.

Reviewers can test by opening `.md`, `.markdown`, `.html`, `.htm`, or `.txt` files from Files, or by using New Document to create Markdown, HTML, or Text documents inside the app. Markdown preview supports headings, tables, code blocks, task lists, local search, and a table of contents. External links in previews show a confirmation alert before opening in Safari.

## Screenshot Checklist

- Home screen with Open and New Document
- Markdown preview with table of contents
- Source editor
- Find in document
- HTML or TXT preview
- Settings
- Export/share sheet

## Local Release Checks

Run this before preparing screenshots, TestFlight, or App Store upload:

```bash
bash scripts/validate_app_store_ready.sh
```

This checks the static App Store requirements that do not require a working Simulator runtime: bundle IDs, app name, document handler rank, privacy manifest, app icon dimensions, version/build numbers, and iPhone+iPad target settings.

## GitHub CI

The repository includes `.github/workflows/ios-ci.yml` for pull requests and pushes to `main`.

The CI gate runs:

- App Store static readiness checks
- Debug iOS Simulator build
- iOS Simulator test bundle build
- XCTest execution on the first available iPhone Simulator
- Release iPhone/iPad build with code signing disabled

The workflow does not upload to App Store Connect and does not store signing certificates. TestFlight and App Store upload should still be done from Xcode Organizer with the paid Apple Developer Team selected.

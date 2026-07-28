# MD阅读器 Support

MD阅读器 is a local Markdown, HTML, and TXT reader/editor for iPhone and iPad.

## Common Questions

### The app installed from Xcode no longer opens

If the app was installed with a free Apple ID, the developer certificate can expire. Reinstall the app from Xcode, then trust the Developer App certificate on the iPhone if prompted:

`Settings > General > VPN & Device Management`

Also confirm Developer Mode is enabled on the device.

### Does MD阅读器 upload my documents?

No. Documents are opened, edited, previewed, and exported locally. The app has no account system, analytics SDK, advertising SDK, cloud sync, or backend service.

### Why do external links ask for confirmation?

Preview links that leave the document are confirmed before opening in the system browser. This keeps document reading local by default and prevents a preview tap from silently navigating away.

### Which file types are supported?

- Markdown: `.md`, `.markdown`
- HTML: `.html`, `.htm`
- Plain text: `.txt`, `.text`

## Contact

For support, use the GitHub repository issue tracker or the support URL listed on the App Store product page.

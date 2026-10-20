# Job desk downloads

The built Job desk app for macOS, one release per version. The code lives in
a private repository; this one only holds what you install.

## Install

Open Terminal, paste this line and press Return:

```bash
curl -fsSL https://raw.githubusercontent.com/Upsstyle/jobdesk-releases/main/install.sh | bash
```

It installs the latest release into Applications, Node.js (for the PDFs)
and Claude Code, then opens Job desk. You need a Mac and a Claude Pro or
Max subscription.

Or download the zip for your Mac from the latest release on the right
(`Job-desk-mac-arm64.zip` for Apple silicon, `Job-desk-mac-x64.zip` for
Intel), unzip it and drag Job desk to Applications.

## Updates

Job desk checks this page at launch and every six hours. When a newer
version is here, a banner inside the app offers "Update now": it downloads
the zip, checks it against `SHA256SUMS.txt`, swaps itself and reopens.
Nothing in your notes is touched.

## What is in a release

- `Job-desk-mac-arm64.zip` and `Job-desk-mac-x64.zip`: the app, signed ad hoc.
- `SHA256SUMS.txt`: checksums the app verifies before installing.
- The notes: what changed in that version.

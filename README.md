# IMGUIDELTA

A file system browser for iOS with sandbox escape capabilities, built using Theos.

## Features

- Browse file system across sandboxed containers
- Access app data containers, shared app groups, and system directories
- Built on sandbox escape techniques for iOS 15+

## Requirements

- macOS with Xcode Command Line Tools
- Theos framework: `export THEOS="$HOME/theos"`
- iOS SDK 15.0+

## Build

```sh
export THEOS="$HOME/theos"
make clean
make package FINALPACKAGE=1
```

This generates an unsigned `.ipa` in the `packages/` directory.

## Signing & Installation

To sign the IPA with your Apple Developer account:

```sh
# Using Xcode's codesign
codesign -s - --force --deep IMGUIDELTA.ipa
```

Or use a tool like Sideloadly/AltStore to install on your device.

## License

MIT

## Disclaimer

Use this tool only on devices you own or have explicit permission to test.

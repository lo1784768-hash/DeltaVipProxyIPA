# IMGUIDELTA - iOS File Manager (Xcode Version)

A file system browser for iOS with sandbox escape capabilities, built using **Xcode + XcodeGen**.

## Features

- Browse file system across sandboxed containers
- Access app data containers, shared app groups, and system directories
- Built on sandbox escape techniques for iOS 15+
- Modern Xcode build system

## Requirements

- macOS 12+ with Xcode
- iOS SDK 15.0+
- XcodeGen (optional - can generate Xcode project)

## Build

### Using XcodeGen (Recommended)

```sh
# Install XcodeGen if not present
brew install xcodegen

# Generate Xcode project
xcodegen generate

# Build app
xcodebuild -scheme IMGUIDELTA -configuration Release build
```

### Using Xcode GUI

```sh
# Generate project
xcodegen generate

# Open in Xcode
open IMGUIDELTA.xcodeproj

# Build: Cmd+B
```

## Output

Built app will be in:
```
build/Release-iphoneos/IMGUIDELTA.app
```

## Packaging to IPA

```sh
# Create IPA from built app
mkdir -p Payload
cp -r build/Release-iphoneos/IMGUIDELTA.app Payload/
zip -r IMGUIDELTA-unsigned.ipa Payload/
```

## Signing & Installation

Use `esign` to sign the IPA:

```sh
esign -s <certificate.p12>:<password> \
       -p <provisioning.mobileprovision> \
       -o IMGUIDELTA-signed.ipa \
       IMGUIDELTA-unsigned.ipa
```

Then install via:
- Sideloadly
- AltStore
- TrollStore (jailbroken devices)

## Project Structure

```
IMGUIDELTA/
├── project.yml              # XcodeGen config
├── Sources/                 # Objective-C app source
│   ├── main.m
│   ├── AppDelegate.{h,m}
│   └── FileManagerViewController.{h,m}
│
├── IMGUIDELTA/              # App resources
│   └── IMGUIDELTA.entitlements
│
├── kexploit/                # Kernel exploit code (from FilzaSlop)
├── kpf/                     # Kernel patchfinder
├── XPF/                     # XPF kernel framework
├── utils/                   # Utility functions
└── compat/                  # Compatibility headers
```

## Customization

### Change App Appearance

Edit `Sources/FileManagerViewController.m` to modify UI.

### Modify Entitlements

Edit `IMGUIDELTA/IMGUIDELTA.entitlements` to change sandbox permissions.

### Update Bundle ID

Edit `project.yml`:
```yaml
options:
  bundleIdPrefix: your.custom.id
```

Then regenerate:
```sh
xcodegen generate
```

## Troubleshooting

### XcodeGen not found

```sh
brew install xcodegen
```

### Project generation fails

```sh
xcodegen generate --verbose
```

### Build fails with missing frameworks

Check `project.yml` dependencies section matches your Xcode version.

## GitHub Actions Build

Automatic builds triggered on push to `main` branch. See `.github/workflows/` for CI/CD config.

## License

MIT

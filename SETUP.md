# IMGUIDELTA Setup & Build Guide

## Overview

IMGUIDELTA is an iOS file manager app built with:
- **Objective-C** (UIKit)
- **Theos** build system
- **Sandbox escape** mechanisms (from FilzaSlop exploit chain)
- **GitHub Actions** for automated CI/CD

## Prerequisites

### For Local Build (macOS)
- macOS 12+
- Xcode Command Line Tools: `xcode-select --install`
- Homebrew: https://brew.sh
- Git

### For GitHub Actions Build
- Just push to your GitHub repo — everything runs on GitHub's macOS runner

## Quick Start

### 1. Clone This Repository

```bash
git clone https://github.com/lo1784768-hash/IMGUIDELTA.git
cd IMGUIDELTA
```

### 2. Setup Theos (Local Development)

```bash
chmod +x scripts/setup_theos.sh
scripts/setup_theos.sh
```

This will:
- Install Theos framework
- Install `ldid` (code signing tool)
- Bootstrap dependencies

### 3. Build the App

#### Option A: Automated Script (Recommended)

```bash
export THEOS=$HOME/theos
chmod +x scripts/build_local.sh
scripts/build_local.sh
```

This will:
- Download exploit code from FilzaSlop
- Compile with Theos
- Generate unsigned IPA in `packages/` directory

#### Option B: Manual Build

```bash
export THEOS=$HOME/theos
make clean
make package FINALPACKAGE=1
```

## Project Structure

```
IMGUIDELTA/
├── main.m                          # App entry point
├── AppDelegate.{h,m}               # Application delegate
├── FileManagerViewController.{h,m} # Main UI controller
├── Makefile                        # Theos build config
├── control                         # Package metadata
├── debug.entitlements              # Sandbox entitlements
├── README.md                       # Features & overview
│
├── kexploit/                       # Kernel exploit code (from FilzaSlop)
│   ├── kexploit_opa334.m          # Main exploit
│   ├── krw.m                      # Kernel read/write
│   ├── kutils.m                   # Kernel utilities
│   ├── offsets.m                  # Kernel offsets
│   └── vnode.m                    # VNode handling
│
├── kpf/                            # Kernel patchfinder
│   └── patchfinder.m
│
├── XPF/                            # XPF kernel framework (from FilzaSlop)
│   ├── src/                        # Source code
│   └── external/ChOma/             # ChOma MachO tools
│
├── utils/                          # Utility functions
│   ├── file.c
│   ├── hexdump.c
│   └── process.c
│
├── compat/sys/                     # Compatibility headers
│
├── .github/workflows/
│   └── build.yml                   # GitHub Actions workflow
│
└── scripts/
    ├── setup_theos.sh             # Theos setup script
    └── build_local.sh             # Local build helper
```

## GitHub Actions Workflow

### What It Does

Every time you push to `main` or `develop` branch:
1. ✓ Checkouts your repo
2. ✓ Installs Theos on macOS runner
3. ✓ Downloads exploit code from FilzaSlop
4. ✓ Builds app with Theos
5. ✓ Generates unsigned IPA
6. ✓ Uploads artifact (30-day retention)
7. ✓ Creates GitHub Release (on main branch only)

### Access Built IPA

**On GitHub:**
- Go to "Actions" tab → latest build → "IMGUIDELTA-IPA" artifact
- Or check "Releases" for main branch builds

**Download Unsigned IPA:**
```bash
# From your local machine
gh release download <tag> -p "*.ipa"
```

## Signing & Installation

### Option 1: Sideloadly (Easiest for Most Users)

1. Download [Sideloadly](https://sideloadly.io)
2. Get the unsigned IPA from GitHub Release
3. Open Sideloadly → select IPA → enter Apple ID → click "Start"
4. Sideloadly auto-signs with your free Apple Developer account
5. IPA installs on your device

**Note:** Free Apple ID can install 10 apps every 7 days.

### Option 2: AltStore

1. Install [AltStore](https://altstore.io)
2. Download unsigned IPA from GitHub
3. Mail IPA to yourself or use AltStore's network install
4. AltStore handles signing & installation

### Option 3: TrollStore (Jailbroken Devices Only)

1. Install TrollStore on jailbroken device
2. Download unsigned IPA
3. Open with TrollStore → Install

### Option 4: Manual Signing (Advanced)

If you have Apple Developer certs locally:

```bash
# Resign IPA with your certificate
codesign -s <CERT_IDENTITY> --force --deep IMGUIDELTA-v1.0.0-unsigned.ipa

# Then install with Sideloadly or similar
```

## GitHub Actions + Apple Developer Signing (Optional)

To auto-sign IPAs in CI:

1. Export your Apple Developer certificate as `.p12`:
   ```bash
   # In Keychain Access:
   # Right-click cert → Export → Save as .p12 (with password)
   ```

2. Create GitHub Secrets:
   - `APPLE_DEV_CERT`: Base64-encoded .p12 file
   - `APPLE_DEV_CERT_PASSWORD`: Your certificate password
   - `APPLE_TEAM_ID`: Your Apple Developer Team ID

3. Update `.github/workflows/build.yml` to include signing step (see advanced section below)

## Customization

### Change App Appearance

Edit [FileManagerViewController.m](FileManagerViewController.m):
- Modify UI colors, layout
- Add more features (file preview, search, etc.)

### Sandbox Escape Features

FilzaSlop exploit code includes:
- **MobileHouseArrest** privilege: Access other app containers
- **Kernel RW**: Read/write kernel memory (iOS 15-27)
- **Patchfinder**: Locate kernel functions dynamically

Modify [sandbox_escape.m](sandbox_escape.m) (when downloaded) to customize behavior.

### Add New Frameworks

Edit `Makefile`:
```makefile
IMGUIDELTA_FRAMEWORKS = UIKit Foundation IOKit CoreFoundation ... YourFramework
```

## Troubleshooting

### Build Fails: "THEOS not found"
```bash
export THEOS=$HOME/theos
make clean
make package FINALPACKAGE=1
```

### Build Fails: "ldid not found"
```bash
brew install ldid
```

### GitHub Actions Build Fails

Check logs in Actions tab → failed workflow → "Build IMGUIDELTA" step.

Common issues:
- FilzaSlop files not downloading → check URLs in build.yml
- Makefile syntax errors → verify Theos installation

### IPA Installs But App Won't Run

Possible causes:
- **Not signed** → Use Sideloadly/AltStore to sign
- **iOS version mismatch** → Check deployment target (currently iOS 15.0)
- **Entitlements issue** → Verify debug.entitlements has required sandbox entitlements
- **Kernel exploit failed** → Might only work on certain iOS versions

## Next Steps

1. **Clone this repo** to your GitHub
2. **Setup Theos locally** (optional, for testing)
3. **Push a commit** → GitHub Actions builds automatically
4. **Download IPA** from Actions artifacts or Releases
5. **Install on device** using Sideloadly/AltStore
6. **Customize app** for your needs

## Additional Resources

- [Theos Wiki](https://theos.dev)
- [FilzaSlop (Reference)](https://github.com/0xjohnnydev/FilzaSlop)
- [Sideloadly Guide](https://sideloadly.io)
- [iOS Sandbox Escape (Academic)](https://en.wikipedia.org/wiki/Jailbreaking)

## Questions?

Feel free to open Issues on GitHub for build problems or feature requests.

---

**Happy building! 🎉**

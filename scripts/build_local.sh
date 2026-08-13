#!/bin/bash
# Local build script for IMGUIDELTA

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "📦 Building IMGUIDELTA..."
echo "Project directory: $PROJECT_DIR"

# Check THEOS
if [ -z "$THEOS" ]; then
    echo "❌ THEOS not set. Run: export THEOS=\$HOME/theos"
    exit 1
fi

# Download exploit code if missing
echo "📥 Checking exploit code..."
if [ ! -f "$PROJECT_DIR/sandbox_escape.m" ]; then
    echo "Downloading FilzaSlop exploit code..."
    cd "$PROJECT_DIR"

    # Create directories
    mkdir -p kexploit kpf XPF/src XPF/external/ChOma/src utils compat/sys

    # Download files
    for file in sandbox_escape.m sandbox_escape.h apfs_own.m apfs_own.h; do
        echo "  - $file"
        curl -sL "https://raw.githubusercontent.com/0xjohnnydev/FilzaSlop/main/$file" -o "$file"
    done

    for file in kexploit_opa334.m krw.m kutils.m offsets.m vnode.m; do
        echo "  - kexploit/$file"
        curl -sL "https://raw.githubusercontent.com/0xjohnnydev/FilzaSlop/main/kexploit/$file" -o "kexploit/$file"
    done

    echo "  - kpf/patchfinder.m"
    curl -sL "https://raw.githubusercontent.com/0xjohnnydev/FilzaSlop/main/kpf/patchfinder.m" -o "kpf/patchfinder.m"

    echo "✓ Exploit code ready"
fi

# Clean and build
cd "$PROJECT_DIR"
echo "🔨 Running make..."
make clean
make package FINALPACKAGE=1

# Show result
echo ""
IPA_FILE=$(find . -name "*.ipa" -type f | head -1)
if [ -n "$IPA_FILE" ]; then
    echo "✅ Build successful!"
    echo "📦 IPA: $IPA_FILE"
    ls -lh "$IPA_FILE"
else
    echo "❌ Build failed - no IPA found"
    exit 1
fi

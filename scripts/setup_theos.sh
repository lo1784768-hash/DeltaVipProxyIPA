#!/bin/bash
# Setup Theos development environment for IMGUIDELTA build

set -e

echo "🔧 Setting up Theos for IMGUIDELTA..."

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ This setup script requires macOS"
    exit 1
fi

# Setup Theos
if [ -z "$THEOS" ]; then
    THEOS_PATH="$HOME/theos"
    if [ ! -d "$THEOS_PATH" ]; then
        echo "📥 Installing Theos..."
        git clone --depth 1 https://github.com/theos/theos.git "$THEOS_PATH"
    fi
    export THEOS="$THEOS_PATH"
    echo "✓ Theos installed at: $THEOS"
else
    echo "✓ THEOS already set: $THEOS"
fi

# Install ldid (required for codesigning)
if ! command -v ldid &> /dev/null; then
    echo "📥 Installing ldid via Homebrew..."
    brew install ldid
else
    echo "✓ ldid already installed"
fi

# Bootstrap Theos
echo "🔨 Bootstrapping Theos..."
cd "$THEOS"
if [ -f "./bin/bootstrap.sh" ]; then
    ./bin/bootstrap.sh
else
    echo "⚠️  Bootstrap script not found, trying git submodule approach..."
    git submodule update --init --recursive || true
fi

echo ""
echo "✅ Setup complete!"
echo "Next steps:"
echo "  1. cd to IMGUIDELTA directory"
echo "  2. Run: export THEOS=$THEOS"
echo "  3. Run: make clean && make package FINALPACKAGE=1"

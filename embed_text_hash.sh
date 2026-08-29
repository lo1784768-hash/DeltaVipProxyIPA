#!/bin/bash
# embed_text_hash.sh — Chạy SAU khi Xcode link xong (Run Script Phase)
# Tính SHA256 của __TEXT,__text section → ghi vào SecurityGuard.m → compile lại
#
# Thêm vào Xcode: Build Phases → + → New Run Script Phase
# Shell: /bin/bash
# Script: "${SRCROOT}/embed_text_hash.sh"
# Đặt SAU "Compile Sources" và "Link Binary With Libraries"
# Check "Run script only when installing" nếu muốn chỉ chạy khi Archive

set -e

BINARY="${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}"
SRC="${SRCROOT}/Sources/SecurityGuard.m"

if [ ! -f "$BINARY" ]; then
    echo "embed_text_hash.sh: binary chưa có, skip"
    exit 0
fi

# Dùng otool để dump __text section bytes rồi tính SHA256
# otool -s __TEXT __text -X in ra hex bytes
TEXT_HEX=$(otool -s __TEXT __text -X "$BINARY" 2>/dev/null | awk '{for(i=2;i<=NF;i++) printf $i}')
if [ -z "$TEXT_HEX" ]; then
    echo "embed_text_hash.sh: không dump được __text, skip"
    exit 0
fi

# Tính SHA256 của hex string đó (đây là sha256 of the hex representation)
# Dùng python3 để tính sha256 thật từ binary bytes
SHA256=$(python3 - "$BINARY" <<'EOF'
import sys, subprocess, hashlib, struct

binary = sys.argv[1]

# Parse mach-o để lấy __TEXT,__text range
result = subprocess.run(['otool', '-l', binary], capture_output=True, text=True)
lines = result.stdout.splitlines()

in_text_sect = False
vm_addr = None
vm_size = None
file_off = None

i = 0
while i < len(lines):
    l = lines[i].strip()
    if 'Section' in l:
        # Check next lines for sectname __text, segname __TEXT
        peek = [lines[i+j].strip() if i+j < len(lines) else '' for j in range(1,8)]
        is_text = any('sectname __text' in p for p in peek)
        is_TEXT = any('segname __TEXT' in p for p in peek)
        if is_text and is_TEXT:
            for p in peek:
                if p.startswith('addr '):  vm_addr  = int(p.split()[1], 16)
                if p.startswith('size '):  vm_size  = int(p.split()[1], 16)
                if p.startswith('offset '): file_off = int(p.split()[1])
    i += 1

if file_off is None or vm_size is None:
    print("0")
    sys.exit(0)

with open(binary, 'rb') as f:
    f.seek(file_off)
    data = f.read(vm_size)

digest = hashlib.sha256(data).digest()
# Lấy 8 byte đầu, pack thành uint64 little-endian
val = struct.unpack('<Q', digest[:8])[0]
print(hex(val))
EOF
)

if [ "$SHA256" = "0" ] || [ -z "$SHA256" ]; then
    echo "embed_text_hash.sh: tính hash thất bại, skip"
    exit 0
fi

echo "embed_text_hash.sh: __text hash = $SHA256"

# Ghi vào SecurityGuard.m (thay dòng kSGTextHash)
# Backup trước
cp "$SRC" "${SRC}.bak"

# sed thay dòng có kSGTextHash = ...
# Dùng perl để an toàn hơn trên macOS
perl -i -pe "s/static const uint64_t kSGTextHash = 0x[0-9a-fA-F]+/static const uint64_t kSGTextHash = $SHA256/" "$SRC"
perl -i -pe "s/static const uint64_t kSGTextHash = 0;/static const uint64_t kSGTextHash = $SHA256;/" "$SRC"

echo "embed_text_hash.sh: đã ghi hash vào SecurityGuard.m, cần compile lại"

# Touch để Xcode biết file đã thay đổi và compile lại ở build tiếp theo
touch "$SRC"

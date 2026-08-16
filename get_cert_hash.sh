#!/bin/bash
# Lấy SHA-256 hash của server certificate để điền vào SecurityPinning.m
# Chạy: bash get_cert_hash.sh YOUR_DOMAIN
#
# Ví dụ: bash get_cert_hash.sh qlhosting.yourdomain.com

DOMAIN="${1:-YOUR_DOMAIN}"

echo "=== Lấy cert hash cho: $DOMAIN ==="
echo ""

HASH=$(openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" </dev/null 2>/dev/null \
    | openssl x509 -outform DER \
    | openssl dgst -sha256 -binary \
    | base64)

if [ -z "$HASH" ]; then
    echo "❌ Không kết nối được. Kiểm tra domain và port 443."
    exit 1
fi

echo "✅ Hash (điền vào kPinnedHashes trong SecurityPinning.m):"
echo ""
echo "    @\"$HASH\","
echo ""
echo "Lệnh check nhanh:"
echo "  echo '$HASH' | openssl base64 -d | xxd | head -2"

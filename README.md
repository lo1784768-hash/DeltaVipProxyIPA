# DELTA PROXY (IMGUIDELTA)

> **Fork / build on top of** [`darksword-kexploit-fun`](https://github.com/lo1784768-hash/darksword-kexploit-fun) bởi **seo** — kernel exploit OPA334/ICMPv6 cho iOS 17–26.

**Tác giả:** Trần Hữu Long

Ứng dụng iOS standalone (không cần jailbreak, không cần Substrate/Theos) cho phép quản lý file và áp dụng các bản vá game trực tiếp từ thiết bị, thông qua sandbox escape kernel-level.

---

## Nguồn gốc & Attribution

| Thành phần | Nguồn gốc | Tác giả |
|---|---|---|
| `kexploit/` — OPA334/ICMPv6 kernel exploit | [`darksword-kexploit-fun`](https://github.com/lo1784768-hash/darksword-kexploit-fun) | **seo** |
| `sandbox_escape.m` — kernel memory patching | [`18.3_sandbox/root.m`](https://github.com/CrazyMind90) | **CrazyMind90** |
| `XPF/` — kernel patchfinder | XPF framework | open-source |
| `XPF/external/ChOma/` — MachO/dyld utilities | [ChOma](https://github.com/opa334/ChOma) | **opa334** |
| `Sources/` — HUD, AutoPaste, VirtualFS, Key system | IMGUIDELTA | **Trần Hữu Long** |

Mọi thành phần bên ngoài đều là **open-source** và được tích hợp nguyên trạng hoặc có ghi chú rõ ràng tại đầu file.

---

## Ứng dụng làm gì (minh bạch)

### 1. Sandbox Escape — truy cập container của app khác

**iOS 17.0 → 26.0.x (Cơ chế B):**
```
kexploit_opa334()       ← OPA334/ICMPv6 kernel exploit → kernel R/W primitives
sandbox_escape()        ← patch proc → ucred → cr_label → sandbox ext_set
                           ghi "/" vào 16 hash slot → filesystem R+W toàn phần
```

**iOS 26.1+ (Cơ chế A):**
```
libsystem_containermanager.dylib
  container_copy_sandbox_token()
  container_object_sandbox_extension_activate()
  → MCM trực tiếp, không cần kernel exploit
```

### 2. Virtual FileSystem

Sau khi escape, build cây symlink tại `~/Documents/Device Storage/`:
```
[MHA-C2] App Data/
    com.dts.freefireth   → /var/mobile/Containers/Data/Application/{UUID}/
    com.dts.freefiremax  → /var/mobile/Containers/Data/Application/{UUID}/
[MHA-C7] App Groups/
[MHA-C10] Service Data/
...
```
Container path tìm bằng 3 lớp fallback: scan metadata plist → MCM C API → LSApplicationProxy.

### 3. DELTA PROXY HUD

Overlay HUD (3 tab) cho phép bật/tắt các bản vá:

| Tab | Màu | Chức năng |
|---|---|---|
| Proxy | Cyan | Body, Cổ V1/V2, Drag, Magic, Speed Hack, Fake Dame |
| Định Vị | Green | Định Vị Xanh/Đỏ/Hồng |
| Mod NV | Purple | Mod Skin (Maro, Alok V1-V8, Hayato, Dimitri) |

Mỗi bản vá:
- Download file từ server qua HTTPS (HMAC-SHA256 signed, SSL pinned)
- Tìm file đệ quy trong container game theo tên
- Ghi đè tại chỗ (không cần restart thiết bị, chỉ cần restart game)

### 4. Key System

- License key kiểm tra qua HTTPS endpoint
- UDID = `identifierForVendor` (bind key vào thiết bị)
- Key hết hạn → tự cập nhật status `expired`

---

## iOS Support

| iOS | Cơ chế |
|---|---|
| < 17.0 | ❌ Không hỗ trợ |
| 17.0 – 26.0.x | ✅ kexploit_opa334 + sandbox_escape |
| 26.1+ | ✅ MCM direct (không exploit) |

---

## Build

```sh
# Yêu cầu: macOS + Xcode, XcodeGen
brew install xcodegen

# Tạo project
xcodegen generate

# Build
xcodebuild -scheme IMGUIDELTA -configuration Release \
  -destination 'generic/platform=iOS' build
```

Đóng gói IPA:
```sh
mkdir -p Payload
cp -r build/Release-iphoneos/IMGUIDELTA.app Payload/
zip -r IMGUIDELTA-unsigned.ipa Payload/
```

Ký và cài:
```sh
# esign, Sideloadly, AltStore, TrollStore
esign -s cert.p12:password -p prov.mobileprovision \
  -o IMGUIDELTA-signed.ipa IMGUIDELTA-unsigned.ipa
```

---

## Cấu trúc Project

```
IMGUIDELTA/
├── Sources/                    # Objective-C app
│   ├── AppDelegate.{h,m}
│   ├── HUDControlViewController.{h,m}  # HUD 3 tab
│   ├── AutoPasteManager.{h,m}          # Download & ghi file mod
│   ├── SandboxEscapeManager.{h,m}      # Chọn cơ chế A/B
│   ├── sandbox_escape.{h,m}            # Kernel memory patching
│   ├── MCMFilzaIntegration.{h,m}       # MCM + sandbox token
│   ├── VirtualFileSystemBuilder.{h,m}  # Symlink tree
│   ├── KeyManager.{h,m}                # License key
│   ├── SecurityPinning.{h,m}           # SSL pinning + HMAC
│   └── ...
├── kexploit/                   # OPA334 kernel exploit (darksword-kexploit-fun/seo)
├── XPF/                        # Kernel patchfinder
│   └── external/ChOma/         # MachO utilities (opa334)
├── kpf/                        # Kernel patchfinder helpers
├── utils/                      # C utilities
├── compat/                     # Compatibility headers
└── project.yml                 # XcodeGen config
```

---

## License

Code gốc của project (`Sources/`) — **MIT** © Trần Hữu Long.  
`kexploit/` — giữ nguyên license của `darksword-kexploit-fun`.  
`XPF/external/ChOma/` — giữ nguyên license của ChOma (MIT).

Xem chi tiết tại từng thư mục.

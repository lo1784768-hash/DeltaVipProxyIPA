# IMGUIDELTA - iOS File Manager with Sandbox Escape
# Build: make clean && make package FINALPACKAGE=1

TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = IMGUIDELTA

IMGUIDELTA_FILES = main.m AppDelegate.m FileManagerViewController.m
IMGUIDELTA_FILES += sandbox_escape.m apfs_own.m
IMGUIDELTA_FILES += kexploit/kexploit_opa334.m kexploit/krw.m kexploit/kutils.m kexploit/offsets.m kexploit/vnode.m
IMGUIDELTA_FILES += utils/file.c utils/hexdump.c utils/process.c
IMGUIDELTA_FILES += kpf/patchfinder.m
IMGUIDELTA_FILES += XPF/src/xpf.c XPF/src/common.c XPF/src/decompress.c XPF/src/bad_recovery.c XPF/src/non_ppl.c XPF/src/ppl.c
IMGUIDELTA_FILES += XPF/external/ChOma/src/arm64.c XPF/external/ChOma/src/Base64.c XPF/external/ChOma/src/BufferedStream.c XPF/external/ChOma/src/CodeDirectory.c XPF/external/ChOma/src/CSBlob.c XPF/external/ChOma/src/DER.c XPF/external/ChOma/src/DyldSharedCache.c XPF/external/ChOma/src/Entitlements.c XPF/external/ChOma/src/Fat.c XPF/external/ChOma/src/FileStream.c XPF/external/ChOma/src/Host.c XPF/external/ChOma/src/MachO.c XPF/external/ChOma/src/MachOLoadCommand.c XPF/external/ChOma/src/MemoryStream.c XPF/external/ChOma/src/PatchFinder.c XPF/external/ChOma/src/PatchFinder_arm64.c XPF/external/ChOma/src/Util.c

# Compiler flags
IMGUIDELTA_CFLAGS = -I$(PWD)/compat -I$(PWD) -I$(PWD)/XPF/src -I$(PWD)/XPF/external/ChOma/include \
    -fobjc-arc \
    -Wno-unused-function -Wno-unused-variable -Wno-unused-but-set-variable \
    -Wno-incompatible-pointer-types -Wno-incompatible-pointer-types-discards-qualifiers \
    -Wno-deprecated-declarations -Wno-nonportable-include-path -Wno-format
IMGUIDELTA_CFLAGS += -Wno-arc-performSelector-leaks

IMGUIDELTA_CCFLAGS = $(IMGUIDELTA_CFLAGS)
IMGUIDELTA_OBJCFLAGS = $(IMGUIDELTA_CFLAGS)
IMGUIDELTA_OBJCCFLAGS = $(IMGUIDELTA_CFLAGS)

IMGUIDELTA_FRAMEWORKS = UIKit Foundation IOKit CoreFoundation
IMGUIDELTA_PRIVATE_FRAMEWORKS = IOSurface
IMGUIDELTA_LIBRARIES = z sandbox

IMGUIDELTA_CODESIGN_FLAGS = -Sdebug.entitlements

include $(THEOS_MAKE_PATH)/application.mk

swiftfiles := $(patsubst %.swift,bin/%,$(wildcard *.swift))
all: $(swiftfiles)

MONITOR_COMPILER_FLAGS = \
    -F$$PWD/Headers \
    -F/System/Library/PrivateFrameworks \
    -framework DisplayServices \
    -framework CoreDisplay \
    -framework OSD \
    -framework MonitorPanel \
    -import-objc-header Headers/Bridging-Header.h


bin/SwapMonitors: SWIFTC_FLAGS=$(MONITOR_COMPILER_FLAGS)
bin/ToggleHDR: SWIFTC_FLAGS=$(MONITOR_COMPILER_FLAGS)
bin/%: %.swift
	swiftc $(SWIFTC_FLAGS) -target arm64-apple-macos10.15.4 $*.swift -o bin/$*-arm64
	swiftc $(SWIFTC_FLAGS) -target x86_64-apple-macos10.15.4 $*.swift -o bin/$*-x86
	lipo -create -output bin/$* bin/$*-*

watch:
	rg -t swift --files | entr make -j$$(nproc)
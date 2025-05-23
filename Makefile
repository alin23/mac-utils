swiftfiles := $(patsubst %.swift,bin/%,$(wildcard *.swift))
all: $(swiftfiles)

MONITOR_COMPILER_FLAGS = \
    -F$$PWD/Headers \
    -F/System/Library/PrivateFrameworks \
    -framework DisplayServices \
    -framework CoreDisplay \
    -framework OSD \
    -framework MonitorPanel \
    -framework SkyLight \
    -import-objc-header Headers/Bridging-Header.h \
    lib/Extensions.swift

bin/SwapMonitors: SWIFTC_FLAGS=$(MONITOR_COMPILER_FLAGS)
bin/ToggleHDR: SWIFTC_FLAGS=$(MONITOR_COMPILER_FLAGS)
bin/RotateDisplay: SWIFTC_FLAGS=$(MONITOR_COMPILER_FLAGS)
bin/HorizontalMonitorLayout: SWIFTC_FLAGS=$(MONITOR_COMPILER_FLAGS)
bin/VerticalMonitorLayout: SWIFTC_FLAGS=$(MONITOR_COMPILER_FLAGS)
bin/MirrorMacBookToMonitor: SWIFTC_FLAGS=$(MONITOR_COMPILER_FLAGS)
bin/ReferencePreset: SWIFTC_FLAGS=$(MONITOR_COMPILER_FLAGS)
bin/ApplyColorProfile: SWIFTC_FLAGS=$(MONITOR_COMPILER_FLAGS)
bin/SetNativeBrightness: SWIFTC_FLAGS=-F$$PWD/Headers -F/System/Library/PrivateFrameworks -framework DisplayServices -import-objc-header Headers/Bridging-Header.h
bin/SetKeyboardBacklight: SWIFTC_FLAGS=-F$$PWD/Headers -F/System/Library/PrivateFrameworks -framework CoreBrightness -import-objc-header Headers/Bridging-Header.h
bin/Screens: SWIFTC_FLAGS=$(MONITOR_COMPILER_FLAGS)
bin/IsNowPlaying: IsNowPlaying.swift
	swiftc -target arm64-apple-macos10.15.4 IsNowPlaying.swift -o bin/com.apple.controlcenter.mac-utils.IsNowPlaying-arm64 && \
	swiftc -target x86_64-apple-macos10.15.4 IsNowPlaying.swift -o bin/com.apple.controlcenter.mac-utils.IsNowPlaying-x86 && \
	lipo -create -output bin/com.apple.controlcenter.mac-utils.IsNowPlaying bin/com.apple.controlcenter.mac-utils.IsNowPlaying-* && \
	cp -f bin/com.apple.controlcenter.mac-utils.IsNowPlaying bin/IsNowPlaying && \
	rm -f bin/IsNowPlaying-* bin/com.apple.controlcenter.mac-utils.IsNowPlaying-* && \
    test -z "$$CODESIGN_CERT" || /usr/bin/codesign -fs "$$CODESIGN_CERT" --options runtime --timestamp bin/com.apple.controlcenter.mac-utils.IsNowPlaying bin/IsNowPlaying
bin/%: bin/%-arm64 bin/%-x86
	lipo -create -output bin/$* bin/$*-* && \
    test -z "$$CODESIGN_CERT" || /usr/bin/codesign -fs "$$CODESIGN_CERT" --options runtime --timestamp bin/$*
bin/%-arm64: build/%-arm64/main.swift
	mkdir -p ./bin
	swiftc $(SWIFTC_FLAGS) -target arm64-apple-macos10.15.4 ./build/$*-arm64/main.swift -o bin/$*-arm64
bin/%-x86: build/%-x86/main.swift
	mkdir -p ./bin
	swiftc $(SWIFTC_FLAGS) -target x86_64-apple-macos10.15.4 ./build/$*-x86/main.swift -o bin/$*-x86
build/%-arm64/main.swift: %.swift
	mkdir -p ./build/$*-arm64 || true
	cp -f $*.swift ./build/$*-arm64/main.swift
build/%-x86/main.swift: %.swift
	mkdir -p ./build/$*-x86 || true
	cp -f $*.swift ./build/$*-x86/main.swift
notarize:
	@rm bin/*-arm64 bin/*-x86 || true
	zip /tmp/bins.zip bin/*
	xcrun notarytool submit --progress --wait --keychain-profile Alin /tmp/bins.zip

watch: BIN=
watch:
	rg -u -t swift -t h --files | entr -rs 'echo \n--------\n; make -j$$(nproc) && ./bin/$(BIN)'

clean:
	rm -rf bin
	rm -rf build
	rm -f /tmp/bins.zip
	rm -f bin/*-arm64
	rm -f bin/*-x86

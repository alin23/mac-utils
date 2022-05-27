all: bin/SwapMonitors bin/VerticalMonitorLayout bin/HorizontalMonitorLayout bin/runbg bin/runfg bin/MirrorMacBookToMonitor bin/IsNowPlaying

bin/%: %.swift
	swiftc $*.swift -o bin/$*-arm64
	arch -x86_64 swiftc $*.swift -o bin/$*-x86
	lipo -create -output bin/$* bin/$*-*

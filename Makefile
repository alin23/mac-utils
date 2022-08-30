swiftfiles := $(patsubst %.swift,bin/%,$(wildcard *.swift))
all: $(swiftfiles)

bin/%: %.swift
	swiftc -target arm64-apple-macos10.15.4 $*.swift -o bin/$*-arm64
	swiftc -target x86_64-apple-macos10.15.4 $*.swift -o bin/$*-x86
	lipo -create -output bin/$* bin/$*-*

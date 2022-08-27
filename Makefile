swiftfiles := $(patsubst %.swift,bin/%,$(wildcard *.swift))
all: $(swiftfiles)

bin/%: %.swift
	swiftc $*.swift -o bin/$*-arm64
	arch -x86_64 swiftc $*.swift -o bin/$*-x86
	lipo -create -output bin/$* bin/$*-*

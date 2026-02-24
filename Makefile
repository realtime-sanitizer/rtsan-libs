LLVM_VERSION := 20.1.1
LLVM_PROJECT_DIR := llvm-project
LLVM_PROJECT_TAR := llvm-project-$(LLVM_VERSION).src.tar.xz
LLVM_PROJECT_URL := https://github.com/llvm/llvm-project/releases/download/llvmorg-$(LLVM_VERSION)/$(LLVM_PROJECT_TAR)

BUILD_DIR := $(LLVM_PROJECT_DIR)/build
TARGET_OS := $(shell uname | tr '[:upper:]' '[:lower:]')
TARGET_ARCH := $(shell uname -m)
NUM_CORES := $(shell nproc 2>/dev/null || sysctl -n hw.ncpu)

RTSAN_HEADER_URL := https://raw.githubusercontent.com/realtime-sanitizer/rtsan/main/include/rtsan_standalone/rtsan_standalone.h
ARTIFACTBUNDLE_DIR := rtsan.artifactbundle
ARTIFACTBUNDLE_VERSION ?= $(LLVM_VERSION)

.PHONY: all download extract init configure build clean test build_xcframework build_artifactbundle

all: init configure build

download:
	if [ ! -f "$(LLVM_PROJECT_TAR)" ]; then \
		curl -LO $(LLVM_PROJECT_URL); \
	fi

extract: download
	if [ ! -d "$(LLVM_PROJECT_DIR)/.extracted" ]; then \
		mkdir -p $(LLVM_PROJECT_DIR) && \
		tar -xf $(LLVM_PROJECT_TAR) --strip-components=1 -C $(LLVM_PROJECT_DIR); \
		touch $(LLVM_PROJECT_DIR)/.extracted; \
	fi

init: extract
	@echo "LLVM project extracted to $(LLVM_PROJECT_DIR)"

configure:
	@mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && cmake -G "Unix Makefiles" \
		-DBUILD_SHARED_LIBS=OFF \
		-DCMAKE_BUILD_TYPE=Release \
		-DCOMPILER_RT_ENABLE_MACCATALYST=OFF \
		-DCOMPILER_RT_BUILD_SANITIZERS=ON \
		../compiler-rt

build:
	$(MAKE) -C $(BUILD_DIR) -j$(NUM_CORES) rtsan

build_xcframework:
	mkdir $(BUILD_DIR)/rtsan_headers
	# xcodebuild -xcframework -headers requires a directory
	# To use only a single header, copy it to a separate location
	curl -fL -o $(BUILD_DIR)/rtsan_headers/rtsan_standalone.h $(RTSAN_HEADER_URL)
	printf '%s\n' \
		'module rtsan {' \
		'    header "rtsan_standalone.h"' \
		'    export *' \
		'}' > $(BUILD_DIR)/rtsan_headers/module.modulemap
	xcrun xcodebuild \
		-create-xcframework \
		-library $(BUILD_DIR)/lib/darwin/libclang_rt.rtsan_osx_dynamic.dylib \
		-headers $(BUILD_DIR)/rtsan_headers \
		-library $(BUILD_DIR)/lib/darwin/libclang_rt.rtsan_ios_dynamic.dylib \
		-headers $(BUILD_DIR)/rtsan_headers \
		-library $(BUILD_DIR)/lib/darwin/libclang_rt.rtsan_iossim_dynamic.dylib \
		-headers $(BUILD_DIR)/rtsan_headers \
		-output $(BUILD_DIR)/lib/darwin/rtsan.xcframework
	cd $(BUILD_DIR)/lib/darwin/ && zip -r rtsan.xcframework.zip rtsan.xcframework

build_artifactbundle:
	rm -rf $(ARTIFACTBUNDLE_DIR)
	mkdir -p $(ARTIFACTBUNDLE_DIR)/x86_64-unknown-linux-gnu \
		$(ARTIFACTBUNDLE_DIR)/aarch64-unknown-linux-gnu \
		$(ARTIFACTBUNDLE_DIR)/headers
	cp $(X86_64_LIB) $(ARTIFACTBUNDLE_DIR)/x86_64-unknown-linux-gnu/librtsan.a
	cp $(AARCH64_LIB) $(ARTIFACTBUNDLE_DIR)/aarch64-unknown-linux-gnu/librtsan.a
	curl -fL -o $(ARTIFACTBUNDLE_DIR)/headers/rtsan_standalone.h $(RTSAN_HEADER_URL)
	printf '%s\n' \
		'module rtsan {' \
		'    header "rtsan_standalone.h"' \
		'    link "rtsan"' \
		'    export *' \
		'}' > $(ARTIFACTBUNDLE_DIR)/headers/module.modulemap
	printf '%s\n' \
		'{' \
		'    "schemaVersion": "1.0",' \
		'    "artifacts": {' \
		'        "rtsan-linux": {' \
		'            "version": "$(ARTIFACTBUNDLE_VERSION)",' \
		'            "type": "staticLibrary",' \
		'            "variants": [' \
		'                {' \
		'                    "path": "x86_64-unknown-linux-gnu/librtsan.a",' \
		'                    "supportedTriples": ["x86_64-unknown-linux-gnu"],' \
		'                    "staticLibraryMetadata": {' \
		'                        "headerPaths": ["headers"],' \
		'                        "moduleMapPath": "headers/module.modulemap"' \
		'                    }' \
		'                },' \
		'                {' \
		'                    "path": "aarch64-unknown-linux-gnu/librtsan.a",' \
		'                    "supportedTriples": ["aarch64-unknown-linux-gnu"],' \
		'                    "staticLibraryMetadata": {' \
		'                        "headerPaths": ["headers"],' \
		'                        "moduleMapPath": "headers/module.modulemap"' \
		'                    }' \
		'                }' \
		'            ]' \
		'        }' \
		'    }' \
		'}' > $(ARTIFACTBUNDLE_DIR)/info.json
	zip -r rtsan.artifactbundle.zip $(ARTIFACTBUNDLE_DIR)

clean:
	rm -rf $(BUILD_DIR)
	rm -rf $(LLVM_PROJECT_DIR)
	rm llvm-project-$(LLVM_VERSION).src.tar.xz
	rm -rf $(ARTIFACTBUNDLE_DIR) rtsan.artifactbundle.zip

test:
	@echo "Running tests for $(TARGET_OS)..."
ifeq ($(TARGET_OS),linux)
	LIB=$(BUILD_DIR)/lib/linux/libclang_rt.rtsan-$(TARGET_ARCH).a bash ./test_common.sh
else
	LIB=$(BUILD_DIR)/lib/darwin/libclang_rt.rtsan_osx_dynamic.dylib bash ./test_common.sh
	LIB=$(BUILD_DIR)/lib/darwin/libclang_rt.rtsan_osx_dynamic.dylib bash ./test_darwin.sh
endif

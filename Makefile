LLVM_VERSION := 20.1.1
LLVM_PROJECT_DIR := llvm-project
LLVM_PROJECT_TAR := llvm-project-$(LLVM_VERSION).src.tar.xz
LLVM_PROJECT_URL := https://github.com/llvm/llvm-project/releases/download/llvmorg-$(LLVM_VERSION)/$(LLVM_PROJECT_TAR)

BUILD_DIR := $(LLVM_PROJECT_DIR)/build
TARGET_OS := $(shell uname | tr '[:upper:]' '[:lower:]')
TARGET_ARCH := $(shell uname -m)
NUM_CORES := $(shell nproc 2>/dev/null || sysctl -n hw.ncpu)

.PHONY: all download extract init configure build clean show-lib

all: init configure build show-lib

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
		-DCOMPILER_RT_BUILD_SANITIZERS=ON \
		../compiler-rt

build:
	$(MAKE) -C $(BUILD_DIR) -j$(NUM_CORES) rtsan

clean:
	rm -rf $(BUILD_DIR)

show-lib:
	@echo "Built library:"
ifeq ($(TARGET_OS),linux)
	@echo "$(BUILD_DIR)/lib/linux/libclang_rt.rtsan-$(TARGET_ARCH).a"
else
	@echo "$(BUILD_DIR)/lib/darwin/libclang_rt.rtsan_osx_dynamic.dylib"
endif

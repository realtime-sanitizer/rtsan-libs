LLVM_PROJECT_DIR := llvm-project
BUILD_DIR := $(LLVM_PROJECT_DIR)/build
TARGET_OS := $(shell uname | tr '[:upper:]' '[:lower:]')
TARGET_ARCH := $(shell uname -m)
NUM_CORES := $(shell nproc 2>/dev/null || sysctl -n hw.ncpu)

.PHONY: all clone init checkout configure build show-lib clean

all: init checkout configure build show-lib

clone:
	if [ ! -d "$(LLVM_PROJECT_DIR)" ]; then \
		git clone --branch llvmorg-20.1.0 \
			https://github.com/llvm/llvm-project.git \
			$(LLVM_PROJECT_DIR); \
	fi

init: clone
	git -C $(LLVM_PROJECT_DIR) sparse-checkout init --no-cone
	git -C $(LLVM_PROJECT_DIR) sparse-checkout set compiler-rt cmake

checkout:
	git -C $(LLVM_PROJECT_DIR) checkout

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

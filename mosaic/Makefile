CUDA_VER?=
ifeq ($(CUDA_VER),)
  $(error "CUDA_VER is not set")
endif

# 检测GPU架构
GPU_ARCHS?=
ifeq ($(GPU_ARCHS),)
    # 默认架构列表，可根据实际GPU修改
    GPU_ARCHS:=86 89 90
endif

# 构建-gencode参数列表
NVCC_GENCODE:=
$(foreach arch,$(GPU_ARCHS),$(eval NVCC_GENCODE += -gencode arch=compute_$(arch),code=sm_$(arch)))
$(foreach arch,$(GPU_ARCHS),$(eval NVCC_GENCODE += -gencode arch=compute_$(arch),code=compute_$(arch)))

# CUDA兼容性版本
CUDA_COMPAT_VER?=$(shell echo $(CUDA_VER) | cut -d. -f1-2)

NVCC:=/usr/local/cuda-$(CUDA_VER)/bin/nvcc
CXX:= g++
CU_FILES:= mosaic.cu
INCS:= $(wildcard *.h)
LIB:=libcudamosaic.so

LIB_INSTALL_DIR?=/opt/nvidia/deepstream/deepstream/lib/

CFLAGS+= -fPIC -Wno-deprecated-declarations -std=c++14 \
	 -I /usr/local/cuda-$(CUDA_VER)/include \
	 -I /opt/nvidia/deepstream/deepstream-$(NVDS_VERSION)/sources/includes/ -DNDEBUG

# 为NVCC添加GPU架构和兼容性选项
NVCC_FLAGS+= $(NVCC_GENCODE) \
		--compiler-options '-fPIC'


LIBS := -shared -Wl,-no-undefined \
	 -lpthread \
	 -L/usr/local/cuda-$(CUDA_VER)/lib64/ -lcudart

LIBS+= -L$(LIB_INSTALL_DIR) -ldl \
       -Wl,-rpath,$(LIB_INSTALL_DIR)

OBJS:= $(CU_FILES:.cu=.o)

all: $(LIB)

%.o: %.cu $(INCS) Makefile
	@echo "Compiling with NVCC flags: $(NVCC_FLAGS)"
	$(NVCC) -c -o $@ $(NVCC_FLAGS) $<

$(LIB): $(OBJS) $(DEP) Makefile
	@echo $(CFLAGS)
	$(CXX) -o $@ $(OBJS) $(LIBS)

install: $(LIB)
	cp -rv $(LIB) $(LIB_INSTALL_DIR)

clean:
	rm -rf $(OBJS) $(LIB)    
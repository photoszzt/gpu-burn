ifneq ("$(wildcard /usr/bin/nvcc)", "")
CUDAPATH ?= /usr
else ifneq ("$(wildcard /usr/local/cuda/bin/nvcc)", "")
CUDAPATH ?= /usr/local/cuda
endif

IS_JETSON   ?= $(shell if grep -Fwq "Jetson" /proc/device-tree/model 2>/dev/null; then echo true; else echo false; fi)
NVCC        :=  ${CUDAPATH}/bin/nvcc
CCPATH      ?=

override CFLAGS   ?=
override CFLAGS   += -O3
override CFLAGS   += -Wno-unused-result
override CFLAGS   += -I${CUDAPATH}/include
override CFLAGS   += -std=c++11
override CFLAGS   += -DIS_JETSON=${IS_JETSON}
override CFLAGS   += -Wextra -Wall -Werror

override LDFLAGS  ?=
override LDFLAGS  += -lcuda
override LDFLAGS  += -L${CUDAPATH}/lib64
override LDFLAGS  += -L${CUDAPATH}/lib64/stubs
override LDFLAGS  += -L${CUDAPATH}/lib
override LDFLAGS  += -L${CUDAPATH}/lib/stubs
override LDFLAGS  += -Wl,-rpath=${CUDAPATH}/lib64
override LDFLAGS  += -Wl,-rpath=${CUDAPATH}/lib
override LDFLAGS  += -lcublas
override LDFLAGS  += -lcudart

CUDA_VERSION ?= 11.8.0
IMAGE_DISTRO ?= ubi8

override NVCCFLAGS ?= -gencode=arch=compute_80,code=sm_80 \
                      -gencode=arch=compute_86,code=sm_86 \
                      -gencode=arch=compute_89,code=sm_89 \
                      -gencode=arch=compute_90,code=sm_90 \
                      -gencode=arch=compute_100,code=sm_100 \
                      -gencode=arch=compute_120,code=compute_120

override NVCCFLAGS += -I${CUDAPATH}/include

IMAGE_NAME ?= gpu-burn

.PHONY: clean

gpu_burn: gpu_burn-drv.o compare.fatbin
	g++ -o $@ $< -O3 ${LDFLAGS}

%.o: %.cpp
	g++ ${CFLAGS} -c $<

%.fatbin: %.cu
	PATH="${PATH}:${CCPATH}:." ${NVCC} ${NVCCFLAGS} -fatbin $< -o $@

clean:
	$(RM) *.ptx *.fatbin *.o gpu_burn

image:
	docker build --build-arg CUDA_VERSION=${CUDA_VERSION} --build-arg IMAGE_DISTRO=${IMAGE_DISTRO} -t ${IMAGE_NAME} .

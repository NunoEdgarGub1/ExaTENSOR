NAME = qforce.v13.01.x
FC  = ftn
CC  = cc
CPP = CC
CUDA_C = nvcc
MPI_INC = -I.
CUDA_INC = -I.
CUDA_LINK = -lcudart -lcublas -L.
CUDA_FLAGS_DEV = --compile -arch=sm_35 -D CUDA_ARCH=350 -g -G -D DEBUG_GPU
CUDA_FLAGS_OPT = --compile -arch=sm_35 -D CUDA_ARCH=350 -O3
CUDA_FLAGS = $(CUDA_FLAGS_OPT)
LA_LINK_INTEL = -lmkl_core -lmkl_intel_thread -lmkl_intel_lp64 -lmkl_blas95_lp64 -lmkl_lapack95_lp64 -lrt
LA_LINK_AMD = -lacml_mp -L/opt/acml/5.3.1/gfortran64_mp/lib
LA_LINK_CRAY = " "
LA_LINK = $(LA_LINK_CRAY)
CFLAGS_DEV = -c -D CUDA_ARCH=350 -g
CFLAGS_OPT = -c -D CUDA_ARCH=350 -O3
CFLAGS = $(CFLAGS_OPT)
FFLAGS_DEV = -c -D CUDA_ARCH=350 -g
FFLAGS_OPT = -c -D CUDA_ARCH=350 -O3
FFLAGS_DEV_GNU = $(FFLAGS_DEV) -fopenmp -fbacktrace -fcheck=bounds -fcheck=array-temps -fcheck=pointer -pg
FFLAGS_OPT_GNU = $(FFLAGS_OPT) -fopenmp
FFLAGS_DEV_PGI = $(FFLAGS_DEV) -mp -Mcache_align -Mbounds -Mchkptr
FFLAGS_OPT_PGI = $(FFLAGS_OPT) -mp -Mcache_align
FFLAGS_DEV_INTEL = $(FFLAGS_DEV) -fpp -vec-threshold4 -vec-report2 -openmp -openmp-report2 -D USE_MKL
FFLAGS_OPT_INTEL = $(FFLAGS_OPT) -fpp -vec-threshold4 -vec-report2 -openmp -openmp-report2 -D USE_MKL
FFLAGS = $(FFLAGS_OPT) -D NO_PHI
LFLAGS_GNU = -lgomp
LFLAGS_PGI = -lpthread
LFLAGS = $(LA_LINK) $(CUDA_LINK) -o

OBJS = stsubs.o combinatoric.o extern_names.o service.o lists.o dictionary.o timers.o \
	symm_index.o tensor_algebra.o tensor_dil_omp.o tensor_algebra_intel_phi.o \
	cuda2fortran.o c_proc_bufs.o tensor_algebra_gpu_nvidia.o sys_service.o \
	c_process.o qforce.o main.o proceed.o

$(NAME): $(OBJS)
	$(FC) $(OBJS) $(MPI_INC) $(CUDA_INC) $(LFLAGS) $(NAME)

%.o: %.F90 qforce.mod
	$(FC) $(MPI_INC) $(CUDA_INC) $(FFLAGS) $?

qforce.mod: qforce.o
qforce.o: qforce.F90 extern_names.mod combinatoric.mod service.mod c_process.mod
	$(FC) $(MPI_INC) $(CUDA_INC) $(FFLAGS) qforce.F90

c_process.mod: c_process.o
c_process.o: c_process.F90 extern_names.mod service.mod lists.mod dictionary.mod timers.mod tensor_algebra_intel_phi.mod
	$(FC) $(MPI_INC) $(CUDA_INC) $(FFLAGS) c_process.F90

tensor_algebra_intel_phi.mod: tensor_algebra_intel_phi.o
tensor_algebra_intel_phi.o: tensor_algebra_intel_phi.F90 tensor_algebra.mod
	$(FC) $(MPI_INC) $(CUDA_INC) $(FFLAGS) tensor_algebra_intel_phi.F90

tensor_algebra.mod: tensor_algebra.o
tensor_algebra.o: tensor_algebra.F90 stsubs.mod combinatoric.mod symm_index.mod timers.mod tensor_algebra.inc
	$(FC) $(MPI_INC) $(CUDA_INC) $(FFLAGS) tensor_algebra.F90

tensor_dil_omp.mod: tensor_dil_omp.o
tensor_dil_omp.o: tensor_dil_omp.F90 timers.mod
	$(FC) $(MPI_INC) $(CUDA_INC) $(FFLAGS) tensor_dil_omp.F90

service.mod: service.o
service.o: service.F90 stsubs.mod
	$(FC) $(MPI_INC) $(CUDA_INC) $(FFLAGS) service.F90

symm_index.mod: symm_index.o
symm_index.o: symm_index.F90
	$(FC) $(MPI_INC) $(CUDA_INC) $(FFLAGS) symm_index.F90

dictionary.mod: dictionary.o
dictionary.o: dictionary.F90
	$(FC) $(MPI_INC) $(CUDA_INC) $(FFLAGS) dictionary.F90

lists.mod: lists.o
lists.o: lists.F90
	$(FC) $(MPI_INC) $(CUDA_INC) $(FFLAGS) lists.F90

timers.mod: timers.o
timers.o: timers.F90
	$(FC) $(MPI_INC) $(CUDA_INC) $(FFLAGS) timers.F90

combinatoric.mod: combinatoric.o
combinatoric.o: combinatoric.F90
	$(FC) $(MPI_INC) $(CUDA_INC) $(FFLAGS) combinatoric.F90

stsubs.mod: stsubs.o
stsubs.o: stsubs.F90
	$(FC) $(MPI_INC) $(CUDA_INC) $(FFLAGS) stsubs.F90

extern_names.mod: extern_names.o
extern_names.o: extern_names.F90
	$(FC) $(MPI_INC) $(CUDA_INC) $(FFLAGS) extern_names.F90

c_proc_bufs.o: c_proc_bufs.cu tensor_algebra.h
	$(CUDA_C) $(MPI_INC) $(CUDA_INC) $(CUDA_FLAGS) c_proc_bufs.cu

cuda2fortran.o: cuda2fortran.cu
	$(CUDA_C) $(MPI_INC) $(CUDA_INC) $(CUDA_FLAGS) -ptx cuda2fortran.cu
	$(CUDA_C) $(MPI_INC) $(CUDA_INC) $(CUDA_FLAGS) cuda2fortran.cu

tensor_algebra_gpu_nvidia.o: tensor_algebra_gpu_nvidia.cu tensor_algebra.h
	$(CUDA_C) $(MPI_INC) $(CUDA_INC) $(CUDA_FLAGS) -ptx tensor_algebra_gpu_nvidia.cu
	$(CUDA_C) $(MPI_INC) $(CUDA_INC) $(CUDA_FLAGS) tensor_algebra_gpu_nvidia.cu

sys_service.o: sys_service.c
	$(CC) $(CFLAGS) sys_service.c

clean:
	rm *.o *.mod *.modmic *.ptx *.x

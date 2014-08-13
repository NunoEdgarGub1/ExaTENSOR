NAME = qforce.v13.01.x
FC  = ftn
CC  = cc
CPP = CC
CUDA_C = nvcc
MPI_INC = -I.
CUDA_INC = -I.
CUDA_LIB = -L.
CUDA_LINK = -lcudart -lcublas
CUDA_FLAGS_DEV = --compile -arch=sm_35 -g -G -DDEBUG
CUDA_FLAGS_OPT = --compile -O3 -arch=sm_35
CUDA_FLAGS = $(CUDA_FLAGS_DEV)
LA_LINK_INTEL = -lmkl_core -lmkl_intel_thread -lmkl_intel_lp64 -lmkl_blas95_lp64 -lmkl_lapack95_lp64 -lrt
LA_LINK_CRAY = -lacml
LA_LINK = $(LA_LINK_CRAY)
CFLAGS_DEV = -c -g
CFLAGS_OPT = -c -O3
CFLAGS = $(CFLAGS_DEV)
FFLAGS_DEV = -c -g
FFLAGS_OPT = -c -O3
FFLAGS_DEV_GNU = -c -g -fopenmp -fbacktrace -fcheck=bounds -fcheck=array-temps -fcheck=pointer
FFLAGS_OPT_GNU = -c -O3 -fopenmp
FFLAGS_DEV_PGI = -c -g -mp
FFLAGS_OPT_PGI = -c -O3 -mp
FFLAGS_DEV_INTEL = -c -g -fpp -vec-threshold4 -vec-report2 -openmp -openmp-report2
FFLAGS_OPT_INTEL = -c -O3 -fpp -vec-threshold4 -vec-report2 -openmp -openmp-report2
FFLAGS = $(FFLAGS_DEV_GNU) -DNO_PHI
LFLAGS_GNU = -lgomp
LFLAGS_PGI = -lpthread
LFLAGS = $(LFLAGS_GNU) $(LA_LINK) -o

OBJS = stsubs.o combinatoric.o extern_names.o service.o lists.o dictionary.o timers.o \
	symm_index.o tensor_algebra.o tensor_dil_omp.o tensor_algebra_intel_phi.o \
	cuda2fortran.o c_proc_bufs.o tensor_algebra_gpu_nvidia.o c_process.o qforce.o \
	main.o proceed.o

$(NAME): $(OBJS)
	$(FC) $(OBJS) $(MPI_INC) $(CUDA_INC) $(CUDA_LIB) $(CUDA_LINK) $(LFLAGS) $(NAME)

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
tensor_algebra.o: tensor_algebra.F90 stsubs.mod combinatoric.mod symm_index.mod timers.mod tensor_algebra_gpu_nvidia.inc
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

c_proc_bufs.o: c_proc_bufs.cu tensor_algebra_gpu_nvidia.h
	$(CUDA_C) $(MPI_INC) $(CUDA_INC) $(CUDA_FLAGS) c_proc_bufs.cu

cuda2fortran.o: cuda2fortran.cu
	$(CUDA_C) $(MPI_INC) $(CUDA_INC) $(CUDA_FLAGS) -ptx cuda2fortran.cu
	$(CUDA_C) $(MPI_INC) $(CUDA_INC) $(CUDA_FLAGS) cuda2fortran.cu

tensor_algebra_gpu_nvidia.o: tensor_algebra_gpu_nvidia.cu tensor_algebra_gpu_nvidia.h
	$(CUDA_C) $(MPI_INC) $(CUDA_INC) $(CUDA_FLAGS) -ptx tensor_algebra_gpu_nvidia.cu
	$(CUDA_C) $(MPI_INC) $(CUDA_INC) $(CUDA_FLAGS) tensor_algebra_gpu_nvidia.cu

clean:
	rm *.o *.mod *.x *.ptx

!TENSOR ALGEBRA IN PARALLEL (TAP) for SHARED-MEMORY SYSTEMS (OpenMP based)
!AUTHOR: Dmitry I. Lyakh (Dmytro I. Liakh): quant4me@gmail.com
!REVISION: 2014/01/17
       module tensor_algebra
        use, intrinsic:: ISO_C_BINDING
        use STSUBS
        use combinatoric
#ifdef USE_MKL
        use mkl95_blas
        use mkl95_lapack
        use mkl95_precision
#endif
!GNU FORTRAN compiling options: -c -O3 --free-line-length-none -x f95-cpp-input -fopenmp
!GNU linking options: -lgomp -blas -llapack
!ACRONYMS:
! - mlndx - multiindex;
! - Lm - Level-min segment size (the lowest level segment size for bricked storage);
! - dlf - dimension-led storage of tensor blocks where the 1st dimension is the most minor (Fortran like) (DEFAULT):
!         Numeration within each dimension starts from 0: [0..extent-1].
! - dlc - dimension-led storage of tensor blocks where the 1st dimension is the most senior (C like);
!         Numeration within each dimension starts from 0: [0..extent-1].
! - brf - bricked storage of tensor blocks where the 1st dimension is the most minor (Fortran like) (DEFAULT);
! - brc - bricked storage of tensor blocks where the 1st dimension is the most senior (C like);
! - r4 - real(4);
! - r8 - real(8);
! - c8 - complex(8);

!FUNCTION PROTOTYPES:

!PARAMETERS:
        include 'tensor_algebra_gpu_nvidia.inc'
 !Default output for the module procedures and functions:
	integer, private:: cons_out=6 !default output device for this module
 !Global:
	integer, parameter, public:: max_shape_str_len=1024 !max allowed length for a tensor shape specification string (TSSS)
	integer, parameter, private:: max_threads=1024      !max allowed number of threads
	logical, private:: data_kind_sync=.true. !if .true., each tensor operation will syncronize all existing data kinds
	logical, private:: trans_shmem=.true.    !shared-memory based (true) VS scatter (false) tensor transpose algorithm
	logical, private:: disable_blas=.false.  !if .true. and BLAS is accessible, BLAS calls will be replaced by my own routines
 !Numerical:
	real(8), parameter:: abs_cmp_thresh=1d-13 !default absolute error threshold for numerical comparisons
	real(8), parameter:: rel_cmp_thresh=1d-2  !default relative error threshold for numerical comparisons
 !Aliases:
  !Tensor block storage layout:
	integer, parameter:: not_allocated=0        !tensor block has not been initialized
	integer, parameter:: scalar_tensor=1        !scalar (rank-0 tensor)
	integer, parameter:: dimension_led=2        !dense tensor block (column-major storage by default): no symmetry restrictions!
	integer, parameter:: bricked_dense=3        !dense tensor block (bricked storage): no symmetry restrictions, %dim_group(:)=0.
	integer, parameter:: bricked_ordered=4      !symmetrically packed tensor block (bricked storage): symmetry restrictions apply, %dim_group(:)!=0.
	integer, parameter:: sparse_list=5          !sparse tensor block: symmetry restrictions do not apply!
	integer, parameter:: compressed=6           !compressed tensor block: symmetry restrictions do not apply!
	logical, parameter:: fortran_like=.true.
	logical, parameter:: c_like=.false.
!DERIVED DATA TYPES:
 !Tensor shape (storage layout specification for a tensor block):
	type tensor_shape_t
	 integer:: num_dim=-1                  !total number of dimensions (num_dim=0 defines a scalar tensor).
	 integer, allocatable:: dim_extent(:)  !extent of each dimension (if num_dim>0): [0..extent-1].
	 integer, allocatable:: dim_divider(:) !divider for each dimension, i.e. the <Lm_segment_size> (ordered dimensions must have the same divider!): %dim_divider(1)=0 means that an alternative (neither dimension-led nor bricked) storage layout is used.
	 integer, allocatable:: dim_group(:)   !dimension grouping (default group 0 means no symmetry restrictions): if %dim_divider(1)=0, then %dim_group(1) regulates the alternative storage layout kind.
	end type tensor_shape_t
 !Tensor block:
	type tensor_block_t
	 integer(8):: tensor_block_size=0_8         !total number of elements in the tensor block (informal, set after creation)
	 type(tensor_shape_t):: tensor_shape        !shape of the tensor block (see above)
	 complex(8):: scalar_value=cmplx(0d0,0d0,8) !scalar value if the rank is zero, otherwise can be used for storing the norm of the tensor block
	 real(4), allocatable:: data_real4(:)       !tensor block data (float)
	 real(8), allocatable:: data_real8(:)       !tensor block data (double)
	 complex(8), allocatable:: data_cmplx8(:)   !tensor block data (complex)
	end type tensor_block_t
!GENERIC INTERFACES:
	interface divide_segment
	 module procedure divide_segment_i4
	 module procedure divide_segment_i8
	end interface divide_segment

	interface tensor_block_slice_dlf
!	 module procedure tensor_block_slice_dlf_r4 !`Enable
	 module procedure tensor_block_slice_dlf_r8
!	 module procedure tensor_block_slice_dlf_c8 !`Enable
	end interface tensor_block_slice_dlf

	interface tensor_block_insert_dlf
!	 module procedure tensor_block_insert_dlf_r4 !`Enable
	 module procedure tensor_block_insert_dlf_r8
!	 module procedure tensor_block_insert_dlf_c8 !`Enable
	end interface tensor_block_insert_dlf

	interface tensor_block_copy_dlf
	 module procedure tensor_block_copy_dlf_r4
	 module procedure tensor_block_copy_dlf_r8
!	 module procedure tensor_block_copy_dlf_c8 !`Enable
	end interface tensor_block_copy_dlf

	interface tensor_block_copy_scatter_dlf
	 module procedure tensor_block_copy_scatter_dlf_r4
	 module procedure tensor_block_copy_scatter_dlf_r8
!	 module procedure tensor_block_copy_scatter_dlf_c8 !`Enable
	end interface tensor_block_copy_scatter_dlf

	interface tensor_block_fcontract_dlf
	 module procedure tensor_block_fcontract_dlf_r4
	 module procedure tensor_block_fcontract_dlf_r8
!	 module procedure tensor_block_fcontract_dlf_c8 !`Enable
	end interface tensor_block_fcontract_dlf

	interface tensor_block_pcontract_dlf
	 module procedure tensor_block_pcontract_dlf_r4
	 module procedure tensor_block_pcontract_dlf_r8
!	 module procedure tensor_block_pcontract_dlf_c8 !`Enable
	end interface tensor_block_pcontract_dlf

	interface tensor_block_ftrace_dlf
!	 module procedure tensor_block_ftrace_dlf_r4 !`Enable
	 module procedure tensor_block_ftrace_dlf_r8
!	 module procedure tensor_block_ftrace_dlf_c8 !`Enable
	end interface tensor_block_ftrace_dlf

	interface tensor_block_ptrace_dlf
!	 module procedure tensor_block_ptrace_dlf_r4 !`Enable
	 module procedure tensor_block_ptrace_dlf_r8
!	 module procedure tensor_block_ptrace_dlf_c8 !`Enable
	end interface tensor_block_ptrace_dlf

!FUNCTION VISIBILITY:
	public set_data_kind_sync          !turns on/off data kind synchronization (0/1)
	public set_transpose_algorithm     !switches between scatter (0) and shared-memory (1) tensor transpose algorithms
	public set_matmult_algorithm       !switches between BLAS GEMM (0) and my OpenMP matmult kernels (1)
	public cmplx8_to_real8             !returns the real approximate of a complex number (algorithm by D.I.L.)
	public divide_segment              !divides a segment into subsegments maximally uniformly (max length difference of 1)
	public tensor_block_layout         !returns the type of the storage layout for a given tensor block
	public tensor_shape_size           !determines the tensor block size induced by its shape
	public tensor_master_data_kind     !determines the master data kind present in a tensor block
	public tensor_common_data_kind     !determines the common data kind present in two compatible tensor blocks
	public tensor_block_compatible     !determines whether two tensor blocks are compatible (under an optional index permutation)
	public tensor_block_mimic          !mimics the internal structure of a tensor block without copying the actual data
	public tensor_block_create         !creates a tensor block based on the shape specification string (SSS)
	public tensor_block_init           !initializes a tensor block with either a predefined value or random numbers
	public tensor_block_destroy        !destroys a tensor block
	public tensor_block_sync           !allocated and/or synchronizes different data kinds in a tensor block
	public tensor_block_scale          !multiplies all elements of a tensor block by some factor
	public tensor_block_norm1          !determines the 1-norm of a tensor block (the sum of moduli of all elements)
	public tensor_block_norm2          !determines the squared Euclidean (Frobenius) 2-norm of a tensor block
	public tensor_block_max            !determines the maximal (by modulus) tensor block element
	public tensor_block_min            !determines the minimal (by modulus) tensor block element
	public tensor_block_slice          !extracts a slice from a tensor block
	public tensor_block_insert         !inserts a slice into a tensor block
	public tensor_block_print          !prints a tensor block
	public tensor_block_trace          !intra-tensor index contraction (accumulative trace)
	public tensor_block_cmp            !compares two tensor blocks
	public tensor_block_copy           !makes a copy of a tensor block (with an optional index permutation)
	public tensor_block_add            !adds one tensor block to another
	public tensor_block_contract       !inter-tensor index contraction (accumulative contraction)
	public get_mlndx_addr              !generates an array of addressing increaments for the linearization map for symmetric multi-indices
	public mlndx_value                 !returns the address associated with a (symmetric) multi-index, based on the array generated by <get_mlndx_addr>
	public tensor_shape_rnd            !returns a random tensor-shape-specification-string (TSSS)
	public get_contr_pattern           !converts a mnemonic contraction pattern into the digital form used by tensor_block_contract
	public get_contr_permutations      !given a digital contraction pattern, returns all tensor permutations necessary for the subsequent matrix multiplication
	private tensor_shape_create        !generates the tensor shape based on the tensor shape specification string (TSSS)
	private tensor_shape_ok            !checks the correctness of a tensor shape generated from a tensor shape specification string (TSSS)
	private tensor_block_slice_dlf     !extracts a slice from a tensor block (Fortran-like dimension-led storage layout)
	private tensor_block_insert_dlf    !inserts a slice into a tensor block (Fortran-like dimension-led storage layout)
	private tensor_block_copy_dlf      !tensor transpose for dimension-led (Fortran-like-stored) dense tensor blocks
	private tensor_block_copy_scatter_dlf !tensor transpose for dimension-led (Fortran-like-stored) dense tensor blocks (scattering variant)
	private tensor_block_fcontract_dlf !multiplies two matrices derived from tensors to produce a scalar
	private tensor_block_pcontract_dlf !multiplies two matrices derived from tensors to produce a third matrix
	private tensor_block_ftrace_dlf    !takes a full trace of a tensor block
	private tensor_block_ptrace_dlf    !takes a partial trace of a tensor block

       contains
!-----------------
!PUBLIC FUNCTIONS:
!-----------------------------------------
	subroutine set_data_kind_sync(alg) !SERIAL
	implicit none
	integer, intent(in):: alg
	if(alg.eq.0) then; data_kind_sync=.false.; else; data_kind_sync=.true.; endif
	return
	end subroutine set_data_kind_sync
!----------------------------------------------
	subroutine set_transpose_algorithm(alg) !SERIAL
	implicit none
	integer, intent(in):: alg
	if(alg.eq.0) then; trans_shmem=.false.; else; trans_shmem=.true.; endif
	return
	end subroutine set_transpose_algorithm
!--------------------------------------------
	subroutine set_matmult_algorithm(alg) !SERIAL
	implicit none
	integer, intent(in):: alg
	if(alg.eq.0) then; disable_blas=.false.; else; disable_blas=.true.; endif
	return
	end subroutine set_matmult_algorithm
!--------------------------------------------------
	real(8) function cmplx8_to_real8(cmplx_num) !SERIAL
!This function returns a real approximant for a complex number with the following properties:
! 1) The Euclidean (Frobenius) norm (modulus) is preserved;
! 2) The sign inversion symmetry is preserved.
	implicit none
	complex(8), intent(in):: cmplx_num
	real(8) real_part
	real_part=dble(cmplx_num)
	if(real_part.ne.0d0) then
	 cmplx8_to_real8=abs(cmplx_num)*sign(1d0,real_part)
	else
	 cmplx8_to_real8=dimag(cmplx_num)
	endif
	return
	end function cmplx8_to_real8
!---------------------------------------------------------------------------
	subroutine divide_segment_i4(seg_range,subseg_num,subseg_sizes,ierr) !SERIAL
!A segment of range <seg_range> will be divided into <subseg_num> subsegments maximally uniformly.
!The length of each subsegment will be returned in the array <subseg_sizes(1:subseg_num)>.
!Any two subsegments will not differ in length by more than 1, longer subsegments preceding the shorter ones.
	implicit none
	integer, intent(in):: seg_range,subseg_num
	integer, intent(out):: subseg_sizes(1:subseg_num)
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n
	ierr=0
	if(seg_range.gt.0.and.subseg_num.gt.0) then
	 n=seg_range/subseg_num; m=mod(seg_range,subseg_num)
	 do i=1,m; subseg_sizes(i)=n+1; enddo
	 do i=m+1,subseg_num; subseg_sizes(i)=n; enddo
	else
	 ierr=-1
	endif
	return
	end subroutine divide_segment_i4
!---------------------------------------------------------------------------
	subroutine divide_segment_i8(seg_range,subseg_num,subseg_sizes,ierr) !SERIAL
!A segment of range <seg_range> will be divided into <subseg_num> subsegments maximally uniformly.
!The length of each subsegment will be returned in the array <subseg_sizes(1:subseg_num)>.
!Any two subsegments will not differ in length by more than 1, longer subsegments preceding the shorter ones.
	implicit none
	integer(8), intent(in):: seg_range,subseg_num
	integer(8), intent(out):: subseg_sizes(1:subseg_num)
	integer, intent(inout):: ierr
	integer(8) i,j,k,l,m,n
	ierr=0
	if(seg_range.gt.0_8.and.subseg_num.gt.0_8) then
	 n=seg_range/subseg_num; m=mod(seg_range,subseg_num)
	 do i=1_8,m; subseg_sizes(i)=n+1_8; enddo
	 do i=m+1_8,subseg_num; subseg_sizes(i)=n; enddo
	else
	 ierr=-1
	endif
	return
	end subroutine divide_segment_i8
!------------------------------------------------------------------
	integer function tensor_block_layout(tens,ierr,check_shape) !SERIAL
!Returns the type of the storage layout for a given tensor block <tens>.
!INPUT:
! - tens - tensor block;
! - check_shape - (optional) if .true., the tensor shape will be checked;
!OUTPUT:
! - tensor_block_layout - tensor block storage layout;
! - ierr - error code (0:sucess).
!NOTES:
! - %dim_divider(1)=0 means that an alternative (neither dimension-led nor bricked) storage layout is used,
!                     whose kind is regulated by the %dim_group(1) then.
	implicit none
	type(tensor_block_t), intent(inout):: tens !(out) because of <tensor_shape_ok>
	logical, intent(in), optional:: check_shape
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n,ibus(0:max_tensor_rank)

	ierr=0; tensor_block_layout=not_allocated
	if(present(check_shape)) then
	 if(check_shape) then; ierr=tensor_shape_ok(tens%tensor_shape); if(ierr.ne.0) return; endif
	endif
	if(tens%tensor_shape%num_dim.gt.0.and.allocated(tens%tensor_shape%dim_extent).and. &
	   allocated(tens%tensor_shape%dim_divider).and.allocated(tens%tensor_shape%dim_group)) then !true tensor
	 if(tens%tensor_shape%dim_divider(1).gt.0) then !dimension-led or bricked
	  tensor_block_layout=dimension_led
	  do i=1,tens%tensor_shape%num_dim
	   if(tens%tensor_shape%dim_extent(i).ne.tens%tensor_shape%dim_divider(i)) then
	    tensor_block_layout=bricked_dense; exit
	   endif
	  enddo
	  if(tensor_block_layout.eq.bricked_dense) then
	   ibus(0:tens%tensor_shape%num_dim)=0
	   do i=1,tens%tensor_shape%num_dim
	    j=tens%tensor_shape%dim_group(i)
	    if(j.gt.0.and.ibus(j).gt.0) then; tensor_block_layout=bricked_ordered; exit; endif
	    ibus(j)=ibus(j)+1
	   enddo
	  endif
	 else !alternative storage layout
	  !`Future
	 endif
	elseif(tens%tensor_shape%num_dim.eq.0) then !scalar tensor
	 tensor_block_layout=scalar_tensor
	endif
	return
	end function tensor_block_layout
!-------------------------------------------------------------
	integer(8) function tensor_shape_size(tens_block,ierr) !SERIAL
!This function determines the size of a tensor block (number of elements) by its shape.
!Note that a scalar (0-dimensional tensor) and a 1-dimensional tensor with extent 1 are not the same!
	implicit none
	type(tensor_block_t), intent(inout):: tens_block !(out) because of <tensor_block_layout> because of <tensor_shape_ok>
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n,k0,k1,k2,k3,ks,kf,tst

	ierr=0; tensor_shape_size=0_8
	tst=tensor_block_layout(tens_block,ierr); if(ierr.ne.0) return
	select case(tst)
	case(not_allocated)
	 tensor_shape_size=0_8; ierr=1
	case(scalar_tensor)
	 tensor_shape_size=1_8
	case(dimension_led,bricked_dense)
	 tensor_shape_size=1_8
	 do i=1,tens_block%tensor_shape%num_dim
	  if(tens_block%tensor_shape%dim_extent(i).gt.0.and. &
	     tens_block%tensor_shape%dim_divider(i).gt.0.and.tens_block%tensor_shape%dim_divider(i).le.tens_block%tensor_shape%dim_extent(i)) then
	   tensor_shape_size=tensor_shape_size*int(tens_block%tensor_shape%dim_extent(i),8)
	  else
	   ierr=i; return !invalid dimension specificator in tens_block%tensor_shape%
	  endif
	 enddo
	case(bricked_ordered)
	 !`Future
	case(sparse_list)
	 !`Future
	case(compressed)
	 !`Future
	case default
	 ierr=-1
	end select
	return
	end function tensor_shape_size
!---------------------------------------------------------------
	character(2) function tensor_master_data_kind(tens,ierr) !SERIAL
!This function determines the master data kind present in a tensor block.
!INPUT:
! - tens - tensor block;
!OUTPUT:
! - tensor_master_data_kind - one of {'r4','r8','c8','--'}, where the latter means "not allocated";
! - ierr - error code (0:success).
	implicit none
	type(tensor_block_t), intent(in):: tens
	integer, intent(inout):: ierr

	ierr=0; tensor_master_data_kind='--'
	if(tens%tensor_shape%num_dim.eq.0) then
	 tensor_master_data_kind='c8'
	elseif(tens%tensor_shape%num_dim.gt.0) then
	 if(allocated(tens%data_real4)) tensor_master_data_kind='r4'
	 if(allocated(tens%data_real8)) tensor_master_data_kind='r8'
	 if(allocated(tens%data_cmplx8)) tensor_master_data_kind='c8'
	endif
	return
	end function tensor_master_data_kind
!---------------------------------------------------------------------
	character(2) function tensor_common_data_kind(tens1,tens2,ierr) !SERIAL
!This function determines the common data kind present in two commpatible tensor blocks.
!INPUT:
! - tens1, tens2 - compatible tensor blocks;
!OUTPUT:
! - tensor_common_data_kind - one of {'r4','r8','c8','--'}, where the latter means "not applicable";
! - ierr - error code (0:success).
	implicit none
	type(tensor_block_t), intent(in):: tens1,tens2
	integer, intent(inout):: ierr

	ierr=0; tensor_common_data_kind='--'
	if(tens1%tensor_shape%num_dim.eq.0.and.tens2%tensor_shape%num_dim.eq.0) then
	 tensor_common_data_kind='c8'
	elseif(tens1%tensor_shape%num_dim.gt.0.and.tens2%tensor_shape%num_dim.gt.0) then
	 if(allocated(tens1%data_real4).and.allocated(tens2%data_real4)) tensor_common_data_kind='r4'
	 if(allocated(tens1%data_real8).and.allocated(tens2%data_real8)) tensor_common_data_kind='r8'
	 if(allocated(tens1%data_cmplx8).and.allocated(tens2%data_cmplx8)) tensor_common_data_kind='c8'
	endif
	return
	end function tensor_common_data_kind
!-------------------------------------------------------------------------------------------------
	logical function tensor_block_compatible(tens_in,tens_out,ierr,transp,no_check_data_kinds) !SERIAL
!This function decides whether two tensor blocks are compatible
!under some index permutation (the latter is optional).
!INPUT:
! - tens_in - input tensor;
! - tens_out - output tensor;
! - transp(0:*) - (optional) O2N index permutation;
! - no_check_data_kinds - (optional) if .true., the two tensor blocks do not have to have the same data kinds allocated;
!OUTPUT:
! - tensor_block_compatible - .true./.false.;
! - ierr - error code (0:success).
!NOTES:
! - Non-allocated tensor blocks are all compatible.
! - Tensor block storage layouts are ignored.
	implicit none
	type(tensor_block_t), intent(in):: tens_in,tens_out
	integer, intent(in), optional:: transp(0:*)
	logical, intent(in), optional:: no_check_data_kinds
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n,k0,k1,k2,k3,ks,kf
	integer trn(0:max_tensor_rank)
	integer(8) ls
	logical chdtk

	ierr=0; tensor_block_compatible=.true.
	if(tens_in%tensor_shape%num_dim.eq.tens_out%tensor_shape%num_dim) then
	 n=tens_in%tensor_shape%num_dim
	 if(n.gt.0) then
!Check tensor shapes:
	  if(allocated(tens_in%tensor_shape%dim_extent).and.allocated(tens_in%tensor_shape%dim_divider).and.allocated(tens_in%tensor_shape%dim_group).and. &
	     allocated(tens_out%tensor_shape%dim_extent).and.allocated(tens_out%tensor_shape%dim_divider).and.allocated(tens_out%tensor_shape%dim_group)) then
	   if(present(transp)) then; trn(0:n)=transp(0:n); else; trn(0:n)=(/+1,(j,j=1,n)/); endif
	   do i=1,n
	    if(tens_out%tensor_shape%dim_extent(trn(i)).ne.tens_in%tensor_shape%dim_extent(i).or. &
	       tens_out%tensor_shape%dim_divider(trn(i)).ne.tens_in%tensor_shape%dim_divider(i).or. &
	       tens_out%tensor_shape%dim_group(trn(i)).ne.tens_in%tensor_shape%dim_group(i)) then
	     tensor_block_compatible=.false.
	     exit
	    endif
	   enddo
!Check data kinds:
	   if(tensor_block_compatible) then
	    if(tens_in%tensor_block_size.ne.tens_out%tensor_block_size) then
	     tensor_block_compatible=.false.; ierr=1 !the same shape tensor blocks have different total sizes
	    else
	     if(present(no_check_data_kinds)) then; chdtk=no_check_data_kinds; else; chdtk=.false.; endif
	     if(.not.chdtk) then
	      if((allocated(tens_in%data_real4).and.(.not.allocated(tens_out%data_real4))).or. &
	        ((.not.allocated(tens_in%data_real4)).and.allocated(tens_out%data_real4))) then
	       tensor_block_compatible=.false.; return
	      else
	       if(allocated(tens_in%data_real4)) then
	        ls=size(tens_in%data_real4)
	        if(size(tens_out%data_real4).ne.ls.or.tens_out%tensor_block_size.ne.ls) then; tensor_block_compatible=.false.; ierr=3; return; endif
	       endif
	      endif
	      if((allocated(tens_in%data_real8).and.(.not.allocated(tens_out%data_real8))).or. &
	        ((.not.allocated(tens_in%data_real8)).and.allocated(tens_out%data_real8))) then
	       tensor_block_compatible=.false.; return
	      else
	       if(allocated(tens_in%data_real8)) then
	        ls=size(tens_in%data_real8)
	        if(size(tens_out%data_real8).ne.ls.or.tens_out%tensor_block_size.ne.ls) then; tensor_block_compatible=.false.; ierr=4; return; endif
	       endif
	      endif
	      if((allocated(tens_in%data_cmplx8).and.(.not.allocated(tens_out%data_cmplx8))).or. &
	        ((.not.allocated(tens_in%data_cmplx8)).and.allocated(tens_out%data_cmplx8))) then
	       tensor_block_compatible=.false.; return
	      else
	       if(allocated(tens_in%data_cmplx8)) then
	        ls=size(tens_in%data_cmplx8)
	        if(size(tens_out%data_cmplx8).ne.ls.or.tens_out%tensor_block_size.ne.ls) then; tensor_block_compatible=.false.; ierr=5; return; endif
	       endif
	      endif
	     endif
	    endif
	   endif
	  else
	   tensor_block_compatible=.false.; ierr=2 !some of the %tensor_shape arrays were not allocated
	  endif
	 endif
	else
	 tensor_block_compatible=.false.
	endif
	return
	end function tensor_block_compatible
!------------------------------------------------------------------
	subroutine tensor_block_mimic(tens_in,tens_out,ierr,transp) !SERIAL
!This subroutine copies the internal structure of a tensor block without copying the actual data.
!Optionally, it can also initialize the tensor shape according to a given permutation (O2N).
!INPUT:
! - tens_in - tensor block being mimicked;
! - transp(0:) - (optional) if present, the tensor shape will also be initialized according to this permutation (O2N);
!OUTPUT:
! - tens_out - output tensor block;
! - ierr - error code (0:success).
!NOTES:
! - Tensor block storage layouts are ignored.
	implicit none
	type(tensor_block_t), intent(in):: tens_in
	type(tensor_block_t), intent(inout):: tens_out
	integer, intent(in), optional:: transp(0:*)
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n,k0,k1,k2,k3,ks,kf

	ierr=0; call tensor_block_destroy(tens_out,ierr); if(ierr.ne.0) return
	n=tens_in%tensor_shape%num_dim
	tens_out%tensor_shape%num_dim=n
	tens_out%tensor_block_size=tens_in%tensor_block_size
	if(n.gt.0) then
	 if(allocated(tens_in%tensor_shape%dim_extent).and.allocated(tens_in%tensor_shape%dim_divider).and.allocated(tens_in%tensor_shape%dim_group)) then
	  if(size(tens_in%tensor_shape%dim_extent).eq.n.and.size(tens_in%tensor_shape%dim_divider).eq.n.and.size(tens_in%tensor_shape%dim_group).eq.n) then
 !Allocate tensor shape:
	   allocate(tens_out%tensor_shape%dim_extent(1:n),STAT=ierr); if(ierr.ne.0) return
	   allocate(tens_out%tensor_shape%dim_divider(1:n),STAT=ierr); if(ierr.ne.0) return
	   allocate(tens_out%tensor_shape%dim_group(1:n),STAT=ierr); if(ierr.ne.0) return
	   if(present(transp)) then !adopt the tensor shape in full according to the given permutation (O2N)
	    tens_out%tensor_shape%dim_extent(transp(1:n))=tens_in%tensor_shape%dim_extent(1:n)
	    tens_out%tensor_shape%dim_divider(transp(1:n))=tens_in%tensor_shape%dim_divider(1:n)
	    tens_out%tensor_shape%dim_group(transp(1:n))=tens_in%tensor_shape%dim_group(1:n)
	   endif
 !Allocate data arrays:
  !REAL4:
	   if(allocated(tens_in%data_real4)) then
	    if(size(tens_in%data_real4).eq.tens_in%tensor_block_size) then
	     allocate(tens_out%data_real4(0:tens_in%tensor_block_size-1),STAT=ierr); if(ierr.ne.0) return
	    else
	     ierr=5; return
	    endif
	   endif
  !REAL8:
	   if(allocated(tens_in%data_real8)) then
	    if(size(tens_in%data_real8).eq.tens_in%tensor_block_size) then
	     allocate(tens_out%data_real8(0:tens_in%tensor_block_size-1),STAT=ierr); if(ierr.ne.0) return
	    else
	     ierr=4; return
	    endif
	   endif
  !CMPLX8:
	   if(allocated(tens_in%data_cmplx8)) then
	    if(size(tens_in%data_cmplx8).eq.tens_in%tensor_block_size) then
	     allocate(tens_out%data_cmplx8(0:tens_in%tensor_block_size-1),STAT=ierr); if(ierr.ne.0) return
	    else
	     ierr=3; return
	    endif
	   endif
	  else
	   ierr=2
	  endif
	 else
	  ierr=1
	 endif
	endif
	return
	end subroutine tensor_block_mimic
!-----------------------------------------------------------------------------------------------
	subroutine tensor_block_create(shape_str,data_kind,tens_block,ierr,val_r4,val_r8,val_c8) !PARALLEL
!This subroutine creates a tensor block <tens_block> based on the tensor shape specification string (TSSS) <shape_str>.
!FORMAT of <shape_str>:
!"(E1/D1{G1},E2/D2{G2},...)":
!  Ex is the extent of the dimension x (segment);
!  /Dx specifies an optional segment divider for the dimension x (lm_segment_size), 1<=Dx<=Ex (DEFAULT = Ex);
!      Ex MUST be a multiple of Dx.
!  {Gx} optionally specifies the symmetric group the dimension belongs to, Gx>=0 (default group 0 has no symmetry ordering).
!       Dimensions grouped together (group#>0) will obey a non-descending ordering from left to right.
!By default, the 1st dimension is the most minor one while the last is the most senior (Fortran-like).
!If the number of dimensions equals to zero, the %scalar_value field will be initialized.
!INPUT:
! - shape_str - tensor shape specification string (SSS);
! - data_kind - requested data kind, one of {"r4","r8","c8"};
! - tens_block - tensor block;
! - val_r4/val_r8/val_c8 - (optional) initialization value for different data kinds (otherwise a random fill will be invoked);
!OUTPUT:
! - tens_block - filled tensor_block;
! - ierr - error code (0: success);
!NOTES:
! - If the tensor block has already been allocated before, it will be reshaped and reinitialized.
! - If ordered dimensions are present, the data feed may not reflect a proper symmetry (antisymmetry)!
	implicit none
	character(*), intent(in):: shape_str
	character(2), intent(in):: data_kind
	type(tensor_block_t), intent(inout):: tens_block
	real(4), intent(in), optional:: val_r4
	real(8), intent(in), optional:: val_r8
	complex(8), intent(in), optional:: val_c8
	integer, intent(inout):: ierr
	ierr=0
	call tensor_shape_create(shape_str,tens_block%tensor_shape,ierr); if(ierr.ne.0) return
	ierr=tensor_shape_ok(tens_block%tensor_shape); if(ierr.ne.0) return
	select case(data_kind)
	case('r4')
	 if(present(val_r4)) then
	  call tensor_block_init(data_kind,tens_block,ierr,val_r4=val_r4); if(ierr.ne.0) return
	 else
	  if(present(val_r8)) then
	   call tensor_block_init(data_kind,tens_block,ierr,val_r8=val_r8); if(ierr.ne.0) return
	  else
	   if(present(val_c8)) then
	    call tensor_block_init(data_kind,tens_block,ierr,val_c8=val_c8); if(ierr.ne.0) return
	   else
	    call tensor_block_init(data_kind,tens_block,ierr); if(ierr.ne.0) return
	   endif
	  endif
	 endif
	case('r8')
	 if(present(val_r8)) then
	  call tensor_block_init(data_kind,tens_block,ierr,val_r8=val_r8); if(ierr.ne.0) return
	 else
	  if(present(val_r4)) then
	   call tensor_block_init(data_kind,tens_block,ierr,val_r4=val_r4); if(ierr.ne.0) return
	  else
	   if(present(val_c8)) then
	    call tensor_block_init(data_kind,tens_block,ierr,val_c8=val_c8); if(ierr.ne.0) return
	   else
	    call tensor_block_init(data_kind,tens_block,ierr); if(ierr.ne.0) return
	   endif
	  endif
	 endif
	case('c8')
	 if(present(val_c8)) then
	  call tensor_block_init(data_kind,tens_block,ierr,val_c8=val_c8); if(ierr.ne.0) return
	 else
	  if(present(val_r8)) then
	   call tensor_block_init(data_kind,tens_block,ierr,val_r8=val_r8); if(ierr.ne.0) return
	  else
	   if(present(val_r4)) then
	    call tensor_block_init(data_kind,tens_block,ierr,val_r4=val_r4); if(ierr.ne.0) return
	   else
	    call tensor_block_init(data_kind,tens_block,ierr); if(ierr.ne.0) return
	   endif
	  endif
	 endif
	case default
	 ierr=-1
	end select
	return
	end subroutine tensor_block_create
!-----------------------------------------------------------------------------------
	subroutine tensor_block_init(data_kind,tens_block,ierr,val_r4,val_r8,val_c8) !PARALLEL
!This subroutine initializes a tensor block <tens_block> with either some value or random numbers.
!INPUT:
! - data_kind - requested data kind, one of {"r4","r8","c8"};
! - tens_block - tensor block;
! - val_r4/val_r8/val_c8 - (optional) if present, the tensor block is assigned the value <val> (otherwise, a random fill);
!OUTPUT:
! - tens_block - filled tensor block;
! - ierr - error code (0: success):
!                     -1: invalid (negative) tensor rank;
!                     -2: negative tensor size returned;
!                    x>0: invalid <tens_shape> (zero/negative xth dimension extent);
!                    666: invalid <data_kind>;
!                    667: memory allocation failed;
!NOTES:
! - For tensors with a non-zero rank, the %scalar_value field will be set to the Euclidean norm of the tensor block.
! - Scalar tensors will be initialized with the <val_XX> value (if present), regardless of the <data_kind>.
! - In general, a tensor block may have dimension ordering (symmetry) restrictions.
!   In this case, the number fill done here might not reflect the proper symmetry (e.g., antisymmetry)!
	implicit none
!-----------------------------------------------
	integer(8), parameter:: chunk_size=2**10
	integer(8), parameter:: vec_size=2**8
!-----------------------------------------------
	character(2), intent(in):: data_kind
	type(tensor_block_t), intent(inout):: tens_block
	real(4), intent(in), optional:: val_r4
	real(8), intent(in), optional:: val_r8
	complex(8), intent(in), optional:: val_c8
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n,k0,k1,k2,k3,k4,ks,kf
	integer(8) tens_size,l0,l1
	real(8) vec_r8(0:vec_size-1),valr8,val,rnd_buf(2)
	real(4) vec_r4(0:vec_size-1),valr4
	complex(8) vec_c8(0:vec_size-1),valc8

	ierr=0; tens_block%tensor_block_size=tensor_shape_size(tens_block,ierr); if(ierr.ne.0) return
	if(tens_block%tensor_block_size.le.0_8) then; ierr=-2; return; endif
	if(tens_block%tensor_shape%num_dim.eq.0) then !scalar tensor
	 if(allocated(tens_block%data_real4)) deallocate(tens_block%data_real4)
	 if(allocated(tens_block%data_real8)) deallocate(tens_block%data_real8)
	 if(allocated(tens_block%data_cmplx8)) deallocate(tens_block%data_cmplx8)
	 if(tens_block%tensor_block_size.ne.1_8) then; ierr=-3; return; endif
	endif
	select case(data_kind)
	case('r4')
	 if(tens_block%tensor_shape%num_dim.gt.0) then !true tensor
	  if(allocated(tens_block%data_real4)) then
	   if(size(tens_block%data_real4).ne.tens_block%tensor_block_size) then
	    deallocate(tens_block%data_real4)
	    allocate(tens_block%data_real4(0:tens_block%tensor_block_size-1),STAT=ierr); if(ierr.ne.0) then; ierr=667; return; endif
	   endif
	  else
	   allocate(tens_block%data_real4(0:tens_block%tensor_block_size-1),STAT=ierr); if(ierr.ne.0) then; ierr=667; return; endif
	  endif
	  if(present(val_r4).or.present(val_r8).or.present(val_c8)) then !constant fill
	   if(present(val_r4)) then
	    valr4=val_r4
	   else
	    if(present(val_r8)) then
	     valr4=real(val_r8,4)
	    else
	     if(present(val_c8)) then
	      valr4=real(cmplx8_to_real8(val_c8),4)
	     endif
	    endif
	   endif
	   vec_r4(0_8:vec_size-1_8)=valr4
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(l0,l1)
!$OMP DO SCHEDULE(GUIDED)
	   do l0=0_8,tens_block%tensor_block_size-1_8-mod(tens_block%tensor_block_size,vec_size),vec_size
	    do l1=0_8,vec_size-1_8; tens_block%data_real4(l0+l1)=vec_r4(l1); enddo
	   enddo
!$OMP END DO NOWAIT
!$OMP MASTER
	   tens_block%data_real4(tens_block%tensor_block_size-mod(tens_block%tensor_block_size,vec_size):tens_block%tensor_block_size-1_8)=valr4
!$OMP END MASTER
!$OMP END PARALLEL
	  else !random fill
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(l0,l1)
!$OMP DO SCHEDULE(GUIDED)
	   do l0=0_8,tens_block%tensor_block_size-1_8,chunk_size
	    l1=min(l0+chunk_size-1_8,tens_block%tensor_block_size-1_8)
	    call random_number(tens_block%data_real4(l0:l1))
	   enddo
!$OMP END DO
!$OMP END PARALLEL
	  endif
	  if(data_kind_sync) then
	   valr8=tensor_block_norm2(tens_block,ierr,'r4'); if(ierr.ne.0) return
	   tens_block%scalar_value=cmplx(dsqrt(valr8),0d0,8)
	  endif
	 else !scalar
	  if(present(val_r4)) then
	   tens_block%scalar_value=cmplx(val_r4,0d0,8)
	  else
	   if(present(val_r8)) then
	    tens_block%scalar_value=cmplx(val_r8,0d0,8)
	   else
	    if(present(val_c8)) then
	     tens_block%scalar_value=val_c8
	    else
	     call random_number(val); tens_block%scalar_value=cmplx(val,0d0,8)
	    endif
	   endif
	  endif
	 endif
	case('r8')
	 if(tens_block%tensor_shape%num_dim.gt.0) then !true tensor
	  if(allocated(tens_block%data_real8)) then
	   if(size(tens_block%data_real8).ne.tens_block%tensor_block_size) then
	    deallocate(tens_block%data_real8)
	    allocate(tens_block%data_real8(0:tens_block%tensor_block_size-1),STAT=ierr); if(ierr.ne.0) then; ierr=667; return; endif
	   endif
	  else
	   allocate(tens_block%data_real8(0:tens_block%tensor_block_size-1),STAT=ierr); if(ierr.ne.0) then; ierr=667; return; endif
	  endif
	  if(present(val_r4).or.present(val_r8).or.present(val_c8)) then !constant fill
	   if(present(val_r8)) then
	    valr8=val_r8
	   else
	    if(present(val_r4)) then
	     valr8=real(val_r4,8)
	    else
	     if(present(val_c8)) then
	      valr8=cmplx8_to_real8(val_c8)
	     endif
	    endif
	   endif
	   vec_r8(0_8:vec_size-1_8)=valr8
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(l0,l1)
!$OMP DO SCHEDULE(GUIDED)
	   do l0=0_8,tens_block%tensor_block_size-1_8-mod(tens_block%tensor_block_size,vec_size),vec_size
	    do l1=0_8,vec_size-1_8; tens_block%data_real8(l0+l1)=vec_r8(l1); enddo
	   enddo
!$OMP END DO NOWAIT
!$OMP MASTER
	   tens_block%data_real8(tens_block%tensor_block_size-mod(tens_block%tensor_block_size,vec_size):tens_block%tensor_block_size-1_8)=valr8
!$OMP END MASTER
!$OMP END PARALLEL
	  else !random fill
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(l0,l1)
!$OMP DO SCHEDULE(GUIDED)
	   do l0=0_8,tens_block%tensor_block_size-1_8,chunk_size
	    l1=min(l0+chunk_size-1_8,tens_block%tensor_block_size-1_8)
	    call random_number(tens_block%data_real8(l0:l1))
	   enddo
!$OMP END DO
!$OMP END PARALLEL
	  endif
	  if(data_kind_sync) then
	   valr8=tensor_block_norm2(tens_block,ierr,'r8'); if(ierr.ne.0) return
	   tens_block%scalar_value=cmplx(dsqrt(valr8),0d0,8)
	  endif
	 else !scalar
	  if(present(val_r8)) then
	   tens_block%scalar_value=cmplx(val_r8,0d0,8)
	  else
	   if(present(val_r4)) then
	    tens_block%scalar_value=cmplx(val_r4,0d0,8)
	   else
	    if(present(val_c8)) then
	     tens_block%scalar_value=val_c8
	    else
	     call random_number(val); tens_block%scalar_value=cmplx(val,0d0,8)
	    endif
	   endif
	  endif
	 endif
	case('c8')
	 if(tens_block%tensor_shape%num_dim.gt.0) then !true tensor
	  if(allocated(tens_block%data_cmplx8)) then
	   if(size(tens_block%data_cmplx8).ne.tens_block%tensor_block_size) then
	    deallocate(tens_block%data_cmplx8)
	    allocate(tens_block%data_cmplx8(0:tens_block%tensor_block_size-1),STAT=ierr); if(ierr.ne.0) then; ierr=667; return; endif
	   endif
	  else
	   allocate(tens_block%data_cmplx8(0:tens_block%tensor_block_size-1),STAT=ierr); if(ierr.ne.0) then; ierr=667; return; endif
	  endif
	  if(present(val_r4).or.present(val_r8).or.present(val_c8)) then !constant fill
	   if(present(val_c8)) then
	    valc8=val_c8
	   else
	    if(present(val_r8)) then
	     valc8=cmplx(val_r8,0d0,8)
	    else
	     if(present(val_r4)) then
	      valc8=cmplx(val_r4,0d0,8)
	     endif
	    endif
	   endif
	   vec_c8(0_8:vec_size-1_8)=valc8
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(l0,l1)
!$OMP DO SCHEDULE(GUIDED)
	   do l0=0_8,tens_block%tensor_block_size-1_8-mod(tens_block%tensor_block_size,vec_size),vec_size
	    do l1=0_8,vec_size-1_8; tens_block%data_cmplx8(l0+l1)=vec_c8(l1); enddo
	   enddo
!$OMP END DO NOWAIT
!$OMP MASTER
	   tens_block%data_cmplx8(tens_block%tensor_block_size-mod(tens_block%tensor_block_size,vec_size):tens_block%tensor_block_size-1_8)=valc8
!$OMP END MASTER
!$OMP END PARALLEL
	  else !random fill
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(l0,rnd_buf)
!$OMP DO SCHEDULE(GUIDED)
	   do l0=0_8,tens_block%tensor_block_size-1_8
	    call random_number(rnd_buf(1:2)); tens_block%data_cmplx8(l0)=cmplx(rnd_buf(1),rnd_buf(2),8)
	   enddo
!$OMP END DO
!$OMP END PARALLEL
	  endif
	  if(data_kind_sync) then
	   valr8=tensor_block_norm2(tens_block,ierr,'c8'); if(ierr.ne.0) return
	   tens_block%scalar_value=cmplx(dsqrt(valr8),0d0,8)
	  endif
	 else !scalar
	  if(present(val_c8)) then
	   tens_block%scalar_value=val_c8
	  else
	   if(present(val_r8)) then
	    tens_block%scalar_value=cmplx(val_r8,0d0,8)
	   else
	    if(present(val_r4)) then
	     tens_block%scalar_value=cmplx(val_r4,0d0,8)
	    else
	     call random_number(val); call random_number(valr8); tens_block%scalar_value=cmplx(val,valr8,8)
	    endif
	   endif
	  endif
	 endif
	case default
	 ierr=666
	end select
	return
	end subroutine tensor_block_init
!-------------------------------------------------------
	subroutine tensor_block_destroy(tens_block,ierr) !SERIAL
!This subroutine destroys a tensor block <tens_block>.
	implicit none
	type(tensor_block_t), intent(inout):: tens_block
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n
	ierr=0; tens_block%tensor_block_size=0_8
	if(allocated(tens_block%data_real4)) deallocate(tens_block%data_real4)
	if(allocated(tens_block%data_real8)) deallocate(tens_block%data_real8)
	if(allocated(tens_block%data_cmplx8)) deallocate(tens_block%data_cmplx8)
	tens_block%scalar_value=cmplx(0d0,0d0,8)
	call destroy_tensor_shape(tens_block%tensor_shape)
	return
	contains
	 subroutine destroy_tensor_shape(tens_shape)
	 type(tensor_shape_t), intent(inout):: tens_shape
	 tens_shape%num_dim=-1
	 if(allocated(tens_shape%dim_extent)) deallocate(tens_shape%dim_extent)
	 if(allocated(tens_shape%dim_divider)) deallocate(tens_shape%dim_divider)
	 if(allocated(tens_shape%dim_group)) deallocate(tens_shape%dim_group)
	 return
	 end subroutine destroy_tensor_shape
	end subroutine tensor_block_destroy
!-------------------------------------------------------------------
	subroutine tensor_block_sync(tens,mast_kind,ierr,slave_kind) !PARALLEL
!This subroutine allocates and/or synchronizes different data kinds within a tensor block.
!For tensors of positive rank, the %scalar_value field will contain the Euclidean (Frobenius) norm of the tensor block.
!Note that basic tensor operations do not have to keep different data kinds consistent, so it is fully on the user!
!INPUT:
! - tens - tensor block;
! - mast_kind - master data kind, one of {'r4','r8','c8'};
! - slave_kind - (optional) slave data kind, one of {'r4','r8','c8', or '--'} (the latter means to destroy the master data kind);
!                If absent, all allocated data kinds will be syncronized with the master data kind.
!OUTPUT:
! - tens - modified tensor block;
! - ierr - error code (0:success).
!NOTES:
! - All data kinds in rank-0 tensor blocks (scalars) are mapped to 'c8'. An attempt to destroy it will cause an error.
! - An attempt to destroy the only data kind present in the tensor block will cause an arror.
! - Non-allocated tensor blocks are ignored.
! - The tensor block storage layout does not matter here since it only affects the access pattern.
	implicit none
	type(tensor_block_t), intent(inout):: tens
	character(2), intent(in):: mast_kind
	character(2), intent(in), optional:: slave_kind
	integer, intent(inout):: ierr
	integer i,j,k,l,m
	character(2) slk
	integer(8) l0,ls
	real(4) val_r4
	real(8) val_r8
	complex(8) val_c8

	ierr=0
	if(mast_kind.ne.'r4'.and.mast_kind.ne.'r8'.and.mast_kind.ne.'c8') then; ierr=1; return; endif
	if(present(slave_kind)) then; slk=slave_kind; else; slk='  '; endif
	if(tens%tensor_shape%num_dim.gt.0) then !true tensor
	 if((mast_kind.eq.'r4'.and.allocated(tens%data_real4)).or. &
	    (mast_kind.eq.'r8'.and.allocated(tens%data_real8)).or. &
	    (mast_kind.eq.'c8'.and.allocated(tens%data_cmplx8))) then
	  ls=tens%tensor_block_size
	  if(slk.eq.'--') then !destroy master data kind
	   select case(mast_kind)
	   case('r4')
	    if(allocated(tens%data_real8).or.allocated(tens%data_cmplx8)) then
	     deallocate(tens%data_real4)
	    else
	     ierr=7; return
	    endif
	   case('r8')
	    if(allocated(tens%data_real4).or.allocated(tens%data_cmplx8)) then
	     deallocate(tens%data_real8)
	    else
	     ierr=8; return
	    endif
	   case('c8')
	    if(allocated(tens%data_real4).or.allocated(tens%data_real8)) then
	     deallocate(tens%data_cmplx8)
	    else
	     ierr=9; return
	    endif
	   end select
	  else
!Set the tensor block norm based on the master kind:
	   val_r8=tensor_block_norm2(tens,ierr,mast_kind); if(ierr.ne.0) return
	   tens%scalar_value=cmplx(dsqrt(val_r8),0d0,8) !Euclidean (Frobenius) norm of the tensor block
!Proceed:
	   if(slk.ne.mast_kind) then
 !REAL4:
	    if(slk.eq.'r4'.or.(mast_kind.ne.'r4'.and.slk.eq.'  '.and.allocated(tens%data_real4))) then
	     if(slk.ne.'  '.and.(.not.allocated(tens%data_real4))) then; allocate(tens%data_real4(0:ls-1),STAT=ierr); if(ierr.ne.0) return; endif
	     if(size(tens%data_real4).eq.ls) then
	      select case(mast_kind)
	      case('r8')
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED)
	       do l0=0_8,ls-1_8; tens%data_real4(l0)=real(tens%data_real8(l0),4); enddo
!$OMP END PARALLEL DO
	      case('c8')
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED)
	       do l0=0_8,ls-1_8; tens%data_real4(l0)=real(cmplx8_to_real8(tens%data_cmplx8(l0)),4); enddo
!$OMP END PARALLEL DO
	      end select
	     else
	      ierr=4; return !array size mismatch
	     endif
	    endif
 !REAL8:
	    if(slk.eq.'r8'.or.(mast_kind.ne.'r8'.and.slk.eq.'  '.and.allocated(tens%data_real8))) then
	     if(slk.ne.'  '.and.(.not.allocated(tens%data_real8))) then; allocate(tens%data_real8(0:ls-1),STAT=ierr); if(ierr.ne.0) return; endif
	     if(size(tens%data_real8).eq.ls) then
	      select case(mast_kind)
	      case('r4')
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED)
	       do l0=0_8,ls-1_8; tens%data_real8(l0)=tens%data_real4(l0); enddo
!$OMP END PARALLEL DO
	      case('c8')
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED)
	       do l0=0_8,ls-1_8; tens%data_real8(l0)=cmplx8_to_real8(tens%data_cmplx8(l0)); enddo
!$OMP END PARALLEL DO
	      end select
	     else
	      ierr=5; return !array size mismatch
	     endif
	    endif
 !COMPLEX8:
	    if(slk.eq.'c8'.or.(mast_kind.ne.'c8'.and.slk.eq.'  '.and.allocated(tens%data_cmplx8))) then
	     if(slk.ne.'  '.and.(.not.allocated(tens%data_cmplx8))) then; allocate(tens%data_cmplx8(0:ls-1),STAT=ierr); if(ierr.ne.0) return; endif
	     if(size(tens%data_cmplx8).eq.ls) then
	      select case(mast_kind)
	      case('r4')
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED)
	       do l0=0_8,ls-1_8; tens%data_cmplx8(l0)=cmplx(tens%data_real4(l0),0d0,8); enddo
!$OMP END PARALLEL DO
	      case('r8')
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED)
	       do l0=0_8,ls-1_8; tens%data_cmplx8(l0)=cmplx(tens%data_real8(l0),0d0,8); enddo
!$OMP END PARALLEL DO
	      end select
	     else
	      ierr=6; return !array size mismatch
	     endif
	    endif
	   endif
	  endif
	 else
	  ierr=3 !master data kind is not allocated
	 endif
	elseif(tens%tensor_shape%num_dim.eq.0) then !scalar
	 if(slk.eq.'--') ierr=2 !the scalar data kind cannot be deleted
	endif
	return
	end subroutine tensor_block_sync
!---------------------------------------------------------
	subroutine tensor_block_scale(tens,scale_fac,ierr) !PARALLEL
!This subroutine multiplies a tensor block by <scale_fac>.
!INPUT:
! - tens - tensor block;
! - scale_fac - scaling factor;
!OUTPUT:
! - tens - scaled tensor block;
! - ierr - error code (0:success).
!NOTES:
! - All allocated data kinds will be scaled (no further sycnronization is required).
	implicit none
	type(tensor_block_t), intent(inout):: tens
	complex(8), intent(in):: scale_fac
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n
	integer(8) l0,l1,ls
	real(4) fac_r4
	real(8) fac_r8
	complex(8) fac_c8

	ierr=0; ls=tens%tensor_block_size
	if(ls.gt.0_8) then
!REAL4:
	 if(allocated(tens%data_real4)) then
	  if(size(tens%data_real4).eq.ls) then
	   fac_r4=real(cmplx8_to_real8(scale_fac),4)
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) FIRSTPRIVATE(fac_r4) SCHEDULE(GUIDED)
	   do l0=0_8,ls-1_8; tens%data_real4(l0)=tens%data_real4(l0)*fac_r4; enddo
!$OMP END PARALLEL DO
	  else
	   ierr=1; return
	  endif
	 endif
!REAL8:
	 if(allocated(tens%data_real8)) then
	  if(size(tens%data_real8).eq.ls) then
	   fac_r8=cmplx8_to_real8(scale_fac)
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) FIRSTPRIVATE(fac_r8) SCHEDULE(GUIDED)
	   do l0=0_8,ls-1_8; tens%data_real8(l0)=tens%data_real8(l0)*fac_r8; enddo
!$OMP END PARALLEL DO
	  else
	   ierr=2; return
	  endif
	 endif
!CMPLX8:
	 if(allocated(tens%data_cmplx8)) then
	  if(size(tens%data_cmplx8).eq.ls) then
	   fac_c8=scale_fac
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) FIRSTPRIVATE(fac_c8) SCHEDULE(GUIDED)
	   do l0=0_8,ls-1_8; tens%data_cmplx8(l0)=tens%data_cmplx8(l0)*fac_c8; enddo
!$OMP END PARALLEL DO
	  else
	   ierr=3; return
	  endif
	 endif
	endif
	return
	end subroutine tensor_block_scale
!---------------------------------------------------------------
	real(8) function tensor_block_norm1(tens,ierr,data_kind) !PARALLEL
!This function computes the 1-norm of a tensor block.
!INPUT:
! - tens - tensor block;
! - data_kind - (optional) data kind, one of {'r4','r8','c8'};
!               If <data_kind> is not specified, the maximal one will be used (r4->r8->c8).
!OUTPUT:
! - tensor_block_norm1 - 1-norm of the tensor block;
! - ierr - error code (0:success).
	implicit none
	type(tensor_block_t), intent(in):: tens
	character(2), intent(in), optional:: data_kind
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n
	integer(8) l0,ls
	character(2) datk
	real(4) val_r4
	real(8) val_r8

	ierr=0; tensor_block_norm1=0d0
	if(present(data_kind)) then
	 datk=data_kind
	else
	 datk=tensor_master_data_kind(tens,ierr); if(ierr.ne.0) return
	endif
	if(tens%tensor_shape%num_dim.gt.0) then !true tensor
	 ls=tens%tensor_block_size
	 if(ls.gt.0_8) then
	  select case(datk)
	  case('r4')
	   if(allocated(tens%data_real4)) then
	    if(size(tens%data_real4).eq.ls) then
	     val_r4=0.0
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED) REDUCTION(+:val_r4)
	     do l0=0_8,ls-1_8; val_r4=val_r4+abs(tens%data_real4(l0)); enddo
!$OMP END PARALLEL DO
	     tensor_block_norm1=real(val_r4,8)
	    else
	     ierr=2
	    endif
	   else
	    ierr=3
	   endif
	  case('r8')
	   if(allocated(tens%data_real8)) then
	    if(size(tens%data_real8).eq.ls) then
	     val_r8=0d0
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED) REDUCTION(+:val_r8)
	     do l0=0_8,ls-1_8; val_r8=val_r8+abs(tens%data_real8(l0)); enddo
!$OMP END PARALLEL DO
	     tensor_block_norm1=val_r8
	    else
	     ierr=4
	    endif
	   else
	    ierr=5
	   endif
	  case('c8')
	   if(allocated(tens%data_cmplx8)) then
	    if(size(tens%data_cmplx8).eq.ls) then
	     val_r8=0d0
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED) REDUCTION(+:val_r8)
	     do l0=0_8,ls-1_8; val_r8=val_r8+abs(tens%data_cmplx8(l0)); enddo
!$OMP END PARALLEL DO
	     tensor_block_norm1=val_r8
	    else
	     ierr=6
	    endif
	   else
	    ierr=7
	   endif
	  case default
	   ierr=-3
	  end select
	 else
	  ierr=-2
	 endif
	elseif(tens%tensor_shape%num_dim.eq.0) then !scalar tensor
	 tensor_block_norm1=abs(tens%scalar_value)
	else !empty tensor
	 ierr=-1
	endif
	return
	end function tensor_block_norm1
!---------------------------------------------------------------
	real(8) function tensor_block_norm2(tens,ierr,data_kind) !PARALLEL
!This function computes the squared Euclidean (Frobenius) 2-norm of a tensor block.
!INPUT:
! - tens - tensor block;
! - data_kind - (optional) data kind, one of {'r4','r8','c8'};
!               If <data_kind> is not specified, the maximal one will be used (r4->r8->c8).
!OUTPUT:
! - tensor_block_norm2 - squared 2-norm of the tensor block;
! - ierr - error code (0:success).
	implicit none
	type(tensor_block_t), intent(in):: tens
	character(2), intent(in), optional:: data_kind
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n
	integer(8) l0,ls
	character(2) datk
	real(4) val_r4
	real(8) val_r8

	ierr=0; tensor_block_norm2=0d0
	if(present(data_kind)) then
	 datk=data_kind
	else
	 datk=tensor_master_data_kind(tens,ierr); if(ierr.ne.0) return
	endif
	if(tens%tensor_shape%num_dim.gt.0) then !true tensor
	 ls=tens%tensor_block_size
	 if(ls.gt.0_8) then
	  select case(datk)
	  case('r4')
	   if(allocated(tens%data_real4)) then
	    if(size(tens%data_real4).eq.ls) then
	     val_r4=0.0
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED) REDUCTION(+:val_r4)
	     do l0=0_8,ls-1_8; val_r4=val_r4+tens%data_real4(l0)**2; enddo
!$OMP END PARALLEL DO
	     tensor_block_norm2=real(val_r4,8)
	    else
	     ierr=2
	    endif
	   else
	    ierr=3
	   endif
	  case('r8')
	   if(allocated(tens%data_real8)) then
	    if(size(tens%data_real8).eq.ls) then
	     val_r8=0d0
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED) REDUCTION(+:val_r8)
	     do l0=0_8,ls-1_8; val_r8=val_r8+tens%data_real8(l0)**2; enddo
!$OMP END PARALLEL DO
	     tensor_block_norm2=val_r8
	    else
	     ierr=4
	    endif
	   else
	    ierr=5
	   endif
	  case('c8')
	   if(allocated(tens%data_cmplx8)) then
	    if(size(tens%data_cmplx8).eq.ls) then
	     val_r8=0d0
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED) REDUCTION(+:val_r8)
	     do l0=0_8,ls-1_8; val_r8=val_r8+abs(tens%data_cmplx8(l0))**2; enddo
!$OMP END PARALLEL DO
	     tensor_block_norm2=val_r8
	    else
	     ierr=6
	    endif
	   else
	    ierr=7
	   endif
	  case default
	   ierr=-3
	  end select
	 else
	  ierr=-2
	 endif
	elseif(tens%tensor_shape%num_dim.eq.0) then !scalar tensor
	 tensor_block_norm2=abs(tens%scalar_value)**2
	else !empty tensor
	 ierr=-1
	endif
	return
	end function tensor_block_norm2
!-------------------------------------------------------------
	real(8) function tensor_block_max(tens,ierr,data_kind) !PARALLEL
!This function finds the largest by modulus element in a tensor block.
!INPUT:
! - tens - tensor block;
! - data_kind - (optional) requested data kind;
!OUTPUT:
! - tensor_block_max - modulus of the max element(s);
! - ierr - error code (0:success).
	implicit none
	type(tensor_block_t), intent(inout):: tens !(out) because of <tensor_block_sync>
	character(2), intent(in), optional:: data_kind
	integer, intent(inout):: ierr
	character(2) dtk
	integer(8) l0
	real(8) val

	ierr=0
	if(tens%tensor_shape%num_dim.gt.0) then !true tensor
	 if(present(data_kind)) then; dtk=data_kind; else; dtk=tensor_master_data_kind(tens,ierr); if(ierr.ne.0) return; endif
	 if(dtk.ne.'r4'.and.dtk.ne.'r8'.and.dtk.ne.'c8') then; ierr=1; return; endif
	 select case(dtk)
	 case('r4')
	  if(allocated(tens%data_real4)) then
	   if(size(tens%data_real4).eq.tens%tensor_block_size) then
	    val=0d0
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED) REDUCTION(max:val)
	    do l0=0_8,tens%tensor_block_size-1_8; val=max(val,real(tens%data_real4(l0),8)); enddo
!$OMP END PARALLEL DO
	    tensor_block_max=val
	   else
	    ierr=2
	   endif
	  else
	   ierr=3
	  endif
	 case('r8')
	  if(allocated(tens%data_real8)) then
	   if(size(tens%data_real8).eq.tens%tensor_block_size) then
	    val=0d0
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED) REDUCTION(max:val)
	    do l0=0_8,tens%tensor_block_size-1_8; val=max(val,tens%data_real8(l0)); enddo
!$OMP END PARALLEL DO
	    tensor_block_max=val
	   else
	    ierr=4
	   endif
	  else
	   ierr=5
	  endif
	 case('c8')
	  if(allocated(tens%data_cmplx8)) then
	   if(size(tens%data_cmplx8).eq.tens%tensor_block_size) then
	    val=0d0
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED) REDUCTION(max:val)
	    do l0=0_8,tens%tensor_block_size-1_8; val=max(val,abs(tens%data_cmplx8(l0))); enddo
!$OMP END PARALLEL DO
	    tensor_block_max=val
	   else
	    ierr=6
	   endif
	  else
	   ierr=7
	  endif
	 end select
	elseif(tens%tensor_shape%num_dim.eq.0) then !scalar
	 tensor_block_max=abs(tens%scalar_value)
	else
	 ierr=-1
	endif
	return
	end function tensor_block_max
!-------------------------------------------------------------
	real(8) function tensor_block_min(tens,ierr,data_kind) !PARALLEL
!This function finds the smallest by modulus element in a tensor block.
!INPUT:
! - tens - tensor block;
! - data_kind - (optional) requested data kind;
!OUTPUT:
! - tensor_block_min - modulus of the min element(s);
! - ierr - error code (0:success).
	implicit none
	type(tensor_block_t), intent(inout):: tens !(out) because of <tensor_block_sync>
	character(2), intent(in), optional:: data_kind
	integer, intent(inout):: ierr
	character(2) dtk
	integer(8) l0
	real(8) val

	ierr=0
	if(tens%tensor_shape%num_dim.gt.0) then !true tensor
	 if(present(data_kind)) then; dtk=data_kind; else; dtk=tensor_master_data_kind(tens,ierr); if(ierr.ne.0) return; endif
	 if(dtk.ne.'r4'.and.dtk.ne.'r8'.and.dtk.ne.'c8') then; ierr=1; return; endif
	 select case(dtk)
	 case('r4')
	  if(allocated(tens%data_real4)) then
	   if(size(tens%data_real4).eq.tens%tensor_block_size) then
	    val=real(tens%data_real4(0),8)
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED) REDUCTION(min:val)
	    do l0=0_8,tens%tensor_block_size-1_8; val=min(val,real(tens%data_real4(l0),8)); enddo
!$OMP END PARALLEL DO
	    tensor_block_min=val
	   else
	    ierr=2
	   endif
	  else
	   ierr=3
	  endif
	 case('r8')
	  if(allocated(tens%data_real8)) then
	   if(size(tens%data_real8).eq.tens%tensor_block_size) then
	    val=tens%data_real8(0)
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED) REDUCTION(min:val)
	    do l0=0_8,tens%tensor_block_size-1_8; val=min(val,tens%data_real8(l0)); enddo
!$OMP END PARALLEL DO
	    tensor_block_min=val
	   else
	    ierr=4
	   endif
	  else
	   ierr=5
	  endif
	 case('c8')
	  if(allocated(tens%data_cmplx8)) then
	   if(size(tens%data_cmplx8).eq.tens%tensor_block_size) then
	    val=abs(tens%data_cmplx8(0))
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED) REDUCTION(min:val)
	    do l0=0_8,tens%tensor_block_size-1_8; val=min(val,abs(tens%data_cmplx8(l0))); enddo
!$OMP END PARALLEL DO
	    tensor_block_min=val
	   else
	    ierr=6
	   endif
	  else
	   ierr=7
	  endif
	 end select
	elseif(tens%tensor_shape%num_dim.eq.0) then !scalar
	 tensor_block_min=abs(tens%scalar_value)
	else
	 ierr=-1
	endif
	return
	end function tensor_block_min
!-----------------------------------------------------------------------
	subroutine tensor_block_slice(tens,slice,ext_beg,ierr,data_kind) !PARALLEL
!This subroutine extracts a slice from a tensor block (<slice> must be preallocated).
!INPUT:
! - tens - tensor block;
! - slice - tensor block which will contain the slice (its shape specifies the slice dimensions);
! - ext_beg(:) - beginning offset of each tensor dimension (numeration starts at 0);
! - data_kind - requested data_kind, one of {'r4','r8','c8'};
!OUTPUT:
! - slice - tensor block slice;
! - ierr - error code (0:success).
!NOTES:
! - <slice> must have the same layout as <tens>!
! - For scalar tensors, slicing reduces to copying the scalar value.
! - If no <data_kind> is specified, the highest possible will be used from <tens>.
! - <slice> is syncronized at the end.
	implicit none
	type(tensor_block_t), intent(inout):: tens !(out) because of <tensor_block_copy> because of <tensor_block_layout> because of <tensor_shape_ok>
	type(tensor_block_t), intent(inout):: slice
	integer, intent(in):: ext_beg(1:*)
	character(2), intent(in), optional:: data_kind
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n,ks,kf,tlt,slt
	integer(8) ls
	character(2) dtk

	ierr=0
	if(tens%tensor_shape%num_dim.eq.slice%tensor_shape%num_dim) then
	 n=tens%tensor_shape%num_dim
	 if(n.gt.0) then !true tensor
!Check and possibly adjust arguments:
	  ls=tensor_shape_size(slice,ierr); if(ierr.ne.0) return
	  if(slice%tensor_block_size.le.0_8.or.slice%tensor_block_size.ne.ls) then; ierr=6; return; endif !invalid size of the tensor slice
	  if(present(data_kind)) then; dtk=data_kind; else; dtk=tensor_master_data_kind(tens,ierr); if(ierr.ne.0) return; endif
	  select case(dtk)
	  case('r4')
	   if(.not.allocated(tens%data_real4)) then; ierr=7; return; endif
	   if(.not.allocated(slice%data_real4)) then; allocate(slice%data_real4(0:ls-1),STAT=ierr); if(ierr.ne.0) return; endif
	  case('r8')
	   if(.not.allocated(tens%data_real8)) then; ierr=8; return; endif
	   if(.not.allocated(slice%data_real8)) then; allocate(slice%data_real8(0:ls-1),STAT=ierr); if(ierr.ne.0) return; endif
	  case('c8')
	   if(.not.allocated(tens%data_cmplx8)) then; ierr=9; return; endif
	   if(.not.allocated(slice%data_cmplx8)) then; allocate(slice%data_cmplx8(0:ls-1),STAT=ierr); if(ierr.ne.0) return; endif
	  case default
	   ierr=5; return !invalid data kind
	  end select
!Check whether the slice is trivial:
	  kf=0
	  do i=1,n
	   if(ext_beg(i).lt.0.or.ext_beg(i).ge.tens%tensor_shape%dim_extent(i).or. &
	      slice%tensor_shape%dim_extent(i).le.0.or.ext_beg(i)+slice%tensor_shape%dim_extent(i)-1.ge.tens%tensor_shape%dim_extent(i)) then
	    ierr=2; return
	   endif
	   if(slice%tensor_shape%dim_extent(i).ne.tens%tensor_shape%dim_extent(i)) kf=1
	  enddo
!Slicing:
	  if(kf.eq.0) then !one-to-one copy
	   call tensor_block_copy(tens,slice,ierr); if(ierr.ne.0) return
	  else !true slicing
	   tlt=tensor_block_layout(tens,ierr); if(ierr.ne.0) return
	   slt=tensor_block_layout(slice,ierr,.true.); if(ierr.ne.0) return
	   if(slt.eq.tlt) then
	    select case(tlt)
	    case(dimension_led)
	     select case(dtk)
	     case('r4')
	      !`Enable
	     case('r8')
	      call tensor_block_slice_dlf(n,tens%data_real8,tens%tensor_shape%dim_extent, &
	                                  slice%data_real8,slice%tensor_shape%dim_extent,ext_beg,ierr); if(ierr.ne.0) return
	     case('c8')
	      !`Enable
	     end select
	    case(bricked_dense,bricked_ordered)
	     !`Future
	    case(sparse_list)
	     !`Future
	    case(compressed)
	     !`Future
	    case default
	     ierr=4; return !invalid tensor layout
	    end select
	    if(data_kind_sync) then; call tensor_block_sync(slice,dtk,ierr); if(ierr.ne.0) return; endif
	   else
	    ierr=3 !tensor layouts differ
	   endif
	  endif
	 elseif(n.eq.0) then !scalar
	  slice%scalar_value=tens%scalar_value
	 endif
	else
	 ierr=1 !tensor block and its slice have different ranks
	endif
	return
	end subroutine tensor_block_slice
!-----------------------------------------------------------------------
	subroutine tensor_block_insert(tens,slice,ext_beg,ierr,data_kind) !PARALLEL
!This subroutine inserts a slice into a tensor block.
!INPUT:
! - tens - tensor block;
! - slice - slice to be inserted;
! - ext_beg(:) - beginning offset of each tensor dimension (numeration starts at 0);
! - data_kind - requested data_kind, one of {'r4','r8','c8'};
!OUTPUT:
! - tens - modified tensor block;
! - ierr - error code (0:success).
!NOTES:
! - <slice> must have the same layout as <tens>!
! - For scalar tensors, insertion reduces to copying the scalar value.
! - If no <data_kind> is specified, the highest possible common data kind will be used.
! - <tens> is syncronized at the end.
	implicit none
	type(tensor_block_t), intent(inout):: tens
	type(tensor_block_t), intent(inout):: slice !(out) because of <tensor_block_copy> because of <tensor_block_layout> because of <tensor_shape_ok>
	integer, intent(in):: ext_beg(1:*)
	character(2), intent(in), optional:: data_kind
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n,ks,kf,tlt,slt
	integer(8) ls
	character(2) dtk,stk

	ierr=0
	if(tens%tensor_shape%num_dim.eq.slice%tensor_shape%num_dim) then
	 n=tens%tensor_shape%num_dim
	 if(n.gt.0) then !true tensor
!Check and possibly adjust arguments:
	  ls=tensor_shape_size(slice,ierr); if(ierr.ne.0) return
	  if(slice%tensor_block_size.le.0_8.or.slice%tensor_block_size.ne.ls) then; ierr=6; return; endif !invalid size of the tensor slice
	  stk=tensor_master_data_kind(slice,ierr); if(ierr.ne.0) return; if(stk.eq.'--') then; ierr=11; return; endif !empty slice
	  if(present(data_kind)) then; dtk=data_kind; else; dtk=tensor_common_data_kind(tens,slice,ierr); if(ierr.ne.0) return; endif
	  select case(dtk)
	  case('r4')
	   if(.not.allocated(tens%data_real4)) then; ierr=7; return; endif
	   if(.not.allocated(slice%data_real4)) then; call tensor_block_sync(slice,stk,ierr,'r4'); if(ierr.ne.0) return; endif
	  case('r8')
	   if(.not.allocated(tens%data_real8)) then; ierr=8; return; endif
	   if(.not.allocated(slice%data_real8)) then; call tensor_block_sync(slice,stk,ierr,'r8'); if(ierr.ne.0) return; endif
	  case('c8')
	   if(.not.allocated(tens%data_cmplx8)) then; ierr=9; return; endif
	   if(.not.allocated(slice%data_cmplx8)) then; call tensor_block_sync(slice,stk,ierr,'c8'); if(ierr.ne.0) return; endif
	  case('--')
	   dtk=tensor_master_data_kind(tens,ierr); if(ierr.ne.0) return
	   select case(dtk)
	   case('r4')
	    if(.not.allocated(slice%data_real4)) then; call tensor_block_sync(slice,stk,ierr,'r4'); if(ierr.ne.0) return; endif
	   case('r8')
	    if(.not.allocated(slice%data_real8)) then; call tensor_block_sync(slice,stk,ierr,'r8'); if(ierr.ne.0) return; endif
	   case('c8')
	    if(.not.allocated(slice%data_cmplx8)) then; call tensor_block_sync(slice,stk,ierr,'c8'); if(ierr.ne.0) return; endif
	   case default
	    ierr=10; return !no master data kind found in <tens>
	   end select
	  case default
	   ierr=5; return !invalid data kind
	  end select
!Check whether the slice is trivial:
	  kf=0
	  do i=1,n
	   if(ext_beg(i).lt.0.or.ext_beg(i).ge.tens%tensor_shape%dim_extent(i).or. &
	      slice%tensor_shape%dim_extent(i).le.0.or.ext_beg(i)+slice%tensor_shape%dim_extent(i)-1.ge.tens%tensor_shape%dim_extent(i)) then
	    ierr=2; return
	   endif
	   if(slice%tensor_shape%dim_extent(i).ne.tens%tensor_shape%dim_extent(i)) kf=1
	  enddo
!Insertion:
	  if(kf.eq.0) then !one-to-one copy
	   call tensor_block_copy(slice,tens,ierr); if(ierr.ne.0) return
	  else !true insertion
	   tlt=tensor_block_layout(tens,ierr); if(ierr.ne.0) return
	   slt=tensor_block_layout(slice,ierr,.true.); if(ierr.ne.0) return
	   if(slt.eq.tlt) then
	    select case(tlt)
	    case(dimension_led)
	     select case(dtk)
	     case('r4')
	      !`Enable
	     case('r8')
	      call tensor_block_insert_dlf(n,tens%data_real8,tens%tensor_shape%dim_extent, &
	                                   slice%data_real8,slice%tensor_shape%dim_extent,ext_beg,ierr); if(ierr.ne.0) return
	     case('c8')
	      !`Enable
	     end select
	    case(bricked_dense,bricked_ordered)
	     !`Future
	    case(sparse_list)
	     !`Future
	    case(compressed)
	     !`Future
	    case default
	     ierr=4; return !invalid tensor layout
	    end select
	    if(data_kind_sync) then; call tensor_block_sync(tens,dtk,ierr); if(ierr.ne.0) return; endif
	   else
	    ierr=3 !tensor layouts differ
	   endif
	  endif
	 elseif(n.eq.0) then !scalar
	  tens%scalar_value=slice%scalar_value
	 endif
	else
	 ierr=1 !tensor block and its slice have different ranks
	endif
	return
	end subroutine tensor_block_insert
!--------------------------------------------------------------------------------------------
	subroutine tensor_block_print(ifh,head_line,ext_beg,tens,ierr,data_kind,print_thresh) !SERIAL
!This subroutine prints all non-zero elements of a tensor block.
!INPUT:
! - ifh - output file handle;
! - head_line - header line;
! - ext_beg(1:) - beginnings for each dimension;
! - tens - tensor block;
! - data_kind - (optional) requested data kind;
! - print_thresh - printing threshold;
!OUTPUT:
! - Output in the file <ifh>;
! - ierr - error code (0:success).
	implicit none
	integer, intent(in):: ifh,ext_beg(1:*)
	character(*), intent(in):: head_line
	type(tensor_block_t), intent(inout):: tens !(out) because of <tensor_block_layout>
	character(2), intent(in), optional:: data_kind
	real(8), intent(in), optional:: print_thresh
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n,tst,im(1:max_tensor_rank)
	integer(8) l0,l1,bases(1:max_tensor_rank)
	character(2) dtk
	real(8) prth

	ierr=0
	write(ifh,'("#")',advance='no',err=2000)
	call printl(ifh,head_line(1:len_trim(head_line)))
	if(tens%tensor_shape%num_dim.ge.0.and.tens%tensor_shape%num_dim.le.max_tensor_rank) then
	 if(tens%tensor_shape%num_dim.gt.0) then !true tensor
	  if(present(data_kind)) then; dtk=data_kind; else; dtk=tensor_master_data_kind(tens,ierr); if(ierr.ne.0) return; endif
	  if(present(print_thresh)) then; prth=print_thresh; else; prth=abs_cmp_thresh; endif
	  tst=tensor_block_layout(tens,ierr); if(ierr.ne.0) return
	  select case(tst)
	  case(dimension_led)
	   l0=1_8; do i=1,tens%tensor_shape%num_dim; bases(i)=l0; l0=l0*tens%tensor_shape%dim_extent(i); enddo
	   if(l0.eq.tens%tensor_block_size) then
	    select case(dtk)
	    case('r4')
	     do l0=0_8,tens%tensor_block_size-1_8
	      if(abs(tens%data_real4(l0)).gt.real(prth,4)) then
	       im(1:tens%tensor_shape%num_dim)=ext_beg(1:tens%tensor_shape%num_dim)
	       l1=l0; do i=tens%tensor_shape%num_dim,1,-1; im(i)=im(i)+l1/bases(i); l1=mod(l1,bases(i)); enddo
	       write(ifh,'(D15.7,64(1x,i5))') tens%data_real4(l0),im(1:tens%tensor_shape%num_dim)
	      endif
	     enddo
	    case('r8')
	     do l0=0_8,tens%tensor_block_size-1_8
	      if(abs(tens%data_real8(l0)).gt.prth) then
	       im(1:tens%tensor_shape%num_dim)=ext_beg(1:tens%tensor_shape%num_dim)
	       l1=l0; do i=tens%tensor_shape%num_dim,1,-1; im(i)=im(i)+l1/bases(i); l1=mod(l1,bases(i)); enddo
	       write(ifh,'(D23.15,64(1x,i5))') tens%data_real8(l0),im(1:tens%tensor_shape%num_dim)
	      endif
	     enddo
	    case('c8')
	     do l0=0_8,tens%tensor_block_size-1_8
	      if(abs(tens%data_cmplx8(l0)).gt.prth) then
	       im(1:tens%tensor_shape%num_dim)=ext_beg(1:tens%tensor_shape%num_dim)
	       l1=l0; do i=tens%tensor_shape%num_dim,1,-1; im(i)=im(i)+l1/bases(i); l1=mod(l1,bases(i)); enddo
	       write(ifh,'("(",D23.15,",",D23.15,")",64(1x,i5))') tens%data_cmplx8(l0),im(1:tens%tensor_shape%num_dim)
	      endif
	     enddo
	    case default
	     ierr=3; return
	    end select
	   else
	    ierr=2; return
	   endif
	  case(bricked_dense,bricked_ordered)
	   !`Future
	  case(sparse_list)
	   !`Future
	  case(compressed)
	   !`Future
	  case default
	   ierr=4; return
	  end select
	 else !scalar
	  write(ifh,'("Complex scalar value = (",D23.15,",",D23.15,")")') tens%scalar_value
	 endif
	else
	 ierr=1; call printl(ifh,'ERROR(tensor_algebra::tensor_block_print): negative or too high tensor rank!')
	endif
	return
2000	ierr=-1; return
	end subroutine tensor_block_print
!-----------------------------------------------------------------------------------------
	subroutine tensor_block_trace(contr_ptrn,tens_in,tens_out,ierr,data_kind,ord_rest) !PARALLEL
!This subroutine executes an intra-tensor index contraction (accumulative partial or full trace):
!tens_out(:)+=TRACE(tens_in(:))
!INPUT:
! - contr_ptrn(1:input_rank) - index contraction pattern (similar to the one used by <tensor_block_contract>);
! - tens_in - input tensor block;
! - data_kind - (optional) requested data kind;
! - ord_rest(1:input_rank) - (optional) index ordering restrictions (for contracted indices only);
!OUTPUT:
! - tens_out - initialized! output tensor block (where the result of partial/full tracing will be accumulated);
! - ierr - error code (0:success).
!NOTES:
! - Both tensor blocks must have the same storage layout.
	implicit none
	integer, intent(in):: contr_ptrn(1:*)
	integer, intent(in), optional:: ord_rest(1:*)
	character(2), intent(in), optional:: data_kind
	type(tensor_block_t), intent(inout):: tens_in !(out) because of <tensor_block_layout>
	type(tensor_block_t), intent(inout):: tens_out
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n,ks,kf
	integer rank_in,rank_out,im(1:max_tensor_rank)
	integer(8) ls,l0
	character(2) dtk,slk,dlt
	logical cptrn_ok
	real(4) valr4
	real(8) valr8
	complex(8) valc8

	ierr=0
	rank_in=tens_in%tensor_shape%num_dim; rank_out=tens_out%tensor_shape%num_dim
	if(rank_in.gt.0.and.rank_out.ge.0.and.rank_out.le.rank_in) then
	 cptrn_ok=contr_ptrn_ok(contr_ptrn,rank_in,rank_out); if(present(ord_rest)) cptrn_ok=cptrn_ok.and.ord_rest_ok(ord_rest,contr_ptrn,rank_in,rank_out)
	 if(present(data_kind)) then; dtk=data_kind; else; dtk=tensor_master_data_kind(tens_in,ierr); if(ierr.ne.0) return; endif
	 if(dtk.ne.'r4'.and.dtk.ne.'r8'.and.dtk.ne.'c8') then; ierr=2; return; endif
	 ks=tensor_block_layout(tens_in,ierr); if(ierr.ne.0) return
	 kf=tensor_block_layout(tens_out,ierr); if(ierr.ne.0) return
	 if(ks.eq.kf.or.kf.eq.scalar_tensor) then !the same storage layout
	  select case(ks)
	  case(dimension_led)
	   select case(dtk)
	   case('r4')
	    !`Enable
	   case('r8')
	    if(allocated(tens_in%data_real8)) then
	     if(rank_out.gt.0.and.(.not.allocated(tens_out%data_real8))) then
	      slk=tensor_master_data_kind(tens_out,ierr); if(ierr.ne.0) return
	      if(slk.eq.'--') then; ierr=5; return; endif
	      dlt='r8'; call tensor_block_sync(tens_out,slk,ierr,dlt); if(ierr.ne.0) return
	     else
	      dlt='  '
	     endif
	     if(rank_out.gt.0) then !partial trace
	      call tensor_block_ptrace_dlf(contr_ptrn,ord_rest,tens_in%data_real8,rank_in,tens_in%tensor_shape%dim_extent,tens_out%data_real8,rank_out,tens_out%tensor_shape%dim_extent,ierr); if(ierr.ne.0) return
	     else !full trace
	      valr8=cmplx8_to_real8(tens_out%scalar_value)
	      call tensor_block_ftrace_dlf(contr_ptrn,ord_rest,tens_in%data_real8,rank_in,tens_in%tensor_shape%dim_extent,valr8,ierr); if(ierr.ne.0) return
	      tens_out%scalar_value=cmplx(valr8,0d0,8)
	     endif
	    else
	     ierr=6; return
	    endif
	   case('c8')
	    !`Enable
	   end select
	  case(bricked_dense,bricked_ordered)
	   !`Future
	  case(sparse_list)
	   !`Future
	  case(compressed)
	   !`Future
	  case default
	   ierr=4; return
	  end select
	  if(data_kind_sync) then; call tensor_block_sync(tens_out,dtk,ierr); if(ierr.ne.0) return; endif
	  if(dlt.ne.'  ') then; call tensor_block_sync(tens_out,dlt,ierr,'--'); if(ierr.ne.0) return; endif
	 else
	  ierr=3 !tensor storage layouts differ
	 endif
	elseif(rank_in.eq.0.and.rank_out.eq.0) then !two scalars
	 tens_out%scalar_value=tens_in%scalar_value
	else
	 ierr=1
	endif
	return
	contains

	 logical function contr_ptrn_ok(cptrn,rank_in,rank_out)
	 integer, intent(in):: rank_in,rank_out,cptrn(1:rank_in)
	 integer j0,j1,jbus(1:rank_out)
	 contr_ptrn_ok=.true.; jbus(1:rank_out)=0
	 do j0=1,rank_in
	  j1=cptrn(j0)
	  if(j1.gt.0) then !uncontracted index
	   if(j1.gt.rank_out) then; contr_ptrn_ok=.false.; return; endif
	   if(jbus(j1).ne.0) then; contr_ptrn_ok=.false.; return; else; jbus(j1)=jbus(j1)+1; endif
	   if(tens_in%tensor_shape%dim_extent(j0).ne.tens_out%tensor_shape%dim_extent(j1)) then; contr_ptrn_ok=.false.; return; endif
	  elseif(j1.lt.0) then !contracted index
	   if(-j1.gt.rank_in.or.-j1.eq.j0) then; contr_ptrn_ok=.false.; return; endif
	   if(cptrn(-j1).ne.-j0) then; contr_ptrn_ok=.false.; return; endif
	   if(tens_in%tensor_shape%dim_extent(j0).ne.tens_in%tensor_shape%dim_extent(-j1)) then; contr_ptrn_ok=.false.; return; endif
	  else
	   contr_ptrn_ok=.false.
	  endif
	 enddo
	 do j0=1,rank_out; if(jbus(j0).ne.1) then; contr_ptrn_ok=.false.; return; endif; enddo
	 return
	 end function contr_ptrn_ok

	 logical function ord_rest_ok(ordr,cptrn,rank_in,rank_out) !`Finish
	 integer, intent(in):: rank_in,rank_out,cptrn(1:rank_in),ordr(1:rank_in)
	 integer j0
	 ord_rest_ok=.true.
	 return
	 end function ord_rest_ok

	end subroutine tensor_block_trace
!----------------------------------------------------------------------------------------------
	logical function tensor_block_cmp(tens1,tens2,ierr,data_kind,rel,cmp_thresh,diff_count) !PARALLEL
!This function compares two tensor blocks.
!INPUT:
! - tens1, tens2 - two tensor blocks to compare;
! - data_kind - (optional) requested data kind, one of {'r4','r8','c8'};
! - rel - if .true., a relative comparison will be invoked: DIFF(a,b)/ABSMAX(a,b), (default=.false.,absolute comparison);
! - cmp_thresh - (optional) numerical comparison threshold (real8);
!OUTPUT:
! - tensor_block_cmp = .true. if tens1 = tens2 to within the given tolerance, .false. otherwise;
! - diff_count - (optional) number of elements that differ (only for compatible tensors with the same layout);
! - ierr - error code (0:success);
!NOTES:
! - The two tensor blocks must have the same storage layout.
! - If <data_kind> is not specified explicitly, this function will try to use the <tensor_common_data_kind>;
!   if the latter does not exist, the result will be .false.!
	implicit none
	type(tensor_block_t), intent(inout):: tens1,tens2 !(out) because of <tensor_block_layout>
	character(2), intent(in), optional:: data_kind
	logical, intent(in), optional:: rel
	real(8), intent(in), optional:: cmp_thresh
	integer(8), intent(out), optional:: diff_count
	integer, intent(inout):: ierr
!-------------------------------------------------
	integer(8), parameter:: chunk_size=2**17 !chunk size
!-------------------------------------------------
	integer i,j,k,l,m,n,k0,k1,k2,k3,ks,kf
	integer(8) l0,l1,l2,diffc
	character(2) dtk
	real(4) cmp_thr4,f1,f2
	real(8) cmp_thr8,d1,d2
	logical no_exit,rel_comp

	ierr=0
	if(present(rel)) then; rel_comp=rel; else; rel_comp=.false.; endif !default is the absolute comparison (not relative)
	if(present(cmp_thresh)) then
	 cmp_thr8=cmp_thresh
	else
	 if(rel_comp) then; cmp_thr8=rel_cmp_thresh; else; cmp_thr8=abs_cmp_thresh; endif
	endif
	if(present(diff_count)) then; diff_count=0_8; no_exit=.true.; else; no_exit=.false.; endif
	tensor_block_cmp=tensor_block_compatible(tens1,tens2,ierr,no_check_data_kinds=.true.); if(ierr.ne.0) then; ierr=1; tensor_block_cmp=.false.; return; endif
	if(tensor_block_cmp.and.tens1%tensor_shape%num_dim.gt.0) then !two tensors
	 k1=tensor_block_layout(tens1,ierr); if(ierr.ne.0) then; ierr=2; return; endif
	 k2=tensor_block_layout(tens2,ierr); if(ierr.ne.0) then; ierr=3; return; endif
	 if(k1.ne.k2) then; tensor_block_cmp=.false.; ierr=4; return; endif !storage layouts differ
	 if(present(data_kind)) then !find common data kind
	  dtk=data_kind
	 else
	  dtk=tensor_common_data_kind(tens1,tens2,ierr); if(ierr.ne.0) then; ierr=5; tensor_block_cmp=.false.; return; endif
	 endif
	 diffc=0_8
	 select case(k1)
	 case(not_allocated,scalar_tensor) !this case is treated separately
	  tensor_block_cmp=.false.; ierr=6
	 case(dimension_led,bricked_dense,bricked_ordered)
	  select case(dtk)
	  case('--') !tensor blocks do not have a common data kind (cannot be directly compared)
	   tensor_block_cmp=.false.
	  case('r4')
	   cmp_thr4=real(cmp_thr8,4)
	   if(allocated(tens1%data_real4).and.allocated(tens2%data_real4)) then
	    l1=size(tens1%data_real4); l2=size(tens2%data_real4)
	    if(l1.eq.l2.and.l1.eq.tens1%tensor_block_size.and.l1.eq.tens2%tensor_block_size.and.l1.gt.0) then
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(l0,l2) FIRSTPRIVATE(cmp_thr4) REDUCTION(+:diffc)
	     do l0=0_8,l1-1_8,chunk_size
	      if(rel_comp) then !relative
!$OMP DO SCHEDULE(GUIDED)
	       do l2=l0,min(l0+chunk_size-1_8,l1-1_8)
	        f1=abs(tens1%data_real4(l2)); f2=abs(tens2%data_real4(l2))
	        if(abs(tens1%data_real4(l2)-tens2%data_real4(l2))/max(f1,f2).gt.cmp_thr4) diffc=diffc+1_8
	       enddo
!$OMP END DO
	      else !absolute
!$OMP DO SCHEDULE(GUIDED)
	       do l2=l0,min(l0+chunk_size-1_8,l1-1_8)
	        if(abs(tens1%data_real4(l2)-tens2%data_real4(l2)).gt.cmp_thr4) diffc=diffc+1_8
	       enddo
!$OMP END DO
	      endif
!$OMP CRITICAL
	      if(diffc.gt.0_8.and.tensor_block_cmp) tensor_block_cmp=.false.
!$OMP END CRITICAL
!$OMP BARRIER
!$OMP FLUSH(tensor_block_cmp)
	      if(.not.(tensor_block_cmp.or.no_exit)) exit
	     enddo
!$OMP END PARALLEL
	    else
	     tensor_block_cmp=.false.; ierr=7
	    endif
	   else
	    tensor_block_cmp=.false.; ierr=8
	   endif
	  case('r8')
	   if(allocated(tens1%data_real8).and.allocated(tens2%data_real8)) then
	    l1=size(tens1%data_real8); l2=size(tens2%data_real8)
	    if(l1.eq.l2.and.l1.eq.tens1%tensor_block_size.and.l1.eq.tens2%tensor_block_size.and.l1.gt.0) then
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(l0,l2) FIRSTPRIVATE(cmp_thr8) REDUCTION(+:diffc)
	     do l0=0_8,l1-1_8,chunk_size
	      if(rel_comp) then !relative
!$OMP DO SCHEDULE(GUIDED)
	       do l2=l0,min(l0+chunk_size-1_8,l1-1_8)
	        d1=abs(tens1%data_real8(l2)); d2=abs(tens2%data_real8(l2))
	        if(abs(tens1%data_real8(l2)-tens2%data_real8(l2))/max(d1,d2).gt.cmp_thr8) diffc=diffc+1_8
	       enddo
!$OMP END DO
	      else !absolute
!$OMP DO SCHEDULE(GUIDED)
	       do l2=l0,min(l0+chunk_size-1_8,l1-1_8)
	        if(abs(tens1%data_real8(l2)-tens2%data_real8(l2)).gt.cmp_thr8) diffc=diffc+1_8
	       enddo
!$OMP END DO
	      endif
!$OMP CRITICAL
	      if(diffc.gt.0_8.and.tensor_block_cmp) tensor_block_cmp=.false.
!$OMP END CRITICAL
!$OMP BARRIER
!$OMP FLUSH(tensor_block_cmp)
	      if(.not.(tensor_block_cmp.or.no_exit)) exit
	     enddo
!$OMP END PARALLEL
	    else
	     tensor_block_cmp=.false.; ierr=9
	    endif
	   else
	    tensor_block_cmp=.false.; ierr=10
	   endif
	  case('c8')
	   if(allocated(tens1%data_cmplx8).and.allocated(tens2%data_cmplx8)) then
	    l1=size(tens1%data_cmplx8); l2=size(tens2%data_cmplx8)
	    if(l1.eq.l2.and.l1.eq.tens1%tensor_block_size.and.l1.eq.tens2%tensor_block_size.and.l1.gt.0) then
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(l0,l2) FIRSTPRIVATE(cmp_thr8)
	     do l0=0_8,l1-1_8,chunk_size
	      if(rel_comp) then !relative
!$OMP DO SCHEDULE(GUIDED)
	       do l2=l0,min(l0+chunk_size-1_8,l1-1_8)
	        d1=abs(tens1%data_cmplx8(l2)); d2=abs(tens2%data_cmplx8(l2))
	        if(abs(tens1%data_cmplx8(l2)-tens2%data_cmplx8(l2))/max(d1,d2).gt.cmp_thr8) diffc=diffc+1_8
	       enddo
!$OMP END DO
	      else !absolute
!$OMP DO SCHEDULE(GUIDED)
	       do l2=l0,min(l0+chunk_size-1_8,l1-1_8)
	        if(abs(tens1%data_cmplx8(l2)-tens2%data_cmplx8(l2)).gt.cmp_thr8) diffc=diffc+1_8
	       enddo
!$OMP END DO
	      endif
!$OMP CRITICAL
	      if(diffc.gt.0_8.and.tensor_block_cmp) tensor_block_cmp=.false.
!$OMP END CRITICAL
!$OMP BARRIER
!$OMP FLUSH(tensor_block_cmp)
	      if(.not.(tensor_block_cmp.or.no_exit)) exit
	     enddo
!$OMP END PARALLEL
	    else
	     tensor_block_cmp=.false.; ierr=11
	    endif
	   else
	    tensor_block_cmp=.false.; ierr=12
	   endif
	  case default
	   tensor_block_cmp=.false.; ierr=-1
	  end select
	 case(sparse_list)
	  !`Future
	 case(compressed)
	  !`Future
	 case default
	  tensor_block_cmp=.false.; ierr=13
	 end select
	 if(present(diff_count)) diff_count=diffc
	elseif(tensor_block_cmp.and.tens1%tensor_shape%num_dim.eq.0) then !two scalars
	 if(rel_comp) then !relative
	  if(abs(tens1%scalar_value-tens2%scalar_value)/max(abs(tens1%scalar_value),abs(tens2%scalar_value)).gt.cmp_thr8) then
	   tensor_block_cmp=.false.; if(present(diff_count)) diff_count=1_8
	  endif
	 else !absolute
	  if(abs(tens1%scalar_value-tens2%scalar_value).gt.cmp_thr8) then
	   tensor_block_cmp=.false.; if(present(diff_count)) diff_count=1_8
	  endif
	 endif
	endif
	return
	end function tensor_block_cmp
!-----------------------------------------------------------------
	subroutine tensor_block_copy(tens_in,tens_out,ierr,transp) !PARALLEL
!This subroutine makes a copy of a tensor block with an optional index permutation.
!INPUT:
! - tens_in - input tensor;
! - transp(0:*) - O2N index permutation (optional);
!OUTPUT:
! - tens_out - output tensor;
! - ierr - error code (0:success).
!NOTE:
! - All allocated data kinds will be copied (no further sync is required).
	implicit none
	type(tensor_block_t), intent(inout):: tens_in !(out) because of <tensor_block_layout> because of <tensor_shape_ok>
	type(tensor_block_t), intent(inout):: tens_out
	integer, intent(in), optional:: transp(0:*)
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n,k0,k1,k2,k3,ks,kf
	integer trn(0:max_tensor_rank)
	logical compat,trivial

	ierr=0; n=tens_in%tensor_shape%num_dim
	if(n.gt.0) then !true tensor
	 if(present(transp)) then
	  trn(0:n)=transp(0:n); if(.not.perm_ok(n,trn)) then; ierr=1; return; endif
	  trivial=perm_trivial(n,trn)
	 else
	  trn(0:n)=(/+1,(j,j=1,n)/); trivial=.true.
	 endif
!Check tensor block shapes:
	 compat=tensor_block_compatible(tens_in,tens_out,ierr,trn); if(ierr.ne.0) return
	 if(.not.compat) then; call tensor_block_mimic(tens_in,tens_out,ierr); if(ierr.ne.0) return; endif
!Scalar value:
	 tens_out%scalar_value=tens_in%scalar_value
!Tensor shape:
	 tens_out%tensor_shape%dim_extent(trn(1:n))=tens_in%tensor_shape%dim_extent(1:n)
	 tens_out%tensor_shape%dim_divider(trn(1:n))=tens_in%tensor_shape%dim_divider(1:n)
	 tens_out%tensor_shape%dim_group(trn(1:n))=tens_in%tensor_shape%dim_group(1:n)
!Determine the tensor block storage layout:
	 ks=tensor_block_layout(tens_in,ierr); if(ierr.ne.0) return
	 kf=tensor_block_layout(tens_out,ierr); if(ierr.ne.0) return
	 if(ks.ne.kf) then; ierr=2; return; endif !tensor block storage layouts differ
	 if(trivial) ks=dimension_led !for a direct copy the storage layout is irrelevant
	 select case(ks)
	 case(dimension_led)
!Data:
 !REAL4:
	  if(allocated(tens_in%data_real4)) then
	   if(tens_in%tensor_block_size.gt.1_8) then
	    if(trans_shmem) then
	     call tensor_block_copy_dlf(n,tens_in%tensor_shape%dim_extent,trn,tens_in%data_real4,tens_out%data_real4,ierr); if(ierr.ne.0) return
	    else
	     call tensor_block_copy_scatter_dlf(n,tens_in%tensor_shape%dim_extent,trn,tens_in%data_real4,tens_out%data_real4,ierr); if(ierr.ne.0) return
	    endif
	   elseif(tens_in%tensor_block_size.eq.1_8) then
	    tens_out%data_real4(0)=tens_in%data_real4(0)
	   else
	    ierr=3; return
	   endif
	  endif
 !REAL8:
	  if(allocated(tens_in%data_real8)) then
	   if(tens_in%tensor_block_size.gt.1_8) then
	    if(trans_shmem) then
	     call tensor_block_copy_dlf(n,tens_in%tensor_shape%dim_extent,trn,tens_in%data_real8,tens_out%data_real8,ierr); if(ierr.ne.0) return
	    else
	     call tensor_block_copy_scatter_dlf(n,tens_in%tensor_shape%dim_extent,trn,tens_in%data_real8,tens_out%data_real8,ierr); if(ierr.ne.0) return
	    endif
	   elseif(tens_in%tensor_block_size.eq.1_8) then
	    tens_out%data_real8(0)=tens_in%data_real8(0)
	   else
	    ierr=4; return
	   endif
	  endif
 !COMPLEX8:
	  !`Enable other data types ('c8')
	 case(bricked_dense,bricked_ordered)
	  !`Future
	 case(sparse_list)
	  !`Future
	 case(compressed)
	  !`Future
	 case default
	  ierr=-1; return
	 end select
	elseif(n.eq.0) then !scalar (0-dimension tensor)
	 if(tens_out%tensor_shape%num_dim.gt.0) then; call tensor_block_destroy(tens_out,ierr); if(ierr.ne.0) return; endif
	 tens_out%tensor_shape%num_dim=0; tens_out%tensor_block_size=tens_in%tensor_block_size; tens_out%scalar_value=tens_in%scalar_value
	else !tens_in%tensor_shape%num_dim<0
	 call tensor_block_destroy(tens_out,ierr); if(ierr.ne.0) return
	endif
	return
	end subroutine tensor_block_copy
!------------------------------------------------------------------------
	subroutine tensor_block_add(tens0,tens1,ierr,scale_fac,data_kind) !PARALLEL
!This subroutine adds tensor block <tens1> to tensor block <tens0>:
!tens0(:)+=tens1(:)*scale_fac
!INPUT:
! - tens0, tens1 - initialized! tensor blocks;
! - scale_fac - (optional) scaling factor;
! - data_kind - (optional) requested data kind, one of {'r4','r8','c8'};
!OUTPUT:
! - tens0 - modified tensor block;
! - ierr - error code (0:success);
!NOTES:
! - If the <data_kind> is not specified explicitly, then all common data kinds will be processed;
!   otherwise, the data kinds syncronization will be invoked.
! - Not-allocated (still compatible) tensor blocks will be simply ignored.
	implicit none
	type(tensor_block_t), intent(inout):: tens0
	type(tensor_block_t), intent(inout):: tens1 !(out) because <tens1> might need data kinds syncronization to become compatible with <tens0>
	complex(8), intent(in), optional:: scale_fac
	character(2), intent(in), optional:: data_kind
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n,ks,kf
	integer(8) l0,l1,ls
	character(2) dtk,slk,dlt
	logical tencom,scale_present
	real(4) val_r4
	real(8) val_r8
	complex(8) val_c8

	ierr=0
	ks=tensor_block_layout(tens0,ierr); if(ierr.ne.0) return
	kf=tensor_block_layout(tens1,ierr); if(ierr.ne.0) return
	if(ks.ne.kf) then; ierr=1; return; endif !tensor storage layouts differ
	if(present(scale_fac)) then; val_c8=scale_fac; scale_present=.true.; else; val_c8=cmplx(1d0,0d0,8); scale_present=.false.; endif
	if(present(data_kind)) then; dtk=data_kind; else; dtk='  '; endif
	tencom=tensor_block_compatible(tens0,tens1,ierr,no_check_data_kinds=.true.); if(ierr.ne.0) return
	if(tencom) then
	 if(tens0%tensor_shape%num_dim.eq.0) then !scalars
	  tens0%scalar_value=tens0%scalar_value+tens1%scalar_value*val_c8
	 elseif(tens0%tensor_shape%num_dim.gt.0) then !true tensors
	  select case(ks)
	  case(dimension_led,bricked_dense,bricked_ordered)
	   ls=tens0%tensor_block_size
	   if(ls.gt.0_8) then
 !REAL4:
	    if(dtk.eq.'r4'.or.dtk.eq.'  ') then
	     if(allocated(tens0%data_real4)) then
	      if(.not.allocated(tens1%data_real4)) then
	       slk=tensor_master_data_kind(tens1,ierr); if(ierr.ne.0) return
	       if(slk.eq.'--') then; ierr=2; return; endif
	       dlt='r4'; call tensor_block_sync(tens1,slk,ierr,dlt); if(ierr.ne.0) return
	      else
	       dlt='  '
	      endif
	      if(size(tens0%data_real4).eq.ls.and.tens1%tensor_block_size.eq.ls) then
	       if(scale_present) then !scaling present
	        val_r4=real(cmplx8_to_real8(val_c8),4)
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED) FIRSTPRIVATE(val_r4)
	        do l0=0_8,ls-1_8; tens0%data_real4(l0)=tens0%data_real4(l0)+tens1%data_real4(l0)*val_r4; enddo
!$OMP END PARALLEL DO
	       else !no scaling
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED)
	        do l0=0_8,ls-1_8; tens0%data_real4(l0)=tens0%data_real4(l0)+tens1%data_real4(l0); enddo
!$OMP END PARALLEL DO
	       endif
	       if(dlt.ne.'  ') then; call tensor_block_sync(tens1,dlt,ierr,'--'); if(ierr.ne.0) return; endif
	      else
	       ierr=3; return
	      endif
	     else
	      if(dtk.eq.'r4') then; ierr=4; return; endif
	     endif
	    endif
 !REAL8:
	    if(dtk.eq.'r8'.or.dtk.eq.'  ') then
	     if(allocated(tens0%data_real8)) then
	      if(.not.allocated(tens1%data_real8)) then
	       slk=tensor_master_data_kind(tens1,ierr); if(ierr.ne.0) return
	       if(slk.eq.'--') then; ierr=5; return; endif
	       dlt='r8'; call tensor_block_sync(tens1,slk,ierr,dlt); if(ierr.ne.0) return
	      else
	       dlt='  '
	      endif
	      if(size(tens0%data_real8).eq.ls.and.tens1%tensor_block_size.eq.ls) then
	       if(scale_present) then !scaling present
	        val_r8=cmplx8_to_real8(val_c8)
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED) FIRSTPRIVATE(val_r8)
	        do l0=0_8,ls-1_8; tens0%data_real8(l0)=tens0%data_real8(l0)+tens1%data_real8(l0)*val_r8; enddo
!$OMP END PARALLEL DO
	       else !no scaling
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED)
	        do l0=0_8,ls-1_8; tens0%data_real8(l0)=tens0%data_real8(l0)+tens1%data_real8(l0); enddo
!$OMP END PARALLEL DO
	       endif
	       if(dlt.ne.'  ') then; call tensor_block_sync(tens1,dlt,ierr,'--'); if(ierr.ne.0) return; endif
	      else
	       ierr=6; return
	      endif
	     else
	      if(dtk.eq.'r8') then; ierr=7; return; endif
	     endif
	    endif
 !COMPLEX8:
	    if(dtk.eq.'c8'.or.dtk.eq.'  ') then
	     if(allocated(tens0%data_cmplx8)) then
	      if(.not.allocated(tens1%data_cmplx8)) then
	       slk=tensor_master_data_kind(tens1,ierr); if(ierr.ne.0) return
	       if(slk.eq.'--') then; ierr=8; return; endif
	       dlt='c8'; call tensor_block_sync(tens1,slk,ierr,dlt); if(ierr.ne.0) return
	      else
	       dlt='  '
	      endif
	      if(size(tens0%data_cmplx8).eq.ls.and.tens1%tensor_block_size.eq.ls) then
	       if(scale_present) then !scaling present
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED) FIRSTPRIVATE(val_c8)
	        do l0=0_8,ls-1_8; tens0%data_cmplx8(l0)=tens0%data_cmplx8(l0)+tens1%data_cmplx8(l0)*val_c8; enddo
!$OMP END PARALLEL DO
	       else !no scaling
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED)
	        do l0=0_8,ls-1_8; tens0%data_cmplx8(l0)=tens0%data_cmplx8(l0)+tens1%data_cmplx8(l0); enddo
!$OMP END PARALLEL DO
	       endif
	       if(dlt.ne.'  ') then; call tensor_block_sync(tens1,dlt,ierr,'--'); if(ierr.ne.0) return; endif
	      else
	       ierr=9; return
	      endif
	     else
	      if(dtk.eq.'c8') then; ierr=10; return; endif
	     endif
	    endif
!Sync the destination tensor:
	    if(dtk.ne.'  ') then
	     if(data_kind_sync) then; call tensor_block_sync(tens0,dtk,ierr); if(ierr.ne.0) return; endif
	    else
	     slk=tensor_master_data_kind(tens0,ierr); if(ierr.ne.0) return
	     if(slk.eq.'--') then; ierr=11; return; endif
	     val_r8=tensor_block_norm2(tens0,ierr,slk); if(ierr.ne.0) return
	     tens0%scalar_value=cmplx(dsqrt(val_r8),0d0,8) !Euclidean norm of the destination tensor block
	    endif
	   else
	    ierr=12 !%tensor_block_size less or equal to zero for an allocated tensor block
	   endif
	  case(sparse_list)
	   !`Future
	  case(compressed)
	   !`Future
	  case default
	   ierr=13 !invalid storage layout
	  end select
	 endif
	else
	 ierr=14 !incompatible shapes of the tensor blocks
	endif
	return
	end subroutine tensor_block_add
!---------------------------------------------------------------------------------------------
	subroutine tensor_block_contract(contr_ptrn,ltens,rtens,dtens,ierr,data_kind,ord_rest) !PARALLEL
!This subroutine contracts two tensor blocks and accumulates the result into another tensor block:
!dtens(:)+=ltens(:)*rtens(:)
!Author: Dmitry I. Lyakh (Dmytro I. Liakh): quant4me@gmail.com
!Possible cases:
! A) tensor+=tensor*tensor (no traces!): all tensor operands can be transposed;
! B) scalar+=tensor*tensor (no traces!): only the left tensor operand can be transposed;
! C) tensor+=tensor*scalar OR tensor+=scalar*tensor (no traces!): no transpose;
! D) scalar+=scalar*scalar: no transpose.
!INPUT:
! - contr_ptrn(1:left_rank+right_rank) - contraction pattern:
!                                        contr_ptrn(1:left_rank) refers to indices of the left tensor argument;
!                                        contr_ptrn(left_rank+1:left_rank+right_rank) refers to indices of the right tensor argument;
!                                        contr_ptrn(x)>0 means that the index is uncontracted and shows the position where it goes;
!                                        contr_ptrn(x)<0 means that the index is contracted and shows the position in the other argument where it is located.
! - ltens - left tensor argument (tensor block);
! - rtens - right tensor argument (tensor block);
! - dtens - initialized! destination tensor argument (tensor block);
! - data_kind - (optional) requested data kind, one of {'r4','r8','c8'};
! - ord_rest(1:left_rank+right_rank) - (optional) index ordering restrictions (for contracted indices only);
!OUTPUT:
! - dtens - modified destination tensor (tensor block);
! - ierr - error code (0: success);
!NOTES:
! - If <data_kind> is not specified then only the highest present data kind will be processed
!   whereas the present lower-level data kinds of the destination tensor will be syncronized.
	implicit none
	integer, intent(in):: contr_ptrn(1:*)
	integer, intent(in), optional:: ord_rest(1:*)
	character(2), intent(in), optional:: data_kind
	type(tensor_block_t), intent(inout), target:: ltens,rtens !(out) because of <tensor_block_layout> because of <tensor_shape_ok>
	type(tensor_block_t), intent(inout), target:: dtens
	integer, intent(inout):: ierr
!------------------------------------------------
	integer, parameter:: partial_contraction=1
	integer, parameter:: full_contraction=2
	integer, parameter:: add_tensor=3
	integer, parameter:: multiply_scalars=4
!------------------------------------------------
	integer i,j,k,l,m,n,k0,k1,k2,k3,ks,kf
	integer(8) l0,l1,l2,l3,lld,lrd,lcd
	integer ltb,rtb,dtb,lrank,rrank,drank,nlu,nru,ncd,tst,contr_case,dn2o(0:max_tensor_rank)
	integer, target:: lo2n(0:max_tensor_rank),ro2n(0:max_tensor_rank),do2n(0:max_tensor_rank)
	integer, pointer:: trn(:)
	type(tensor_block_t), pointer:: tens_in,tens_out,ltp,rtp,dtp
	type(tensor_block_t), target:: lta,rta,dta
	character(2) dtk
	real(4) d_r4,start_dgemm
	real(8) d_r8
	complex(8) d_c8
	logical contr_ok,ltransp,rtransp,dtransp,transp

	ierr=0
!Get the argument types:
	ltb=tensor_block_layout(ltens,ierr); if(ierr.ne.0) return !left-tensor storage layout type
	rtb=tensor_block_layout(rtens,ierr); if(ierr.ne.0) return !right-tensor storage layout type
	dtb=tensor_block_layout(dtens,ierr); if(ierr.ne.0) return !destination-tensor storage layout type
!Determine the contraction case:
	if(ltb.eq.not_allocated.or.rtb.eq.not_allocated.or.dtb.eq.not_allocated) then; ierr=1; return; endif
	if(ltb.eq.scalar_tensor.and.rtb.eq.scalar_tensor.and.dtb.eq.scalar_tensor) then !multiplication of scalars
	 contr_case=multiply_scalars
	elseif((ltb.ne.scalar_tensor.and.rtb.eq.scalar_tensor.and.dtb.ne.scalar_tensor).or. &
	       (ltb.eq.scalar_tensor.and.rtb.ne.scalar_tensor.and.dtb.ne.scalar_tensor)) then
	 contr_case=add_tensor
	elseif(ltb.ne.scalar_tensor.and.rtb.ne.scalar_tensor.and.dtb.eq.scalar_tensor) then
	 contr_case=full_contraction
	elseif(ltb.ne.scalar_tensor.and.rtb.ne.scalar_tensor.and.dtb.ne.scalar_tensor) then
	 contr_case=partial_contraction
	else
	 ierr=2; return
	endif
!Check tensor ranks:
	lrank=ltens%tensor_shape%num_dim; rrank=rtens%tensor_shape%num_dim; drank=dtens%tensor_shape%num_dim
	if(lrank.ge.0.and.lrank.le.max_tensor_rank.and.rrank.ge.0.and.rrank.le.max_tensor_rank.and.drank.ge.0.and.drank.le.max_tensor_rank) then
	 if(present(data_kind)) then; dtk=data_kind; else; call determine_data_kind(dtk,ierr); if(ierr.ne.0) return; endif
 !Check the requested contraction pattern:
	 contr_ok=contr_ptrn_ok(contr_ptrn,lrank,rrank,drank)
	 if(present(ord_rest)) contr_ok=contr_ok.and.ord_rest_ok(ord_rest,contr_ptrn,lrank,rrank,drank)
	 if(.not.contr_ok) then; ierr=3; return; endif
!	 write(cons_out,'("DEBUG(tensor_algebra::tensor_block_contract): contraction pattern accepted:",128(1x,i2))') contr_ptrn(1:lrank+rrank) !debug
!	 write(cons_out,'("DEBUG(tensor_algebra::tensor_block_contract): tensor layouts (left, right, dest): ",i2,1x,i2,1x,i2)') ltb,rtb,dtb !debug
 !Determine index permutations for all tensor operands together with the numbers of contracted/uncontraced indices (ncd/{nlu,nru}):
	 call determine_index_permutations !sets {dtransp,ltransp,rtransp},{do2n,lo2n,ro2n},{ncd,nlu,nru}
!	 write(cons_out,'("DEBUG(tensor_algebra::tensor_block_contract): left uncontr, right uncontr, contr dims: ",i2,1x,i2,1x,i2)') nlu,nru,ncd !debug
!	 write(cons_out,'("DEBUG(tensor_algebra::tensor_block_contract): left index permutation (O2N)  :",128(1x,i2))') lo2n(1:lrank) !debug
!	 write(cons_out,'("DEBUG(tensor_algebra::tensor_block_contract): right index permutation (O2N) :",128(1x,i2))') ro2n(1:rrank) !debug
!	 write(cons_out,'("DEBUG(tensor_algebra::tensor_block_contract): result index permutation (O2N):",128(1x,i2))') do2n(1:drank) !debug
 !Transpose the tensor arguments, if needed:
	 do k=1,2 !left/right switch
	  if(k.eq.1) then; tst=ltb; transp=ltransp; tens_in=>ltens; else; tst=rtb; transp=rtransp; tens_in=>rtens; endif
	  if(tens_in%tensor_shape%num_dim.gt.0.and.transp) then !true tensor which requires a transpose
!	   write(cons_out,'("DEBUG(tensor_algebra::tensor_block_contract): permutation to be performed for ",i2)') k !debug
	   if(k.eq.1) then; trn=>lo2n; tens_out=>lta; else; trn=>ro2n; tens_out=>rta; endif
	   select case(tst)
	   case(scalar_tensor)
	   case(dimension_led)
	    call tensor_block_copy(tens_in,tens_out,ierr,trn); if(ierr.ne.0) goto 999
	   case(bricked_dense,bricked_ordered)
	    !`Future
	   case(sparse_list)
	    !`Future
	   case(compressed)
	    !`Future
	   case default
	    ierr=4; goto 999
	   end select
	   if(k.eq.1) then; ltp=>lta; else; rtp=>rta; endif
	   nullify(tens_out); nullify(trn)
	  elseif(tens_in%tensor_shape%num_dim.eq.0.or.(.not.transp)) then !scalar tensor or no transpose required
	   if(k.eq.1) then; ltp=>ltens; else; rtp=>rtens; endif
	  else
	   ierr=5; goto 999
	  endif
	  nullify(tens_in)
	 enddo !k
	 if(dtransp) then !a transpose required for the destination tensor
!	  write(cons_out,'("DEBUG(tensor_algebra::tensor_block_contract): permutation to be performed for ",i2)') 0 !debug
	  dn2o(0)=+1; do k=1,drank; dn2o(do2n(k))=k; enddo
	  call tensor_block_copy(dtens,dta,ierr,dn2o); if(ierr.ne.0) goto 999
	  dtp=>dta
	 else !no transpose for the destination tensor
	  dtp=>dtens
	 endif
!	 write(cons_out,'("DEBUG(tensor_algebra::tensor_block_contract): arguments are ready to be processed!")') !debug
 !Calculate matrix dimensions:
!	 write(cons_out,'("DEBUG(tensor_algebra::tensor_block_contract): argument pointer status (l,r,d): ",l1,1x,l1,1x,l1)') associated(ltp),associated(rtp),associated(dtp) !debug
!	 write(cons_out,'("DEBUG(tensor_algebra::tensor_block_contract): left index extents  :",128(1x,i4))') ltp%tensor_shape%dim_extent(1:lrank) !debug
!	 write(cons_out,'("DEBUG(tensor_algebra::tensor_block_contract): right index extents :",128(1x,i4))') rtp%tensor_shape%dim_extent(1:rrank) !debug
!	 write(cons_out,'("DEBUG(tensor_algebra::tensor_block_contract): result index extents:",128(1x,i4))') dtp%tensor_shape%dim_extent(1:drank) !debug
	 call calculate_matrix_dimensions(dtb,nlu,nru,dtp,lld,lrd,ierr); if(ierr.ne.0) goto 999
	 call calculate_matrix_dimensions(ltb,ncd,nlu,ltp,lcd,l0,ierr); if(ierr.ne.0) goto 999
	 call calculate_matrix_dimensions(rtb,ncd,nru,rtp,l1,l2,ierr); if(ierr.ne.0) goto 999
!	 write(cons_out,'("DEBUG(tensor_algebra::tensor_block_contract): matrix dimensions (left,right,contr): ",i10,1x,i10,1x,i10)') lld,lrd,lcd !debug
	 if(l0.ne.lld.or.l1.ne.lcd.or.l2.ne.lrd) then; ierr=6; goto 999; endif
 !Multiply two matrices (ltp & rtp):
!	 start_dgemm=secnds(0.) !debug
	 select case(contr_case)
	 case(partial_contraction) !destination is an array
	  select case(dtk)
	  case('r4')
#ifdef NO_BLAS
	   call tensor_block_pcontract_dlf(lld,lrd,lcd,ltp%data_real4,rtp%data_real4,dtp%data_real4,ierr); if(ierr.ne.0) goto 999
#else
	   if(.not.disable_blas) then
	    call sgemm('T','N',int(lld,4),int(lrd,4),int(lcd,4),1.0,ltp%data_real4,int(lcd,4),rtp%data_real4,int(lcd,4),1.0,dtp%data_real4,int(lld,4))
	   else
	    call tensor_block_pcontract_dlf(lld,lrd,lcd,ltp%data_real4,rtp%data_real4,dtp%data_real4,ierr); if(ierr.ne.0) goto 999
	   endif
#endif
	  case('r8')
#ifdef NO_BLAS
	   call tensor_block_pcontract_dlf(lld,lrd,lcd,ltp%data_real8,rtp%data_real8,dtp%data_real8,ierr); if(ierr.ne.0) goto 999
#else
	   if(.not.disable_blas) then
	    call dgemm('T','N',int(lld,4),int(lrd,4),int(lcd,4),1d0,ltp%data_real8,int(lcd,4),rtp%data_real8,int(lcd,4),1d0,dtp%data_real8,int(lld,4))
	   else
	    call tensor_block_pcontract_dlf(lld,lrd,lcd,ltp%data_real8,rtp%data_real8,dtp%data_real8,ierr); if(ierr.ne.0) goto 999
	   endif
#endif
	  case('c8')
!	   call tensor_block_pcontract_dlf(lld,lrd,lcd,ltp%data_cmplx8,rtp%data_cmplx8,dtp%data_cmplx8,ierr); if(ierr.ne.0) goto 999 !`Enable
	  end select
	 case(full_contraction) !destination is a scalar variable
	  select case(dtk)
	  case('r4')
	   d_r4=0.0
	   call tensor_block_fcontract_dlf(lcd,ltp%data_real4,rtp%data_real4,d_r4,ierr); if(ierr.ne.0) goto 999
	   dtp%scalar_value=dtp%scalar_value+cmplx(d_r4,0d0,8)
	  case('r8')
	   d_r8=0d0
	   call tensor_block_fcontract_dlf(lcd,ltp%data_real8,rtp%data_real8,d_r8,ierr); if(ierr.ne.0) goto 999
	   dtp%scalar_value=dtp%scalar_value+cmplx(d_r8,0d0,8)
	  case('c8')
	   d_c8=cmplx(0d0,0d0,8)
!	   call tensor_block_fcontract_dlf(lcd,ltp%data_cmplx8,rtp%data_cmplx8,d_c8,ierr); if(ierr.ne.0) goto 999 !`Enable
	   dtp%scalar_value=dtp%scalar_value+d_c8
	  end select
	 case(add_tensor)
	  if(ltb.ne.scalar_tensor.and.rtb.eq.scalar_tensor) then
	   call tensor_block_add(dtp,ltp,ierr,rtp%scalar_value,dtk); if(ierr.ne.0) goto 999
	  elseif(ltb.eq.scalar_tensor.and.rtb.ne.scalar_tensor) then
	   call tensor_block_add(dtp,rtp,ierr,ltp%scalar_value,dtk); if(ierr.ne.0) goto 999
	  else
	   ierr=7; goto 999
	  endif
	 case(multiply_scalars)
	  dtp%scalar_value=dtp%scalar_value+ltp%scalar_value*rtp%scalar_value
	 end select
!	 write(cons_out,'("DEBUG(tensor_algebra::tensor_block_contract): DGEMM time: ",F10.4)') secnds(start_dgemm) !debug
 !Transpose the matrix-result into the output tensor:
	 if(dtransp) then
!	  write(cons_out,'("DEBUG(tensor_algebra::tensor_block_contract): permutation to be performed for ",i2)') 0 !debug
	  call tensor_block_copy(dtp,dtens,ierr,do2n); if(ierr.ne.0) goto 999
	 endif
	 if(data_kind_sync) then; call tensor_block_sync(dtens,dtk,ierr); if(ierr.ne.0) goto 999; endif
 !Destroy temporary tensor blocks:
999	 if(associated(ltp)) nullify(ltp); if(associated(rtp)) nullify(rtp); if(associated(dtp)) nullify(dtp)
	 if(associated(tens_in)) nullify(tens_in); if(associated(tens_out)) nullify(tens_out); if(associated(trn)) nullify(trn)
	 select case(contr_case)
	 case(partial_contraction)
	  if(ltransp) then; call tensor_block_destroy(lta,j); if(j.ne.0.and.ierr.eq.0) then; ierr=j; return; endif; endif
	  if(rtransp) then; call tensor_block_destroy(rta,j); if(j.ne.0.and.ierr.eq.0) then; ierr=j; return; endif; endif
	  if(dtransp) then; call tensor_block_destroy(dta,j); if(j.ne.0.and.ierr.eq.0) then; ierr=j; return; endif; endif
	 case(full_contraction)
	  if(ltransp) then; call tensor_block_destroy(lta,j); if(j.ne.0.and.ierr.eq.0) then; ierr=j; return; endif; endif
	 case(add_tensor)
	  if(dtransp) then; call tensor_block_destroy(dta,j); if(j.ne.0.and.ierr.eq.0) then; ierr=j; return; endif; endif
	 case(multiply_scalars)
	 end select
	else
	 ierr=8
	endif
!	write(cons_out,'("DEBUG(tensor_algebra::tensor_block_contract): exit error code: ",i5)') ierr !debug
	return
	contains

	 subroutine calculate_matrix_dimensions(tbst,nm,ns,tens,lm,ls,ier)
	 integer, intent(in):: tbst,nm,ns !tensor block storage layout, number of minor dimensions, number of senior dimensions
	 type(tensor_block_t), intent(in):: tens !tensor block
	 integer(8), intent(out):: lm,ls !minor extent, senior extent (of the matrix)
	 integer, intent(out):: ier
	 integer j0
	 ier=0
	 if(nm.ge.0.and.ns.ge.0.and.nm+ns.eq.tens%tensor_shape%num_dim) then
	  select case(tbst)
	  case(scalar_tensor)
	   lm=1_8; ls=1_8
	  case(dimension_led)
	   lm=1_8; do j0=1,nm; lm=lm*tens%tensor_shape%dim_extent(j0); enddo
	   ls=1_8; do j0=1,ns; ls=ls*tens%tensor_shape%dim_extent(nm+j0); enddo
	  case(bricked_dense) !`Future
	  case(bricked_ordered) !`Future
	  case(sparse_list) !`Future
	  case(compressed) !`Future
	  case default
	   ier=2
	  end select
	 else
	  ier=1
	 endif
	 return
	 end subroutine calculate_matrix_dimensions

	 subroutine determine_index_permutations !sets {dtransp,ltransp,rtransp},{do2n,lo2n,ro2n},{ncd,nlu,nru}
	 integer jkey(1:max_tensor_rank),jtrn0(0:max_tensor_rank),jtrn1(0:max_tensor_rank),jj,j0,j1
 !Destination operand:
	 if(drank.gt.0) then
	  do2n(0)=+1; j1=0
	  do j0=1,lrank+rrank
	   if(contr_ptrn(j0).gt.0) then
	    j1=j1+1; do2n(j1)=contr_ptrn(j0)
	   endif
	  enddo
	  if(perm_trivial(j1,do2n)) then; dtransp=.false.; else; dtransp=.true.; endif
	 else
	  dtransp=.false.
	 endif
 !Right tensor operand:
	 nru=0; ncd=0 !numbers of the right uncontracted and contracted dimensions
	 if(rrank.gt.0) then
	  ro2n(0)=+1; j1=0
	  do j0=1,rrank; if(contr_ptrn(lrank+j0).lt.0) then; j1=j1+1; ro2n(j0)=j1; endif; enddo; ncd=j1 !contracted dimensions
	  do j0=1,rrank; if(contr_ptrn(lrank+j0).gt.0) then; j1=j1+1; ro2n(j0)=j1; endif; enddo; nru=j1-ncd !uncontracted dimensions
	  if(perm_trivial(j1,ro2n)) then; rtransp=.false.; else; rtransp=.true.; endif
	 else
	  rtransp=.false.
	 endif
 !Left tensor operand:
	 nlu=0 !number of the left uncontracted dimensions
	 if(lrank.gt.0) then
	  lo2n(0)=+1; j1=0
	  do j0=1,lrank; if(contr_ptrn(j0).lt.0) then; j1=j1+1; jtrn1(j1)=j0; jkey(j1)=abs(contr_ptrn(j0)); endif; enddo; ncd=j1 !contracted dimensions
	  jtrn0(0:j1)=(/+1,(jj,jj=1,j1)/); call merge_sort_key_int(j1,jkey,jtrn0)
	  do j0=1,j1; jj=jtrn0(j0); lo2n(jtrn1(jj))=j0; enddo !contracted dimensions of the left operand are aligned to the corresponding dimensions of the right operand
	  do j0=1,lrank; if(contr_ptrn(j0).gt.0) then; j1=j1+1; lo2n(j0)=j1; endif; enddo; nlu=j1-ncd !uncontracted dimensions
	  if(perm_trivial(j1,lo2n)) then; ltransp=.false.; else; ltransp=.true.; endif
	 else
	  ltransp=.false.
	 endif
	 return
	 end subroutine determine_index_permutations

	 subroutine determine_data_kind(dtkd,ier)
	 character(2), intent(out):: dtkd
	 integer, intent(out):: ier
	 ier=0
	 select case(contr_case)
	 case(partial_contraction)
	  if(allocated(ltens%data_cmplx8).and.allocated(rtens%data_cmplx8).and.allocated(dtens%data_cmplx8)) then
	   dtkd='c8'
	  else
	   if(allocated(ltens%data_real8).and.allocated(rtens%data_real8).and.allocated(dtens%data_real8)) then
	    dtkd='r8'
	   else
	    if(allocated(ltens%data_real4).and.allocated(rtens%data_real4).and.allocated(dtens%data_real4)) then
	     dtkd='r4'
	    else
	     ier=101
	    endif
	   endif
	  endif
	 case(full_contraction)
	  if(allocated(ltens%data_cmplx8).and.allocated(rtens%data_cmplx8)) then
	   dtkd='c8'
	  else
	   if(allocated(ltens%data_real8).and.allocated(rtens%data_real8)) then
	    dtkd='r8'
	   else
	    if(allocated(ltens%data_real4).and.allocated(rtens%data_real4)) then
	     dtkd='r4'
	    else
	     ier=102
	    endif
	   endif
	  endif
	 case(add_tensor)
	  if(allocated(ltens%data_cmplx8).or.allocated(rtens%data_cmplx8)) then
	   dtkd='c8'
	  else
	   if(allocated(ltens%data_real8).or.allocated(rtens%data_real8)) then
	    dtkd='r8'
	   else
	    if(allocated(ltens%data_real4).or.allocated(rtens%data_real4)) then
	     dtkd='r4'
	    else
	     ier=103
	    endif
	   endif
	  endif
	 case(multiply_scalars)
	  dtkd='c8' !scalars are always complex(8)
	 end select
	 return
	 end subroutine determine_data_kind

	 logical function contr_ptrn_ok(ptrn,lr,rr,dr)
	 integer, intent(in):: ptrn(1:*),lr,rr,dr
	 integer j0,j1,jl,jbus(dr+lr+rr)
	 contr_ptrn_ok=.true.; jl=dr+lr+rr
	 if(jl.gt.0) then
	  jbus(1:jl)=0
	  do j0=1,lr !left tensor-argument
	   j1=ptrn(j0)
	   if(j1.gt.0.and.j1.le.dr) then !uncontracted index
	    jbus(j1)=jbus(j1)+1; jbus(dr+j0)=jbus(dr+j0)+1
	    if(ltens%tensor_shape%dim_extent(j0).ne.dtens%tensor_shape%dim_extent(j1)) then; contr_ptrn_ok=.false.; return; endif
	   elseif(j1.lt.0.and.abs(j1).le.rr) then !contracted index
	    jbus(dr+lr+abs(j1))=jbus(dr+lr+abs(j1))+1
	    if(ltens%tensor_shape%dim_extent(j0).ne.rtens%tensor_shape%dim_extent(abs(j1))) then; contr_ptrn_ok=.false.; return; endif
	   else
	    contr_ptrn_ok=.false.; return
	   endif
	  enddo
	  do j0=lr+1,lr+rr !right tensor-argument
	   j1=ptrn(j0)
	   if(j1.gt.0.and.j1.le.dr) then !uncontracted index
	    jbus(j1)=jbus(j1)+1; jbus(dr+j0)=jbus(dr+j0)+1
	    if(rtens%tensor_shape%dim_extent(j0-lr).ne.dtens%tensor_shape%dim_extent(j1)) then; contr_ptrn_ok=.false.; return; endif
	   elseif(j1.lt.0.and.abs(j1).le.lr) then !contracted index
	    jbus(dr+abs(j1))=jbus(dr+abs(j1))+1
	    if(rtens%tensor_shape%dim_extent(j0-lr).ne.ltens%tensor_shape%dim_extent(abs(j1))) then; contr_ptrn_ok=.false.; return; endif
	   else
	    contr_ptrn_ok=.false.; return
	   endif
	  enddo
	  do j0=1,jl
	   if(jbus(j0).ne.1) then; contr_ptrn_ok=.false.; return; endif
	  enddo
	 endif
	 return
	 end function contr_ptrn_ok

	 logical function ord_rest_ok(ord,ptrn,lr,rr,dr)!`Finish
	 integer, intent(in):: ord(1:*),ptrn(1:*),lr,rr,dr
	 ord_rest_ok=.true.
	 return
	 end function ord_rest_ok

	end subroutine tensor_block_contract
!----------------------------------------------------------------------
	subroutine get_mlndx_addr(intyp,id1,id2,mnii,ia1,ivol,iba,ierr) !SERIAL
!This subroutine creates an addressing array IBA(index_value,index_place) containing addressing increaments for multiindices.
!A multiindex is supposed to be in an ascending order for an i_multiindex and descending order for an a_multiindex
!with respect to moving from the minor multiindex positions to senior ones (left ro right): i1<i2<...<in; a1>a2>...>an,
!such that general index positions (minor) precede active index positions (senior).
!INPUT:
! - intyp - type of the multiindex {i/a}: {1/2};
! - id1   - index value upper bound: [0...id1], range=(1+id1);
! - id2   - length of the multiindex: [1..id2];
! - mnii  - maximal number of inactive indices (first <mnii> positions);
! - ia1   - first active index value for an i_multiindex, last active index value for an a_multiindex;
! - ierr - if non-zero, the validity test will be executed at the end;
!OUTPUT:
! - iba(0:id1,1:id2) - addressing array (addressing increaments);
! - ivol(1:id2) - number of possible multiindices for each multiindex length less or equal to <id2>;
! - ierr - error code (0:success).
	implicit none
	integer i,j,k,l,m,n,k1,k2,ks,kf,ierr
	integer, intent(in):: intyp,id1,id2,mnii,ia1
	integer(8), intent(out):: ivol(1:id2),iba(0:id1,1:id2)
	integer nii,ibnd(1:id2,2),im(0:id2+1)
	integer(8) kv1,kv2,mz,l1
	logical validity_test

	if(ierr.eq.0) then; validity_test=.false.; else; validity_test=.true.; ierr=0; endif
	nii=min(id2,mnii) !actual number of inactive (leading minor) positions
!Test arguments:
	if(id1.lt.0.or.id2.lt.0.or.id2.gt.1+id1) then
	 write(cons_out,'("ERROR(tensor_algebra::get_mlndx_addr): invalid or incompatible multiindex specification: ",i1,1x,i6,1x,i2,1x,i2,1x,i6)') intyp,id1,id2,mnii,ia1
	 ierr=1; return
	endif
	if(mnii.lt.0.or.ia1.lt.0.or.ia1.gt.id1.or.(intyp.eq.1.and.id2-nii.gt.id1-ia1+1).or.(intyp.eq.2.and.id2-nii.gt.ia1+1)) then
	 write(cons_out,'("ERROR(tensor_algebra::get_mlndx_addr): invalid active space configuration: ",i1,1x,i6,1x,i2,1x,i2,1x,i6)') intyp,id1,id2,mnii,ia1
	 ierr=2; return
	endif
	if(id2.eq.0) return !empty multiindex
!Set the multiindex addressing increaments:
	iba(:,:)=0_8; ivol(:)=0_8
	if(intyp.eq.1) then
 !i_multiindex, runnning downwards:
  !set index bounds:
	 ibnd(1:id2,1)=(/(j,j=0,nii-1),(max(nii,ia1)+j,j=0,id2-nii-1)/) !lower bounds do not depend on the multiindex length
	 ibnd(1:id2,2)=(/(j,j=id1-id2+1,id1)/) !upper bounds
  !set IBA:
	 kv2=0_8; do j=id1,ibnd(1,1),-1; iba(j,1)=kv2; kv2=kv2+1_8; enddo !the most minor position (the most rapidly changing)
	 ivol(1)=kv2; kv2=kv2-1_8
	 do k=2,id2 !loop over the index positions
	  kv1=0_8; do j=1,k-1; kv1=kv1+iba(id1-j,k-j); enddo !loop over the previous index positions
	  iba(id1,k)=-kv1 !set the first element at position k
	  do l=id1-1,ibnd(k,1),-1 !loop over the other index values
	   kv1=0_8; do j=1,k-1; kv1=kv1+iba(l-j,k-j); enddo
	   iba(l,k)=iba(l+1,k)+ivol(k-1)-kv1
	  enddo
	  kv2=kv2+iba(ibnd(k,1),k); ivol(k)=kv2+1_8
	 enddo
	elseif(intyp.eq.2) then
 !a_multiindex, runnning upwards:
  !set index bounds:
	 ibnd(1:id2,1)=(/(id2-j,j=1,id2)/) !lower bounds
	 ibnd(1:id2,2)=(/(id1-j,j=0,nii-1),(min(id1-nii,ia1)-j,j=0,id2-nii-1)/) !upper bounds do not depend on the multiindex length
  !set IBA:
	 kv2=0_8; do j=0,ibnd(1,2); iba(j,1)=kv2; kv2=kv2+1_8; enddo !the most minor position (the most rapidly changing)
	 ivol(1)=kv2; kv2=kv2-1_8
	 do k=2,id2 !loop over the index positions
	  kv1=0_8; do j=1,k-1; kv1=kv1+iba(j,k-j); enddo !loop over the previous index positions
	  iba(0,k)=-kv1 !set the first element at position k
	  do l=1,ibnd(k,2) !loop over the other index values
	   kv1=0_8; do j=1,k-1; kv1=kv1+iba(l+j,k-j); enddo
	   iba(l,k)=iba(l-1,k)+ivol(k-1)-kv1
	  enddo
	  kv2=kv2+iba(ibnd(k,2),k); ivol(k)=kv2+1_8
	 enddo
	else
	 write(cons_out,'("ERROR(tensor_algebra::get_mlndx_addr): invalid multiindex type requested: ",i2)') intyp
	 ierr=3; return
	endif
!Testing IBA for multiindices of size <id2>:
	if(validity_test) then
	 if(intyp.eq.1) then
 !i_multiindex, runnning downward:
  !set bounds:
	  ibnd(1:id2,1)=(/(j,j=0,nii-1),(max(nii,ia1)+j,j=0,id2-nii-1)/) !lower bounds do not depend on the multiindex length
	  ibnd(1:id2,2)=(/(j,j=id1-id2+1,id1)/) !upper bounds
  !init IM:
	  im(1:id2)=ibnd(1:id2,2); mz=0_8; do k=1,id2; mz=mz+iba(im(k),k); enddo; l1=0_8
	  iloop: do
!	   write(cons_out,'("Curent MLNDX: ",i10,5x,128(1x,i4))') l1,im(1:id2) !debug
	   if(mz.ne.l1) then; write(cons_out,*)'ERROR(tensor_algebra::get_mlndx_addr): fuck i_MZ: ',l1,mz; ierr=-1; return; endif
	   l1=l1+1_8
  !loop footer:
	   k=1
	   do while(k.le.id2)
	    mz=mz-iba(im(k),k)
	    if(im(k).gt.ibnd(k,1)) then
	     im(k)=im(k)-1; mz=mz+iba(im(k),k)
	     do k1=k-1,1,-1; im(k1)=min(im(k1+1)-1,ibnd(k1,2)); mz=mz+iba(im(k1),k1); enddo
	     cycle iloop
	    else
	     k=k+1
	    endif
	   enddo
!	   write(cons_out,'(" TESTED i-VOLUME: ",i20)') l1 !debug
	   exit iloop
	  enddo iloop
	 else !intyp=2
 !a_multiindex, runnning upward:
  !set bounds:
	  ibnd(1:id2,1)=(/(id2-j,j=1,id2)/) !lower bounds
	  ibnd(1:id2,2)=(/(id1-j,j=0,nii-1),(min(id1-nii,ia1)-j,j=0,id2-nii-1)/) !upper bounds do not depend on the multiindex length
  !init IM:
	  im(1:id2)=ibnd(1:id2,1); mz=0_8; do k=1,id2; mz=mz+iba(im(k),k); enddo; l1=0_8
	  aloop: do
!	   write(cons_out,'("Curent MLNDX: ",i10,5x,128(1x,i4))') im(id2:1:-1) !debug
	   if(mz.ne.l1) then; write(cons_out,*)'ERROR(tensor_algebra::get_mlndx_addr): fuck a_MZ: ',l1,mz; ierr=-2; return; endif
	   l1=l1+1_8
  !loop footer:
	   k=1
	   do while(k.le.id2)
	    mz=mz-iba(im(k),k)
	    if(im(k).lt.ibnd(k,2)) then
	     im(k)=im(k)+1; mz=mz+iba(im(k),k)
	     do k1=k-1,1,-1; im(k1)=max(im(k1+1)+1,ibnd(k1,1)); mz=mz+iba(im(k1),k1); enddo
	     cycle aloop
	    else
	     k=k+1
	    endif
	   enddo
!	   write(cons_out,'(" TESTED a-VOLUME: ",i20)') l1 !debug
	   exit aloop
	  enddo aloop
	 endif
	endif !validity test
	return
	end subroutine get_mlndx_addr
!-------------------------------------------------
	integer(8) function mlndx_value(ml,im,iba) !SERIAL
!This function returns an integer(8) address associated with the given multiindex.
!Each index is greater or equal to zero. Index position numeration starts from 1.
!INPUT:
! - ml - multiindex length;
! - im(1:ml) - multiindex;
! - iba(0:,1:) - array with addressing increaments (generated by <get_mlndx_addr>);
!OUTPUT:
! - mlndx_value - integer(8) address, -1 if ml<0;
	implicit none
	integer, intent(in):: ml,im(1:ml)
	integer(8), intent(in):: iba(0:,1:)
	integer i,j,k,l,m,n,k0,k1,k2,k3,ks,kf,ierr
	if(ml.ge.0) then
	 mlndx_value=0_8; ks=mod(ml,2)
	 do i=1,ml-ks,2; mlndx_value=mlndx_value+iba(im(i),i)+iba(im(i+1),i+1); enddo
	 if(ks.ne.0) mlndx_value=mlndx_value+iba(im(ml),ml)
	else
	 mlndx_value=-1_8
	endif
	return
	end function mlndx_value
!-------------------------------------------------------------------
	subroutine tensor_shape_rnd(tsss,tsl,ierr,tsize,tdim,spread) !SERIAL
!This subroutine returns a random tensor shape specification string.
!Only simple dense tensor blocks (without any ordering) are concerned here.
!INPUT:
! - tsize - (optional) desirable size of the tensor block (approximate);
! - tdim - (optional) desirable rank of the tensor block (exact);
! - spread - (optional) desirable spread in dimension extents (ratio max_dim_ext/min_dim_ext);
!OUTPUT:
! - tsss(1:tsl) - tensor shape specification string.
	implicit none
	character(*), intent(out):: tsss
	integer, intent(out):: tsl
	integer(8), intent(in), optional:: tsize
	integer, intent(in), optional:: tdim
	integer, intent(in), optional:: spread
	integer, intent(inout):: ierr
!---------------------------------------------------
	integer, parameter:: max_dim_extent=2**30  !max dimension extent
	integer(8), parameter:: max_blk_size=2**30 !max tensor block size (default)
!---------------------------------------------------
	integer i,j,m,n,tdm,spr
	integer(8) tsz
	real(8) val,stretch,dme(1:max_tensor_rank)

	ierr=0; tsl=0
	if(present(tdim)) then
	 if(tdim.ge.0) then; tdm=tdim; else; ierr=1; return; endif
	else
	 call random_number(val); tdm=nint(dble(max_tensor_rank)*val)
	endif
	if(present(tsize)) then
	 if(tsize.gt.0_8) then; tsz=tsize; if(tdm.eq.0.and.tsize.gt.1_8) tdm=1; else; ierr=2; return; endif
	else
	 if(tdm.gt.0) then; call random_number(val); tsz=int(dble(max_blk_size)*val,8)+1_8; else; tsz=1_8; endif
	endif
	spr=0; if(present(spread)) then; if(spread.gt.0) then; spr=spread; else; ierr=3; return; endif; endif
	if(tdm.gt.0) then
	 tsss(1:1)='('; tsl=1
	 call random_number(dme(1:tdm))
	 val=dme(1); do i=2,tdm; val=min(val,dme(i)); enddo
	 do i=1,tdm; dme(i)=dme(i)/val; enddo
!	 write(cons_out,*) dme(1:tdm) !debug
	 val=dme(1); do i=2,tdm; val=max(val,dme(i)); enddo
	 if(spr.ge.1) then; stretch=dlog10(dble(spr))/dlog10(val); do i=1,tdm; dme(i)=dme(i)**stretch; enddo; endif
!	 write(cons_out,*) stretch; write(cons_out,*) dme(1:tdm) !debug
	 val=dme(1); do i=2,tdm; val=val*dme(i); enddo
	 stretch=(dble(tsz)/val)**(1d0/dble(tdm))
	 do i=1,tdm
	  val=dme(i)*stretch
	  if(val.ge.1d0) then
	   m=min(nint(val),max_dim_extent); if(i.lt.tdm) stretch=stretch*((val/dble(m))**(1d0/dble(tdm-i)))
	  else
	   m=1; if(i.lt.tdm) stretch=stretch*(val**(1d0/dble(tdm-i)))
	  endif
	  call numchar(m,j,tsss(tsl+1:)); tsl=tsl+j+1; tsss(tsl:tsl)=','
	 enddo
	 tsss(tsl:tsl)=')'
	else
	 tsss(1:2)='()'; tsl=2
	endif
	return
	end subroutine tensor_shape_rnd
!--------------------------------------------------------------
	subroutine get_contr_pattern(cptrn,contr_ptrn,cpl,ierr) !SERIAL
!This subroutine converts a mnemonic contraction pattern into the digital form.
!INPUT:
! - cptrn - mnemonic contraction pattern (e.g., "D(ia1,ib2)+=L(ib2,k2,c3)*R(c3,ia1,k2)" );
!OUTPUT:
! - contr_ptrn(1:cpl) - digital contraction pattern (see, tensor_block_contract);
! - ierr - error code (0:success).
!NOTES:
! - Index labels can only contain English letters and/or numbers.
!   Indices are separated by commas. Parentheses are mandatory.
! - ASCII is assumed.
	implicit none
	character(*), intent(in):: cptrn
	integer, intent(out):: contr_ptrn(1:*),cpl
	integer, intent(inout):: ierr
	character(1), parameter:: dn1(0:9)=(/'0','1','2','3','4','5','6','7','8','9'/)
	character(2), parameter:: dn2(0:49)=(/'00','01','02','03','04','05','06','07','08','09', &
	                                      '10','11','12','13','14','15','16','17','18','19', &
	                                      '20','21','22','23','24','25','26','27','28','29', &
	                                      '30','31','32','33','34','35','36','37','38','39', &
	                                      '40','41','42','43','44','45','46','47','48','49'/)
	integer i,j,k,l,m,n,k0,k1,k2,k3,k4,ks,kf,adims(0:2),tag_len
	character(2048) str !increase the length if needed (I doubt)

	ierr=0; l=len_trim(cptrn); cpl=0
	if(l.gt.0) then
!	 write(cons_out,*)'DEBUG(tensor_algebra::get_contr_pattern): '//cptrn(1:l) !debug
!Extract the index labels:
	 tag_len=len('{000}')
	 adims(:)=0; n=-1; m=0; ks=0; i=1
	 aloop: do while(i.le.l)
	  do while(cptrn(i:i).ne.'('); i=i+1; if(i.gt.l) exit aloop; enddo; ks=i; i=i+1; n=n+1; k=1 !find '(': beginning of an argument #n
	  if(n.gt.2) then; ierr=7; return; endif
	  str(m+1:m+tag_len)='{'//dn1(n)//dn2(k)//'}'; m=m+tag_len
	  do while(i.le.l)
	   if(cptrn(i:i).eq.',') then
	    j=i-1-abs(ks); if(.not.index_label_ok(cptrn(abs(ks)+1:i-1))) then; ierr=4; return; endif
	    str(m+1:m+j)=cptrn(abs(ks)+1:i-1); m=m+j; ks=-i
	    k=k+1; str(m+1:m+tag_len)='{'//dn1(n)//dn2(k)//'}'; m=m+tag_len
	   elseif(cptrn(i:i).eq.')') then
	    j=i-1-abs(ks)
	    if(j.le.0) then
	     if(ks.lt.0) then; ierr=5; return; endif
	    else
	     if(.not.index_label_ok(cptrn(abs(ks)+1:i-1))) then; ierr=9; return; endif
	     str(m+1:m+j)=cptrn(abs(ks)+1:i-1); m=m+j
	     k=k+1; str(m+1:m+tag_len)='{'//dn1(n)//dn2(k)//'}'; m=m+tag_len
	    endif
	    ks=0; i=i+1; exit
	   endif
	   i=i+1
	  enddo
	  m=m-tag_len; if(ks.ne.0) then; ierr=6; return; endif !no closing parenthesis
	  adims(n)=k-1 !number of indices in argument #k
	 enddo aloop
	 str(m+1:m+1)='{' !special setting
	 if(ks.ne.0) then; ierr=2; return; endif !no closing parenthesis
	 if(n.eq.2) then !contraction (three arguments)
 !Analyze the index labels:
	  cpl=adims(1)+adims(2)
!	  write(cons_out,*)'DEBUG(tensor_algebra::get_contr_pattern): str: '//str(1:m+1) !debug
	  i=0
	  do
	   j=index(str(i+1:m),'}')+i; if(j.gt.i) then; i=j; else; exit; endif
	   j=i+1; do while(j.le.m-tag_len); if(str(j:j).eq.'{') exit; j=j+1; enddo; if(str(j:j).ne.'{'.or.j.gt.m-tag_len) then; ierr=8; return; endif
	   k0=index(str(j+tag_len-1:m+1),str(i:j))+(j+tag_len-2)
	   if(k0.gt.j+tag_len-2) then
!	    write(cons_out,*)'DEBUG(tensor_algebra::get_contr_pattern): index match: '//str(i+1:j-1) !debug
	    k1=icharnum(1,str(i-tag_len+2:i-tag_len+2)); k2=icharnum(2,str(i-tag_len+3:i-tag_len+4))
	    k3=icharnum(1,str(k0-tag_len+2:k0-tag_len+2)); k4=icharnum(2,str(k0-tag_len+3:k0-tag_len+4))
	    if(k1.eq.0.and.k3.eq.1) then !open index
	     contr_ptrn(k4)=k2
	    elseif(k1.eq.0.and.k3.eq.2) then !open index
	     contr_ptrn(adims(1)+k4)=k2
	    elseif(k1.eq.1.and.k3.eq.2) then !free index
	     contr_ptrn(k2)=-k4; contr_ptrn(adims(1)+k4)=-k2
	    else
	     ierr=11; return
	    endif
	    str(i+1:j-1)=' '; do while(str(k0:k0).ne.'{'); str(k0:k0)=' '; k0=k0+1; enddo
	   else
	    ierr=10; return
	   endif
	  enddo
	 elseif(n.eq.1) then !permutation (two arguments)
	  !`Add
	  ierr=-13
	 endif
	else !empty string
	 ierr=1
	endif
!	write(cons_out,*)'DEBUG(tensor_algebra::get_contr_pattern): cpl,contr_ptrn: ',cpl,contr_ptrn(1:cpl) !debug
	return

	contains

	 logical function index_label_ok(lb)
	  character(*), intent(in):: lb
	  integer j0,j1,j2
	  j0=len(lb); index_label_ok=.true.
	  if(j0.gt.0) then
	   do j1=1,j0
	    j2=iachar(lb(j1:j1))
	    if(.not.((j2.ge.iachar('a').and.j2.le.iachar('z')).or. &
	             (j2.ge.iachar('A').and.j2.le.iachar('Z')).or.(j2.ge.iachar('0').and.j2.le.iachar('9')))) then
	     index_label_ok=.false.; return
	    endif
	   enddo
!	   j2=iachar(lb(1:1)); if(j2.ge.iachar('0').and.j2.le.iachar('9')) index_label_ok=.false. !the 1st character cannot be a number
	  else
	   index_label_ok=.false.
	  endif
	  return
	 end function index_label_ok

	end subroutine get_contr_pattern
!-------------------------------------------------------------------------------------------
	subroutine get_contr_permutations(lrank,rrank,cptrn,dprm,lprm,rprm,ncd,nlu,nru,ierr) bind(c,name='get_contr_permutations') !SERIAL
!This subroutine returns all tensor permutations necessary for the tensor
!contraction specified by <cptrn> (implemented via a matrix multiplication).
!INPUT:
! - cptrn(1:lrank+rrank) - digital contraction pattern;
!OUTPUT:
! - dprm(0:drank) - index permutation for the destination tensor (N2O, numeration starts from 1);
! - lprm(0:lrank) - index permutation for the left tensor argument (O2N, numeration starts from 1);
! - rprm(0:rrank) - index permutation for the right tensor argument (O2N, numeration starts from 1);
! - ncd - total number of contracted indices;
! - nlu - number of left uncontracted indices;
! - nru - number of right uncontracted indices;
! - ierr - error code (0:success).
	use, intrinsic:: ISO_C_BINDING
	implicit none
!------------------------------------------------
	logical, parameter:: check_pattern=.true.
!------------------------------------------------
	integer(C_INT), intent(in), value:: lrank,rrank
	integer(C_INT), intent(in):: cptrn(1:*)
	integer(C_INT), intent(out):: dprm(0:*),lprm(0:*),rprm(0:*),ncd,nlu,nru
	integer(C_INT), intent(inout):: ierr
	integer(C_INT) i,j,k,drank,jkey(1:lrank+rrank),jtrn0(0:lrank+rrank),jtrn1(0:lrank+rrank)
	logical pattern_ok

	ierr=0
	if(check_pattern) then; pattern_ok=contr_pattern_ok(); else; pattern_ok=.true.; endif
	if(pattern_ok.and.lrank.ge.0.and.rrank.ge.0) then
 !Destination operand:
	 drank=0; dprm(0)=+1;
	 do i=1,lrank+rrank; if(cptrn(i).gt.0) then; drank=drank+1; dprm(drank)=cptrn(i); endif; enddo
 !Right tensor operand:
	 nru=0; ncd=0; rprm(0)=+1; !numbers of the right uncontracted and contracted dimensions
	 if(rrank.gt.0) then
	  j=0; do i=1,rrank; if(cptrn(lrank+i).lt.0) then; j=j+1; rprm(i)=j; endif; enddo; ncd=j !contracted dimensions
	  do i=1,rrank; if(cptrn(lrank+i).gt.0) then; j=j+1; rprm(i)=j; endif; enddo; nru=j-ncd !uncontracted dimensions
	 endif
 !Left tensor operand:
	 nlu=0; lprm(0)=+1; !number of the left uncontracted dimensions
	 if(lrank.gt.0) then
	  j=0
	  do i=1,lrank
	   if(cptrn(i).lt.0) then; j=j+1; jtrn1(j)=i; jkey(j)=abs(cptrn(i)); endif
	  enddo
	  ncd=j !contracted dimensions
	  jtrn0(0:j)=(/+1,(k,k=1,j)/); if(j.ge.2) call merge_sort_key_int(j,jkey,jtrn0)
	  do i=1,j; k=jtrn0(i); lprm(jtrn1(k))=i; enddo !contracted dimensions of the left operand are aligned to the corresponding dimensions of the right operand
	  do i=1,lrank; if(cptrn(i).gt.0) then; j=j+1; lprm(i)=j; endif; enddo; nlu=j-ncd !uncontracted dimensions
	 endif
	else !invalid lrank or rrank or cptrn(:)
	 ierr=1
	endif
	return

	contains

	 logical function contr_pattern_ok()
	 integer(C_INT) j0,j1,jc,jl
	 contr_pattern_ok=.true.; jl=lrank+rrank
	 if(jl.gt.0) then
	  jkey(1:jl)=0; jc=0
	  do j0=1,jl
	   j1=cptrn(j0)
	   if(j1.lt.0) then !contracted index
	    if(j0.le.lrank) then
	     if(abs(j1).gt.rrank) then; contr_pattern_ok=.false.; return; endif
	     if(cptrn(lrank+abs(j1)).ne.-j0) then; contr_pattern_ok=.false.; return; endif
	    else
	     if(abs(j1).gt.lrank) then; contr_pattern_ok=.false.; return; endif
	     if(cptrn(abs(j1)).ne.-(j0-lrank)) then; contr_pattern_ok=.false.; return; endif
	    endif
	   elseif(j1.gt.0.and.j1.le.jl) then !uncontracted index
	    jc=jc+1
	    if(jkey(j1).eq.0) then
	     jkey(j1)=1
	    else
	     contr_pattern_ok=.false.; return
	    endif
	   else
	    contr_pattern_ok=.false.; return
	   endif
	  enddo
	  do j0=1,jc; if(jkey(j0).ne.1) then; contr_pattern_ok=.false.; return; endif; enddo
	 endif
	 return
	 end function contr_pattern_ok

	end subroutine get_contr_permutations
!--------------------------------------------
!PRIVATE FUNCTIONS:
!----------------------------------------------------------------
	subroutine tensor_shape_create(shape_str,tens_shape,ierr) !SERIAL
!This subroutine generates a tensor shape <tens_shape> based on the tensor shape specification string (TSSS) <str>.
!Only the syntax of the TSSS is checked, but not the logical consistency (which can be checked by function <tensor_shape_ok>)!
!FORMAT of <shape_str>:
!"(E1/D1{G1},E2/D2{G2},...)":
!  Ex is the extent of the dimension x (segment);
!  /Dx specifies an optional segment divider for the dimension x (lm_segment_size), 1<=Dx<=Ex (DEFAULT = Ex);
!      Ex MUST be a multiple of Dx.
!  {Gx} optionally specifies the symmetric group the dimension belongs to, Gx>=0 (default group 0 has no symmetry ordering).
!       Dimensions grouped together (group#>0) will obey a non-descending ordering from left to right.
!By default, the 1st dimension is the most minor one while the last is the most senior (Fortran-like).
!If the number of dimensions equals to zero, the %scalar_value field will be used instead of data arrays.
	implicit none
	character(*), intent(in):: shape_str
	type(tensor_shape_t), intent(inout):: tens_shape
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n,k0,k1,k2,k3,ks,kf
	character(max_shape_str_len) shp

	ierr=0; l=len_trim(shape_str)
	if(l.gt.max_shape_str_len) then; write(cons_out,*)'FATAL(tensor_algebra::tensor_shape_create): max length of a shape specification string exceeded: ',l; ierr=-1; return; endif
	call remove_blanks(l,shape_str,shp)
	if(l.ge.len('()')) then
	 if(shp(1:1).eq.'('.and.shp(l:l).eq.')') then
	  call destroy_tensor_shape(tens_shape)
 !count the number of dimensions:
	  n=0
	  if(l.gt.len('()')) then
	   do i=1,l
	    if(shp(i:i).eq.',') n=n+1
	   enddo
	   n=n+1
	  else
	   if(shp(1:l).ne.'()') then; ierr=10; return; endif
	  endif
 !read the specifications:
	  if(n.gt.0) then
	   allocate(tens_shape%dim_extent(1:n),STAT=ierr); if(ierr.ne.0) return
	   allocate(tens_shape%dim_divider(1:n),STAT=ierr); if(ierr.ne.0) return
	   allocate(tens_shape%dim_group(1:n),STAT=ierr); if(ierr.ne.0) return
	   tens_shape%dim_divider(1:n)=0
	   tens_shape%dim_group(1:n)=0 !by default, each dimension belongs to symmetric group 0 (with no symmetry ordering)
	   n=1; i=len('(')+1; ks=i; kf=0
	   do while(i.le.l)
	    select case(shp(i:i))
	    case(',',')','/','{','}')
	     if(i.gt.ks) then
	      k=i-ks; m=icharnum(k,shp(ks:i-1)); if(k.le.0) then; ierr=4; return; endif
	     else
	      if(kf.ne.3) then; ierr=3; return; endif
	     endif
	     select case(shp(i:i))
	     case(',',')')
	      if(kf.eq.0) then; tens_shape%dim_extent(n)=m; elseif(kf.eq.1) then; tens_shape%dim_divider(n)=m; elseif(kf.eq.2) then; ierr=9; return; endif
	      if(shp(i:i).eq.',') then; n=n+1; i=i+1; ks=i; kf=0; else; if(i.ne.l) then; ierr=5; return; endif; i=i+1; endif
	     case('/')
	      if(kf.eq.0) then; tens_shape%dim_extent(n)=m; else; ierr=6; return; endif
	      i=i+1; ks=i; kf=1
	     case('{')
	      if(kf.eq.0) then; tens_shape%dim_extent(n)=m; elseif(kf.eq.1) then; tens_shape%dim_divider(n)=m; else; ierr=7; return; endif
	      i=i+1; ks=i; kf=2
	     case('}')
	      if(kf.eq.2) then; tens_shape%dim_group(n)=m; else; ierr=8; return; endif
	      i=i+1; ks=i; kf=3
	     end select
	    case default
	     i=i+1
	    end select
	   enddo
	   do i=1,n; if(tens_shape%dim_divider(i).eq.0) tens_shape%dim_divider(i)=tens_shape%dim_extent(i); enddo
	   tens_shape%num_dim=n
	  elseif(n.eq.0) then
	   tens_shape%num_dim=0 !scalar (rank-0 tensor)
	  endif
	 else
	  ierr=2 !invalid shape descriptor string
	 endif
	else
	 ierr=1 !invalid shape descriptor string
	endif
	return
	contains

	 subroutine destroy_tensor_shape(tens_shape)
	 type(tensor_shape_t), intent(inout):: tens_shape
	 tens_shape%num_dim=-1
	 if(allocated(tens_shape%dim_extent)) deallocate(tens_shape%dim_extent)
	 if(allocated(tens_shape%dim_divider)) deallocate(tens_shape%dim_divider)
	 if(allocated(tens_shape%dim_group)) deallocate(tens_shape%dim_group)
	 return
	 end subroutine destroy_tensor_shape

	 subroutine remove_blanks(sl,str_in,str_out)
	 integer, intent(inout):: sl
	 character(*), intent(in):: str_in
	 character(*), intent(out):: str_out
	 integer j0,j1
	 j1=0
	 do j0=1,sl
	  if(str_in(j0:j0).ne.' '.and.iachar(str_in(j0:j0)).ne.9) then
	   j1=j1+1; str_out(j1:j1)=str_in(j0:j0)
	  endif
	 enddo
	 sl=j1
	 return
	 end subroutine remove_blanks

	end subroutine tensor_shape_create
!---------------------------------------------------
	integer function tensor_shape_ok(tens_shape) !SERIAL
!This function checks the logical correctness of a tensor shape generated from a tensor shape specification string (TSSS).
!INPUT:
! - tens_shape - tensor shape;
!OUTPUT:
! - tensor_shape_ok - error code (0:success);
!NOTES:
! - Ordered (symmetric) indices must have the same divider! Whether or not should they have the same extent is still debatable for me (D.I.L.).
	implicit none
	type(tensor_shape_t), intent(inout):: tens_shape
	integer i,j,k,l,m,n,k0,k1,k2,k3,ks,kf,ierr
	integer group_ext(1:max_tensor_rank),group_div(1:max_tensor_rank)

	tensor_shape_ok=0
	if(tens_shape%num_dim.eq.0) then !scalar (rank-0) tensor
	 if(allocated(tens_shape%dim_extent)) deallocate(tens_shape%dim_extent)
	 if(allocated(tens_shape%dim_divider)) deallocate(tens_shape%dim_divider)
	 if(allocated(tens_shape%dim_group)) deallocate(tens_shape%dim_group)
	elseif(tens_shape%num_dim.gt.0) then !true tensor (rank>0)
	 n=tens_shape%num_dim
	 if(n.le.max_tensor_rank) then
	  if(.not.allocated(tens_shape%dim_extent)) then; tensor_shape_ok=2; return; endif
	  if(.not.allocated(tens_shape%dim_divider)) then; tensor_shape_ok=3; return; endif
	  if(.not.allocated(tens_shape%dim_group)) then; tensor_shape_ok=4; return; endif
	  if(size(tens_shape%dim_extent).ne.n) then; ierr=11; return; endif
	  if(size(tens_shape%dim_divider).ne.n) then; ierr=12; return; endif
	  if(size(tens_shape%dim_group).ne.n) then; ierr=13; return; endif
	  kf=0
	  do i=1,n
	   if(tens_shape%dim_extent(i).le.0) then; tensor_shape_ok=5; return; endif
	   if(tens_shape%dim_divider(i).gt.0.and.tens_shape%dim_divider(i).le.tens_shape%dim_extent(i)) then
	    kf=1; if(mod(tens_shape%dim_extent(i),tens_shape%dim_divider(i)).ne.0) then; tensor_shape_ok=14; return; endif
	   elseif(tens_shape%dim_divider(i).eq.0) then
	    if(kf.ne.0) then; tensor_shape_ok=15; return; endif
	   else !negative divider
	    tensor_shape_ok=6; return
	   endif
	  enddo
	  if(kf.ne.0) then !dimension_led or bricked storage layout
	   group_div(1:n)=0
	   do i=1,n
	    if(tens_shape%dim_group(i).lt.0) then
	     tensor_shape_ok=7; return
	    elseif(tens_shape%dim_group(i).gt.0) then !non-trivial symmetric group
	     if(tens_shape%dim_group(i).le.n) then
	      if(group_div(tens_shape%dim_group(i)).eq.0) group_div(tens_shape%dim_group(i))=tens_shape%dim_divider(i)
	      if(tens_shape%dim_divider(i).ne.group_div(tens_shape%dim_group(i))) then; tensor_shape_ok=9; return; endif !divider must be the same for symmetric dimensions
	     else
	      tensor_shape_ok=10; return
	     endif
	    endif
	   enddo
	  else !alternative storage layout
	   !`Future
	  endif
	 else !max tensor rank exceeded: increase parameter <max_tensor_rank> of this module
	  tensor_shape_ok=-max_tensor_rank
	 endif
	else !negative tensor rank
	 tensor_shape_ok=1
	endif
	return
	end function tensor_shape_ok
!-----------------------------------------------------------------------------------------------
	subroutine tensor_block_slice_dlf_r8(dim_num,tens,tens_ext,slice,slice_ext,ext_beg,ierr) !PARALLEL
!This subroutine extracts a slice from a tensor block.
!INPUT:
! - dim_num - number of tensor dimensions;
! - tens(0:) - tensor block (array);
! - tens_ext(1:dim_num) - dimension extents for <tens>;
! - slice_ext(1:dim_num) - dimension extents for <slice>;
! - ext_beg(1:dim_num) - beginning dimension offsets for <tens> (numeration starts at 0);
!OUTPUT:
! - slice(0:) - slice (array);
! - ierr - error code (0:success).
!NOTES:
! - No argument validity checks.
	implicit none
!---------------------------------------
	integer, parameter:: real_kind=8
!---------------------------------------
	integer, intent(in):: dim_num,tens_ext(1:dim_num),slice_ext(1:dim_num),ext_beg(1:dim_num)
	real(real_kind), intent(in):: tens(0:*)
	real(real_kind), intent(out):: slice(0:*)
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n,ks,kf,im(1:dim_num)
	integer(8) bases_in(1:dim_num),bases_out(1:dim_num),segs(0:max_threads),lts,lss,l_in,l_out
	real(4) time_beg
	integer, external:: omp_get_thread_num,omp_get_num_threads

	ierr=0
!	time_beg=secnds(0.) !debug
	if(dim_num.gt.0) then
	 lts=1_8; do i=1,dim_num; bases_in(i)=lts; lts=lts*tens_ext(i); enddo   !tensor block indexing bases
	 lss=1_8; do i=1,dim_num; bases_out(i)=lss; lss=lss*slice_ext(i); enddo !slice indexing bases
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(i,m,n,im,l_in,l_out)
#ifndef NO_OMP
	 n=omp_get_thread_num(); m=omp_get_num_threads()
#else
	 n=0; m=1
#endif
!$OMP MASTER
	 segs(0)=0_8; call divide_segment(lss,int(m,8),segs(1:),ierr); do i=2,m; segs(i)=segs(i)+segs(i-1); enddo
!$OMP END MASTER
!$OMP BARRIER
!$OMP FLUSH(segs)
	 l_out=segs(n); do i=dim_num,1,-1; im(i)=l_out/bases_out(i); l_out=mod(l_out,bases_out(i)); enddo
	 l_in=ext_beg(1)+im(1); do i=2,dim_num; l_in=l_in+(ext_beg(i)+im(i))*bases_in(i); enddo
	 sloop: do l_out=segs(n),segs(n+1)-1_8
	  slice(l_out)=tens(l_in)
	  do i=1,dim_num
	   if(im(i)+1.lt.slice_ext(i)) then
	    im(i)=im(i)+1; l_in=l_in+bases_in(i)
	    cycle sloop
	   else
	    l_in=l_in-im(i)*bases_in(i); im(i)=0
	   endif
	  enddo
	  exit sloop
	 enddo sloop
!$OMP END PARALLEL
	else
	 ierr=1 !zero-rank tensor
	endif
!	write(cons_out,'("DEBUG(tensor_algebra::tensor_block_slice_dlf_r8): kernel time/error code: ",F10.4,1x,i3)') secnds(time_beg),ierr !debug
	return
	end subroutine tensor_block_slice_dlf_r8
!------------------------------------------------------------------------------------------------
	subroutine tensor_block_insert_dlf_r8(dim_num,tens,tens_ext,slice,slice_ext,ext_beg,ierr) !PARALLEL
!This subroutine inserts a slice into a tensor block.
!INPUT:
! - dim_num - number of tensor dimensions;
! - tens_ext(1:dim_num) - dimension extents for <tens>;
! - slice(0:) - slice (array);
! - slice_ext(1:dim_num) - dimension extents for <slice>;
! - ext_beg(1:dim_num) - beginning dimension offsets for <tens> (numeration starts at 0);
!OUTPUT:
! - tens(0:) - tensor block (array);
! - ierr - error code (0:success).
!NOTES:
! - No argument validity checks.
	implicit none
!---------------------------------------
	integer, parameter:: real_kind=8
!---------------------------------------
	integer, intent(in):: dim_num,tens_ext(1:dim_num),slice_ext(1:dim_num),ext_beg(1:dim_num)
	real(real_kind), intent(in):: slice(0:*)
	real(real_kind), intent(out):: tens(0:*)
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n,ks,kf,im(1:dim_num)
	integer(8) bases_in(1:dim_num),bases_out(1:dim_num),segs(0:max_threads),lts,lss,l_in,l_out
	real(4) time_beg
	integer, external:: omp_get_thread_num,omp_get_num_threads

	ierr=0
!	time_beg=secnds(0.) !debug
	if(dim_num.gt.0) then
	 lts=1_8; do i=1,dim_num; bases_out(i)=lts; lts=lts*tens_ext(i); enddo !tensor block indexing bases
	 lss=1_8; do i=1,dim_num; bases_in(i)=lss; lss=lss*slice_ext(i); enddo !slice indexing bases
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(i,m,n,im,l_in,l_out)
#ifndef NO_OMP
	 n=omp_get_thread_num(); m=omp_get_num_threads()
#else
	 n=0; m=1
#endif
!$OMP MASTER
	 segs(0)=0_8; call divide_segment(lss,int(m,8),segs(1:),ierr); do i=2,m; segs(i)=segs(i)+segs(i-1); enddo
!$OMP END MASTER
!$OMP BARRIER
!$OMP FLUSH(segs)
	 l_in=segs(n); do i=dim_num,1,-1; im(i)=l_in/bases_in(i); l_in=mod(l_in,bases_in(i)); enddo
	 l_out=ext_beg(1)+im(1); do i=2,dim_num; l_out=l_out+(ext_beg(i)+im(i))*bases_out(i); enddo
	 sloop: do l_in=segs(n),segs(n+1)-1_8
	  tens(l_out)=slice(l_in)
	  do i=1,dim_num
	   if(im(i)+1.lt.slice_ext(i)) then
	    im(i)=im(i)+1; l_out=l_out+bases_out(i)
	    cycle sloop
	   else
	    l_out=l_out-im(i)*bases_out(i); im(i)=0
	   endif
	  enddo
	  exit sloop
	 enddo sloop
!$OMP END PARALLEL
	else
	 ierr=1 !zero-rank tensor
	endif
!	write(cons_out,'("DEBUG(tensor_algebra::tensor_block_insert_dlf_r8): kernel time/error code: ",F10.4,1x,i3)') secnds(time_beg),ierr !debug
	return
	end subroutine tensor_block_insert_dlf_r8
!------------------------------------------------------------------------------------------------
	subroutine tensor_block_copy_dlf_r4(dim_num,dim_extents,dim_transp,tens_in,tens_out,ierr) !PARALLEL
!Given a dense tensor block, this subroutine makes a copy of it, permuting the indices according to the <dim_transp>.
!The algorithm is cache-efficient (Author: Dmitry I. Lyakh (Dmytro I. Liakh): quant4me@gmail.com)
!INPUT:
! - dim_num - number of dimensions (>0);
! - dim_extents(1:dim_num) - dimension extents;
! - dim_transp(0:dim_num) - index permutation (O2N);
! - tens_in(0:) - input tensor data;
!OUTPUT:
! - tens_out(0:) - output (possibly transposed) tensor data;
! - ierr - error code (0:success).
	implicit none
!---------------------------------------------------
	integer, parameter:: real_kind=4
	logical, parameter:: cache_efficiency=.true.
	integer(8), parameter:: cache_line_lim=2**5   !approx. number of simultaneously open cache lines per thread
	integer(8), parameter:: small_tens_size=2**12 !up to this size (of a tensor block) it is useless to apply cache efficiency
	integer(8), parameter:: ave_thread_num=32     !average number of executing threads (approx.)
	integer(8), parameter:: max_dim_ext=cache_line_lim*ave_thread_num !boundary dimensions which have a larger extent will be split
	integer(8), parameter:: vec_size=2**4         !loop reorganization parameter
!-----------------------------------------------------
	integer, intent(in):: dim_num,dim_extents(1:*),dim_transp(0:*)
	real(real_kind), intent(in):: tens_in(0:*)
	real(real_kind), intent(out):: tens_out(0:*)
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n,k0,k1,k2,k3,ks,kf,split_in,split_out,ac1(1:max_tensor_rank+1)
	integer im(1:max_tensor_rank),n2o(0:max_tensor_rank+1),ipr(1:max_tensor_rank+1)
	integer(8) bases_in(1:max_tensor_rank+1),bases_out(1:max_tensor_rank+1),bases_pri(1:max_tensor_rank+1)
	integer(8) bs,l0,l1,l2,l3,l_in,l_out,segs(0:max_threads)
	integer dim_beg(1:dim_num),dim_end(1:dim_num)
	logical trivial,in_out_dif
	real(4) time_beg
	integer, external:: omp_get_thread_num,omp_get_num_threads

	ierr=0
!	time_beg=secnds(0.) !debug
	if(dim_num.lt.0) then; ierr=dim_num; return; elseif(dim_num.eq.0) then; tens_out(0)=tens_in(0); return; endif
!Check the index permutation:
	trivial=.true.; do i=1,dim_num; if(dim_transp(i).ne.i) then; trivial=.false.; exit; endif; enddo
	trivial=trivial.and.cache_efficiency
	if(trivial) then !trivial index permutation
 !Compute indexing bases:
	 n2o(0:dim_num+1)=(/+1,dim_transp(1:dim_num),dim_num+1/)
	 bs=1_8; do i=1,dim_num; bases_in(i)=bs; bs=bs*dim_extents(i); enddo
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(l0,l1)
!$OMP DO SCHEDULE(GUIDED)
	 do l0=0_8,bs-1_8-mod(bs,vec_size),vec_size
	  do l1=0_8,vec_size-1_8; tens_out(l0+l1)=tens_in(l0+l1); enddo
	 enddo
!$OMP END DO NOWAIT
!$OMP MASTER
	 do l0=bs-mod(bs,vec_size),bs-1_8; tens_out(l0)=tens_in(l0); enddo
!$OMP END MASTER
!$OMP END PARALLEL
	else !non-trivial index permutation
 !Compute indexing bases:
	 do i=1,dim_num; n2o(dim_transp(i))=i; enddo; n2o(dim_num+1)=dim_num+1 !get the N2O
	 bs=1_8; do i=1,dim_num; bases_in(i)=bs; bs=bs*dim_extents(i); enddo
	 bs=1_8; do i=1,dim_num; bases_out(n2o(i))=bs; bs=bs*dim_extents(n2o(i)); enddo
	 bases_in(dim_num+1)=bs; bases_out(dim_num+1)=bs
 !Determine index looping priorities:
	 in_out_dif=.false.; split_in=0; split_out=0
	 if(bs.le.small_tens_size.or.(.not.cache_efficiency)) then !tensor block is too small
	  ipr(1:dim_num+1)=(/(j,j=1,dim_num+1)/); kf=dim_num !trivial priorities
	 else
	  do k1=2,dim_num; if(bases_in(k1).ge.cache_line_lim) exit; enddo; k1=k1-1 !first k1 input dimensions form the input minor set
	  ipr(1:k1)=(/(j,j=1,k1)/); n=k1 !first k1 input dimensions form the input minor set
	  do j=1,k1; if(dim_transp(j).gt.k1) then; in_out_dif=.true.; exit; endif; enddo !if .true., the output minor set differs from the input one
	  if(in_out_dif) then !check whether I need to split long ranges
	   if(dim_extents(k1).gt.max_dim_ext) split_in=k1 !input dimension which will be split
	   do k2=2,dim_num; if(bases_out(n2o(k2)).ge.cache_line_lim) exit; enddo; k2=k2-1 !first k2 output dimensions form the output minor set
	   if(dim_extents(n2o(k2)).gt.max_dim_ext) split_out=n2o(k2) !output dimension which will be split
	   if(split_out.eq.split_in) split_out=0 !input and output split dimensions coincide
	  else
	   k2=k1
	  endif
	  kf=k1; do j=1,k2; if(n2o(j).gt.k1) then; n=n+1; ipr(n)=n2o(j); kf=kf+1; endif; enddo !ipr(priority) = old_num: dimension looping priorities
	  do j=k2+1,dim_num; if(n2o(j).gt.k1) then; n=n+1; ipr(n)=n2o(j); endif; enddo !kf is the length of the combined minor set
	  ipr(dim_num+1)=dim_num+1 !special setting
	 endif
	 do i=1,dim_num; ac1(i)=n2o(dim_transp(i)+1); enddo !accelerator array
!	 write(cons_out,'("DEBUG(tensor_algebra::tensor_block_copy_dlf_r4): block size, split dims = ",i10,3x,i2,1x,i2)') bs,split_in,split_out !debug
!	 write(cons_out,'("DEBUG(tensor_algebra::tensor_block_copy_dlf_r4): index extents =",128(1x,i2))') dim_extents(1:dim_num) !debug
!	 write(cons_out,'("DEBUG(tensor_algebra::tensor_block_copy_dlf_r4): index permutation =",128(1x,i2))') dim_transp(1:dim_num) !debug
!	 write(cons_out,'("DEBUG(tensor_algebra::tensor_block_copy_dlf_r4): index priorities = ",i3,1x,l1,128(1x,i2))') kf,in_out_dif,ipr(1:dim_num) !debug
 !Transpose loop:
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(i,j,m,n,im,l_in,l_out,l0,l1,l2,l3,dim_beg,dim_end)
#ifndef NO_OMP
	 n=omp_get_thread_num(); m=omp_get_num_threads() !multi-threaded execution
#else
	 n=0; m=1 !serial execution
#endif
!	 if(n.eq.0) write(cons_out,'("DEBUG(tensor_algebra::tensor_block_copy_dlf_r4): total number of threads = ",i4)') m !debug
	 if(.not.in_out_dif) then !input minor set coincides with the output minor set: no splitting
!$OMP MASTER
!	  write(cons_out,'("DEBUG(tensor_algebra::tensor_block_copy_dlf_r4): total number of threads = ",i4)') m !debug
	  segs(0)=0_8; call divide_segment(bs,int(m,8),segs(1:),ierr); do j=2,m; segs(j)=segs(j)+segs(j-1); enddo
	  l0=1_8; do i=1,dim_num; bases_pri(ipr(i))=l0; l0=l0*dim_extents(ipr(i)); enddo !priority bases
!$OMP END MASTER
!$OMP BARRIER
!$OMP FLUSH(segs,bases_pri)
	  l0=segs(n); do i=dim_num,1,-1; j=ipr(i); im(j)=l0/bases_pri(j); l0=mod(l0,bases_pri(j)); enddo !initial multiindex for each thread
	  l_in=0_8; do j=1,dim_num; l_in=l_in+im(j)*bases_in(j); enddo !initital input address
	  l_out=0_8; do j=1,dim_num; l_out=l_out+im(j)*bases_out(j); enddo !initial output address
	  do l0=segs(n),segs(n+1)-1_8,cache_line_lim
	   loop0: do l1=l0,min(l0+cache_line_lim-1_8,segs(n+1)-1_8)
	    tens_out(l_out)=tens_in(l_in)
  !Increament of the multi-index (scheme 1):
	    do i=1,dim_num
	     j=ipr(i)
	     if(im(j)+1.eq.dim_extents(j)) then
	      l_in=l_in+bases_in(j)-bases_in(j+1); l_out=l_out+bases_out(j)-bases_out(ac1(j)); im(j)=0
	     else
	      im(j)=im(j)+1; l_in=l_in+bases_in(j); l_out=l_out+bases_out(j)
	      cycle loop0
	     endif
	    enddo !i
	   enddo loop0 !l1
	  enddo !l0
	 else !input and output minor sets differ: range splitting possible
	  if(split_in.gt.0.and.split_out.eq.0) then !split the last dimension from the input minor set
	   dim_beg(1:dim_num)=0; dim_end(1:dim_num)=dim_extents(1:dim_num)-1; im(1:dim_num)=dim_beg(1:dim_num)
	   l1=dim_extents(split_in)-1_8
!$OMP DO SCHEDULE(GUIDED)
	   do l0=0_8,l1,cache_line_lim
	    dim_beg(split_in)=int(l0,4); dim_end(split_in)=int(min(l0+cache_line_lim-1_8,l1),4)
	    im(split_in)=dim_beg(split_in); l_in=im(split_in)*bases_in(split_in); l_out=im(split_in)*bases_out(split_in)
	    loop2: do
	     tens_out(l_out)=tens_in(l_in)
	     do i=1,dim_num
	      j=ipr(i) !old index number
	      if(im(j).lt.dim_end(j)) then
	       im(j)=im(j)+1; l_in=l_in+bases_in(j); l_out=l_out+bases_out(j)
	       cycle loop2
	      else
	       l_in=l_in-(im(j)-dim_beg(j))*bases_in(j); l_out=l_out-(im(j)-dim_beg(j))*bases_out(j); im(j)=dim_beg(j)
	      endif
	     enddo !i
	     exit loop2
	    enddo loop2
	   enddo !l0
!$OMP END DO
	  elseif(split_in.eq.0.and.split_out.gt.0) then !split the last dimension from the output minor set
	   dim_beg(1:dim_num)=0; dim_end(1:dim_num)=dim_extents(1:dim_num)-1; im(1:dim_num)=dim_beg(1:dim_num)
           l1=dim_extents(split_out)-1_8
!$OMP DO SCHEDULE(GUIDED)
	   do l0=0_8,l1,cache_line_lim
	    dim_beg(split_out)=int(l0,4); dim_end(split_out)=int(min(l0+cache_line_lim-1_8,l1),4)
	    im(split_out)=dim_beg(split_out); l_in=im(split_out)*bases_in(split_out); l_out=im(split_out)*bases_out(split_out)
	    loop3: do
	     tens_out(l_out)=tens_in(l_in)
	     do i=1,dim_num
	      j=ipr(i) !old index number
	      if(im(j).lt.dim_end(j)) then
	       im(j)=im(j)+1; l_in=l_in+bases_in(j); l_out=l_out+bases_out(j)
	       cycle loop3
	      else
	       l_in=l_in-(im(j)-dim_beg(j))*bases_in(j); l_out=l_out-(im(j)-dim_beg(j))*bases_out(j); im(j)=dim_beg(j)
	      endif
	     enddo !i
	     exit loop3
	    enddo loop3
	   enddo !l0
!$OMP END DO
	  elseif(split_in.gt.0.and.split_out.gt.0) then !split the last dimensions from both the input and output minor sets
	   dim_beg(1:dim_num)=0; dim_end(1:dim_num)=dim_extents(1:dim_num)-1; im(1:dim_num)=dim_beg(1:dim_num)
           l2=dim_end(split_in); l3=dim_end(split_out)
!$OMP DO SCHEDULE(GUIDED) COLLAPSE(1)
	   do l0=0_8,l2,cache_line_lim !input dimension
	    do l1=0_8,l3,cache_line_lim !output dimension
	     dim_beg(split_in)=int(l0,4); dim_end(split_in)=int(min(l0+cache_line_lim-1_8,l2),4)
	     dim_beg(split_out)=int(l1,4); dim_end(split_out)=int(min(l1+cache_line_lim-1_8,l3),4)
	     im(split_in)=dim_beg(split_in); im(split_out)=dim_beg(split_out)
	     l_in=im(split_in)*bases_in(split_in)+im(split_out)*bases_in(split_out)
	     l_out=im(split_in)*bases_out(split_in)+im(split_out)*bases_out(split_out)
	     loop4: do
	      tens_out(l_out)=tens_in(l_in)
	      do i=1,dim_num
	       j=ipr(i) !old index number
	       if(im(j).lt.dim_end(j)) then
	        im(j)=im(j)+1; l_in=l_in+bases_in(j); l_out=l_out+bases_out(j)
	        cycle loop4
	       else
	        l_in=l_in-(im(j)-dim_beg(j))*bases_in(j); l_out=l_out-(im(j)-dim_beg(j))*bases_out(j); im(j)=dim_beg(j)
	       endif
	      enddo !i
	      exit loop4
	     enddo loop4
	    enddo !l1
	   enddo !l0
!$OMP END DO
	  else !no range splitting
!$OMP MASTER
	   segs(0)=0_8; call divide_segment(bs,int(m,8),segs(1:),ierr); do j=2,m; segs(j)=segs(j)+segs(j-1); enddo
	   l0=1_8; do i=1,dim_num; bases_pri(ipr(i))=l0; l0=l0*dim_extents(ipr(i)); enddo !priority bases
!$OMP END MASTER
!$OMP BARRIER
!$OMP FLUSH(segs,bases_pri)
	   l0=segs(n); do i=dim_num,1,-1; j=ipr(i); im(j)=l0/bases_pri(j); l0=mod(l0,bases_pri(j)); enddo
	   l_in=0_8; do j=1,dim_num; l_in=l_in+im(j)*bases_in(j); enddo
	   l_out=0_8; do j=1,dim_num; l_out=l_out+im(j)*bases_out(j); enddo
	   do l0=segs(n),segs(n+1)-1_8,cache_line_lim
	    loop1: do l1=l0,min(l0+cache_line_lim-1_8,segs(n+1)-1_8)
	     tens_out(l_out)=tens_in(l_in)
  !Increament of the multi-index (scheme 2):
	     do i=1,dim_num
	      j=ipr(i) !old index number
	      if(im(j)+1.lt.dim_extents(j)) then
	       im(j)=im(j)+1; l_in=l_in+bases_in(j); l_out=l_out+bases_out(j)
	       cycle loop1
	      else
	       l_in=l_in-im(j)*bases_in(j); l_out=l_out-im(j)*bases_out(j); im(j)=0
	      endif
	     enddo !i
	    enddo loop1 !l1
	   enddo !l0
	  endif
	 endif
!$OMP END PARALLEL
	endif !trivial or not
!	write(cons_out,'("DEBUG(tensor_algebra::tensor_block_copy_dlf_r4): kernel time/error code = ",F10.4,1x,i3)') secnds(time_beg),ierr !debug
	return
	end subroutine tensor_block_copy_dlf_r4
!------------------------------------------------------------------------------------------------
	subroutine tensor_block_copy_dlf_r8(dim_num,dim_extents,dim_transp,tens_in,tens_out,ierr) !PARALLEL
!Given a dense tensor block, this subroutine makes a copy of it, permuting the indices according to the <dim_transp>.
!The algorithm is cache-efficient (Author: Dmitry I. Lyakh (Dmytro I. Liakh): quant4me@gmail.com)
!INPUT:
! - dim_num - number of dimensions (>0);
! - dim_extents(1:dim_num) - dimension extents;
! - dim_transp(0:dim_num) - index permutation (O2N);
! - tens_in(0:) - input tensor data;
!OUTPUT:
! - tens_out(0:) - output (possibly transposed) tensor data;
! - ierr - error code (0:success).
	implicit none
!---------------------------------------------------
	integer, parameter:: real_kind=8
	logical, parameter:: cache_efficiency=.true.
	integer(8), parameter:: cache_line_lim=2**5   !approx. number of simultaneously open cache lines per thread
	integer(8), parameter:: small_tens_size=2**12 !up to this size (of a tensor block) it is useless to apply cache efficiency
	integer(8), parameter:: ave_thread_num=32     !average number of executing threads (approx.)
	integer(8), parameter:: max_dim_ext=cache_line_lim*ave_thread_num !boundary dimensions which have a larger extent will be split
	integer(8), parameter:: vec_size=2**4         !loop reorganization parameter
!-----------------------------------------------------
	integer, intent(in):: dim_num,dim_extents(1:*),dim_transp(0:*)
	real(real_kind), intent(in):: tens_in(0:*)
	real(real_kind), intent(out):: tens_out(0:*)
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n,k0,k1,k2,k3,ks,kf,split_in,split_out,ac1(1:max_tensor_rank+1)
	integer im(1:max_tensor_rank),n2o(0:max_tensor_rank+1),ipr(1:max_tensor_rank+1)
	integer(8) bases_in(1:max_tensor_rank+1),bases_out(1:max_tensor_rank+1),bases_pri(1:max_tensor_rank+1)
	integer(8) bs,l0,l1,l2,l3,l_in,l_out,segs(0:max_threads)
	integer dim_beg(1:dim_num),dim_end(1:dim_num)
	logical trivial,in_out_dif
	real(4) time_beg
	integer, external:: omp_get_thread_num,omp_get_num_threads

	ierr=0
!	time_beg=secnds(0.) !debug
	if(dim_num.lt.0) then; ierr=dim_num; return; elseif(dim_num.eq.0) then; tens_out(0)=tens_in(0); return; endif
!Check the index permutation:
	trivial=.true.; do i=1,dim_num; if(dim_transp(i).ne.i) then; trivial=.false.; exit; endif; enddo
	trivial=trivial.and.cache_efficiency
	if(trivial) then !trivial index permutation
 !Compute indexing bases:
	 n2o(0:dim_num+1)=(/+1,dim_transp(1:dim_num),dim_num+1/)
	 bs=1_8; do i=1,dim_num; bases_in(i)=bs; bs=bs*dim_extents(i); enddo
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(l0,l1)
!$OMP DO SCHEDULE(GUIDED)
	 do l0=0_8,bs-1_8-mod(bs,vec_size),vec_size
	  do l1=0_8,vec_size-1_8; tens_out(l0+l1)=tens_in(l0+l1); enddo
	 enddo
!$OMP END DO NOWAIT
!$OMP MASTER
	 do l0=bs-mod(bs,vec_size),bs-1_8; tens_out(l0)=tens_in(l0); enddo
!$OMP END MASTER
!$OMP END PARALLEL
	else !non-trivial index permutation
 !Compute indexing bases:
	 do i=1,dim_num; n2o(dim_transp(i))=i; enddo; n2o(dim_num+1)=dim_num+1 !get the N2O
	 bs=1_8; do i=1,dim_num; bases_in(i)=bs; bs=bs*dim_extents(i); enddo
	 bs=1_8; do i=1,dim_num; bases_out(n2o(i))=bs; bs=bs*dim_extents(n2o(i)); enddo
	 bases_in(dim_num+1)=bs; bases_out(dim_num+1)=bs
 !Determine index looping priorities:
	 in_out_dif=.false.; split_in=0; split_out=0
	 if(bs.le.small_tens_size.or.(.not.cache_efficiency)) then !tensor block is too small
	  ipr(1:dim_num+1)=(/(j,j=1,dim_num+1)/); kf=dim_num !trivial priorities
	 else
	  do k1=2,dim_num; if(bases_in(k1).ge.cache_line_lim) exit; enddo; k1=k1-1 !first k1 input dimensions form the input minor set
	  ipr(1:k1)=(/(j,j=1,k1)/); n=k1 !first k1 input dimensions form the input minor set
	  do j=1,k1; if(dim_transp(j).gt.k1) then; in_out_dif=.true.; exit; endif; enddo !if .true., the output minor set differs from the input one
	  if(in_out_dif) then !check whether I need to split long ranges
	   if(dim_extents(k1).gt.max_dim_ext) split_in=k1 !input dimension which will be split
	   do k2=2,dim_num; if(bases_out(n2o(k2)).ge.cache_line_lim) exit; enddo; k2=k2-1 !first k2 output dimensions form the output minor set
	   if(dim_extents(n2o(k2)).gt.max_dim_ext) split_out=n2o(k2) !output dimension which will be split
	   if(split_out.eq.split_in) split_out=0 !input and output split dimensions coincide
	  else
	   k2=k1
	  endif
	  kf=k1; do j=1,k2; if(n2o(j).gt.k1) then; n=n+1; ipr(n)=n2o(j); kf=kf+1; endif; enddo !ipr(priority) = old_num: dimension looping priorities
	  do j=k2+1,dim_num; if(n2o(j).gt.k1) then; n=n+1; ipr(n)=n2o(j); endif; enddo !kf is the length of the combined minor set
	  ipr(dim_num+1)=dim_num+1 !special setting
	 endif
	 do i=1,dim_num; ac1(i)=n2o(dim_transp(i)+1); enddo !accelerator array
!	 write(cons_out,'("DEBUG(tensor_algebra::tensor_block_copy_dlf_r8): block size, split dims = ",i10,3x,i2,1x,i2)') bs,split_in,split_out !debug
!	 write(cons_out,'("DEBUG(tensor_algebra::tensor_block_copy_dlf_r8): index extents =",128(1x,i2))') dim_extents(1:dim_num) !debug
!	 write(cons_out,'("DEBUG(tensor_algebra::tensor_block_copy_dlf_r8): index permutation =",128(1x,i2))') dim_transp(1:dim_num) !debug
!	 write(cons_out,'("DEBUG(tensor_algebra::tensor_block_copy_dlf_r8): index priorities = ",i3,1x,l1,128(1x,i2))') kf,in_out_dif,ipr(1:dim_num) !debug
 !Transpose loop:
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(i,j,m,n,im,l_in,l_out,l0,l1,l2,l3,dim_beg,dim_end)
#ifndef NO_OMP
	 n=omp_get_thread_num(); m=omp_get_num_threads() !multi-threaded execution
#else
	 n=0; m=1 !serial execution
#endif
!	 if(n.eq.0) write(cons_out,'("DEBUG(tensor_algebra::tensor_block_copy_dlf_r8): total number of threads = ",i4)') m !debug
	 if(.not.in_out_dif) then !input minor set coincides with the output minor set: no splitting
!$OMP MASTER
!	  write(cons_out,'("DEBUG(tensor_algebra::tensor_block_copy_dlf_r8): total number of threads = ",i4)') m !debug
	  segs(0)=0_8; call divide_segment(bs,int(m,8),segs(1:),ierr); do j=2,m; segs(j)=segs(j)+segs(j-1); enddo
	  l0=1_8; do i=1,dim_num; bases_pri(ipr(i))=l0; l0=l0*dim_extents(ipr(i)); enddo !priority bases
!$OMP END MASTER
!$OMP BARRIER
!$OMP FLUSH(segs,bases_pri)
	  l0=segs(n); do i=dim_num,1,-1; j=ipr(i); im(j)=l0/bases_pri(j); l0=mod(l0,bases_pri(j)); enddo !initial multiindex for each thread
	  l_in=0_8; do j=1,dim_num; l_in=l_in+im(j)*bases_in(j); enddo !initital input address
	  l_out=0_8; do j=1,dim_num; l_out=l_out+im(j)*bases_out(j); enddo !initial output address
	  do l0=segs(n),segs(n+1)-1_8,cache_line_lim
	   loop0: do l1=l0,min(l0+cache_line_lim-1_8,segs(n+1)-1_8)
	    tens_out(l_out)=tens_in(l_in)
  !Increament of the multi-index (scheme 1):
	    do i=1,dim_num
	     j=ipr(i)
	     if(im(j)+1.eq.dim_extents(j)) then
	      l_in=l_in+bases_in(j)-bases_in(j+1); l_out=l_out+bases_out(j)-bases_out(ac1(j)); im(j)=0
	     else
	      im(j)=im(j)+1; l_in=l_in+bases_in(j); l_out=l_out+bases_out(j)
	      cycle loop0
	     endif
	    enddo !i
	   enddo loop0 !l1
	  enddo !l0
	 else !input and output minor sets differ: range splitting possible
	  if(split_in.gt.0.and.split_out.eq.0) then !split the last dimension from the input minor set
	   dim_beg(1:dim_num)=0; dim_end(1:dim_num)=dim_extents(1:dim_num)-1; im(1:dim_num)=dim_beg(1:dim_num)
	   l1=dim_extents(split_in)-1_8
!$OMP DO SCHEDULE(GUIDED)
	   do l0=0_8,l1,cache_line_lim
	    dim_beg(split_in)=int(l0,4); dim_end(split_in)=int(min(l0+cache_line_lim-1_8,l1),4)
	    im(split_in)=dim_beg(split_in); l_in=im(split_in)*bases_in(split_in); l_out=im(split_in)*bases_out(split_in)
	    loop2: do
	     tens_out(l_out)=tens_in(l_in)
	     do i=1,dim_num
	      j=ipr(i) !old index number
	      if(im(j).lt.dim_end(j)) then
	       im(j)=im(j)+1; l_in=l_in+bases_in(j); l_out=l_out+bases_out(j)
	       cycle loop2
	      else
	       l_in=l_in-(im(j)-dim_beg(j))*bases_in(j); l_out=l_out-(im(j)-dim_beg(j))*bases_out(j); im(j)=dim_beg(j)
	      endif
	     enddo !i
	     exit loop2
	    enddo loop2
	   enddo !l0
!$OMP END DO
	  elseif(split_in.eq.0.and.split_out.gt.0) then !split the last dimension from the output minor set
	   dim_beg(1:dim_num)=0; dim_end(1:dim_num)=dim_extents(1:dim_num)-1; im(1:dim_num)=dim_beg(1:dim_num)
           l1=dim_extents(split_out)-1_8
!$OMP DO SCHEDULE(GUIDED)
	   do l0=0_8,l1,cache_line_lim
	    dim_beg(split_out)=int(l0,4); dim_end(split_out)=int(min(l0+cache_line_lim-1_8,l1),4)
	    im(split_out)=dim_beg(split_out); l_in=im(split_out)*bases_in(split_out); l_out=im(split_out)*bases_out(split_out)
	    loop3: do
	     tens_out(l_out)=tens_in(l_in)
	     do i=1,dim_num
	      j=ipr(i) !old index number
	      if(im(j).lt.dim_end(j)) then
	       im(j)=im(j)+1; l_in=l_in+bases_in(j); l_out=l_out+bases_out(j)
	       cycle loop3
	      else
	       l_in=l_in-(im(j)-dim_beg(j))*bases_in(j); l_out=l_out-(im(j)-dim_beg(j))*bases_out(j); im(j)=dim_beg(j)
	      endif
	     enddo !i
	     exit loop3
	    enddo loop3
	   enddo !l0
!$OMP END DO
	  elseif(split_in.gt.0.and.split_out.gt.0) then !split the last dimensions from both the input and output minor sets
	   dim_beg(1:dim_num)=0; dim_end(1:dim_num)=dim_extents(1:dim_num)-1; im(1:dim_num)=dim_beg(1:dim_num)
           l2=dim_end(split_in); l3=dim_end(split_out)
!$OMP DO SCHEDULE(GUIDED) COLLAPSE(1)
	   do l0=0_8,l2,cache_line_lim !input dimension
	    do l1=0_8,l3,cache_line_lim !output dimension
	     dim_beg(split_in)=int(l0,4); dim_end(split_in)=int(min(l0+cache_line_lim-1_8,l2),4)
	     dim_beg(split_out)=int(l1,4); dim_end(split_out)=int(min(l1+cache_line_lim-1_8,l3),4)
	     im(split_in)=dim_beg(split_in); im(split_out)=dim_beg(split_out)
	     l_in=im(split_in)*bases_in(split_in)+im(split_out)*bases_in(split_out)
	     l_out=im(split_in)*bases_out(split_in)+im(split_out)*bases_out(split_out)
	     loop4: do
	      tens_out(l_out)=tens_in(l_in)
	      do i=1,dim_num
	       j=ipr(i) !old index number
	       if(im(j).lt.dim_end(j)) then
	        im(j)=im(j)+1; l_in=l_in+bases_in(j); l_out=l_out+bases_out(j)
	        cycle loop4
	       else
	        l_in=l_in-(im(j)-dim_beg(j))*bases_in(j); l_out=l_out-(im(j)-dim_beg(j))*bases_out(j); im(j)=dim_beg(j)
	       endif
	      enddo !i
	      exit loop4
	     enddo loop4
	    enddo !l1
	   enddo !l0
!$OMP END DO
	  else !no range splitting
!$OMP MASTER
	   segs(0)=0_8; call divide_segment(bs,int(m,8),segs(1:),ierr); do j=2,m; segs(j)=segs(j)+segs(j-1); enddo
	   l0=1_8; do i=1,dim_num; bases_pri(ipr(i))=l0; l0=l0*dim_extents(ipr(i)); enddo !priority bases
!$OMP END MASTER
!$OMP BARRIER
!$OMP FLUSH(segs,bases_pri)
	   l0=segs(n); do i=dim_num,1,-1; j=ipr(i); im(j)=l0/bases_pri(j); l0=mod(l0,bases_pri(j)); enddo
	   l_in=0_8; do j=1,dim_num; l_in=l_in+im(j)*bases_in(j); enddo
	   l_out=0_8; do j=1,dim_num; l_out=l_out+im(j)*bases_out(j); enddo
	   do l0=segs(n),segs(n+1)-1_8,cache_line_lim
	    loop1: do l1=l0,min(l0+cache_line_lim-1_8,segs(n+1)-1_8)
	     tens_out(l_out)=tens_in(l_in)
  !Increament of the multi-index (scheme 2):
	     do i=1,dim_num
	      j=ipr(i) !old index number
	      if(im(j)+1.lt.dim_extents(j)) then
	       im(j)=im(j)+1; l_in=l_in+bases_in(j); l_out=l_out+bases_out(j)
	       cycle loop1
	      else
	       l_in=l_in-im(j)*bases_in(j); l_out=l_out-im(j)*bases_out(j); im(j)=0
	      endif
	     enddo !i
	    enddo loop1 !l1
	   enddo !l0
	  endif
	 endif
!$OMP END PARALLEL
	endif !trivial or not
!	write(cons_out,'("DEBUG(tensor_algebra::tensor_block_copy_dlf_r8): kernel time/error code = ",F10.4,1x,i3)') secnds(time_beg),ierr !debug
	return
	end subroutine tensor_block_copy_dlf_r8
!--------------------------------------------------------------------------------------------------------
	subroutine tensor_block_copy_scatter_dlf_r4(dim_num,dim_extents,dim_transp,tens_in,tens_out,ierr) !PARALLEL
!Given a dense tensor block, this subroutine makes a copy of it, permuting the indices according to the <dim_transp>.
!INPUT:
! - dim_num - number of dimensions (>0);
! - dim_extents(1:dim_num) - dimension extents;
! - dim_transp(0:dim_num) - index permutation (O2N);
! - tens_in(0:) - input tensor data;
!OUTPUT:
! - tens_out(0:) - output (possibly transposed) tensor data;
! - ierr - error code (0:success).
	implicit none
!---------------------------------------
	integer, parameter:: real_kind=4
!---------------------------------------
	integer, intent(in):: dim_num,dim_extents(1:*)
	integer, intent(in):: dim_transp(0:*)
	real(real_kind), intent(in):: tens_in(0:*)
	real(real_kind), intent(out):: tens_out(0:*)
	integer, intent(inout):: ierr
	integer i,k,n2o(dim_num)
	integer(8) j,l,m,n,base_in(dim_num),base_out(dim_num)
	logical trivial
	real(4) time_beg

	ierr=0
!	time_beg=secnds(0.) !debug
	if(dim_num.eq.0) then !scalar tensor
	 tens_out(0)=tens_in(0)
	elseif(dim_num.gt.0) then
	 trivial=.true.; do i=1,dim_num; if(dim_transp(i).ne.i) then; trivial=.false.; exit; endif; enddo
	 n=dim_extents(1); do i=2,dim_num; n=n*dim_extents(i); enddo
	 if(trivial) then !trivial permutation
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(i) SCHEDULE(GUIDED)
	  do l=0_8,n-1_8; tens_out(l)=tens_in(l); enddo
!$OMP END PARALLEL DO
	 else !non-trivial permutation
	  do i=1,dim_num; n2o(dim_transp(i))=i; enddo
	  j=1_8; do i=1,dim_num; base_in(i)=j; j=j*dim_extents(i); enddo
	  j=1_8; do i=1,dim_num; k=n2o(i); base_out(k)=j; j=j*dim_extents(k); enddo
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(i,j,k,l) SCHEDULE(GUIDED)
	  do m=0_8,n-1_8
	   l=0_8; j=m; do k=dim_num,1,-1; l=l+(j/base_in(k))*base_out(k); j=mod(j,base_in(k)); enddo
	   tens_out(l)=tens_in(m)
	  enddo
!$OMP END PARALLEL DO
	 endif
	else
	 ierr=1
	endif
!	write(cons_out,'("DEBUG(tensor_algebra::tensor_block_copy_scatter_dlf_r4): kernel time/error code = ",F10.4,1x,i3)') secnds(time_beg),ierr !debug
	return
	end subroutine tensor_block_copy_scatter_dlf_r4
!--------------------------------------------------------------------------------------------------------
	subroutine tensor_block_copy_scatter_dlf_r8(dim_num,dim_extents,dim_transp,tens_in,tens_out,ierr) !PARALLEL
!Given a dense tensor block, this subroutine makes a copy of it, permuting the indices according to the <dim_transp>.
!INPUT:
! - dim_num - number of dimensions (>0);
! - dim_extents(1:dim_num) - dimension extents;
! - dim_transp(0:dim_num) - index permutation (O2N);
! - tens_in(0:) - input tensor data;
!OUTPUT:
! - tens_out(0:) - output (possibly transposed) tensor data;
! - ierr - error code (0:success).
	implicit none
!---------------------------------------
	integer, parameter:: real_kind=8
!---------------------------------------
	integer, intent(in):: dim_num,dim_extents(1:*)
	integer, intent(in):: dim_transp(0:*)
	real(real_kind), intent(in):: tens_in(0:*)
	real(real_kind), intent(out):: tens_out(0:*)
	integer, intent(inout):: ierr
	integer i,k,n2o(dim_num)
	integer(8) j,l,m,n,base_in(dim_num),base_out(dim_num)
	logical trivial
	real(4) time_beg

	ierr=0
!	time_beg=secnds(0.) !debug
	if(dim_num.eq.0) then !scalar tensor
	 tens_out(0)=tens_in(0)
	elseif(dim_num.gt.0) then
	 trivial=.true.; do i=1,dim_num; if(dim_transp(i).ne.i) then; trivial=.false.; exit; endif; enddo
	 n=dim_extents(1); do i=2,dim_num; n=n*dim_extents(i); enddo
	 if(trivial) then !trivial permutation
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(i) SCHEDULE(GUIDED)
	  do l=0_8,n-1_8; tens_out(l)=tens_in(l); enddo
!$OMP END PARALLEL DO
	 else !non-trivial permutation
	  do i=1,dim_num; n2o(dim_transp(i))=i; enddo
	  j=1_8; do i=1,dim_num; base_in(i)=j; j=j*dim_extents(i); enddo
	  j=1_8; do i=1,dim_num; k=n2o(i); base_out(k)=j; j=j*dim_extents(k); enddo
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(i,j,k,l) SCHEDULE(GUIDED)
	  do m=0_8,n-1_8
	   l=0_8; j=m; do k=dim_num,1,-1; l=l+(j/base_in(k))*base_out(k); j=mod(j,base_in(k)); enddo
	   tens_out(l)=tens_in(m)
	  enddo
!$OMP END PARALLEL DO
	 endif
	else
	 ierr=1
	endif
!	write(cons_out,'("DEBUG(tensor_algebra::tensor_block_copy_scatter_dlf_r8): kernel time/error code = ",F10.4,1x,i3)') secnds(time_beg),ierr !debug
	return
	end subroutine tensor_block_copy_scatter_dlf_r8
!--------------------------------------------------------------------------
	subroutine tensor_block_fcontract_dlf_r4(dc,ltens,rtens,dtens,ierr) !PARALLEL
!This subroutine fully reduces two vectors derived from the corresponding tensors by index permutations:
!dtens+=ltens(0:dc-1)*rtens(0:dc-1), where dtens is a scalar.
	implicit none
!---------------------------------------
	integer, parameter:: real_kind=4 !real data kind
!---------------------------------------
	integer(8), intent(in):: dc
	real(real_kind), intent(in):: ltens(0:*),rtens(0:*) !true tensors
	real(real_kind), intent(inout):: dtens !scalar
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n
	real(real_kind) val
	integer(8) l0
	real(4) time_beg

	ierr=0
!	time_beg=secnds(0.) !debug
!	write(cons_out,'("DEBUG(tensor_algebra::tensor_block_fcontract_dlf_r4): dc: ",i9)') dc !debug
	if(dc.gt.0_8) then
	 val=0.0
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED) REDUCTION(+:val)
	 do l0=0_8,dc-1_8; val=val+ltens(l0)*rtens(l0); enddo
!$OMP END PARALLEL DO
	 dtens=dtens+val
	else
	 ierr=1
	endif
!	write(cons_out,'("DEBUG(tensor_algebra::tensor_block_fcontract_dlf_r4): kernel time/error code: ",F10.4,1x,i3)') secnds(time_beg),ierr !debug
	return
	end subroutine tensor_block_fcontract_dlf_r4
!--------------------------------------------------------------------------
	subroutine tensor_block_fcontract_dlf_r8(dc,ltens,rtens,dtens,ierr) !PARALLEL
!This subroutine fully reduces two vectors derived from the corresponding tensors by index permutations:
!dtens+=ltens(0:dc-1)*rtens(0:dc-1), where dtens is a scalar.
	implicit none
!---------------------------------------
	integer, parameter:: real_kind=8 !real data kind
!---------------------------------------
	integer(8), intent(in):: dc
	real(real_kind), intent(in):: ltens(0:*),rtens(0:*) !true tensors
	real(real_kind), intent(inout):: dtens !scalar
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n
	real(real_kind) val
	integer(8) l0
	real(4) time_beg

	ierr=0
!	time_beg=secnds(0.) !debug
!	write(cons_out,'("DEBUG(tensor_algebra::tensor_block_fcontract_dlf_r8): dc: ",i9)') dc !debug
	if(dc.gt.0_8) then
	 val=0d0
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0) SCHEDULE(GUIDED) REDUCTION(+:val)
	 do l0=0_8,dc-1_8; val=val+ltens(l0)*rtens(l0); enddo
!$OMP END PARALLEL DO
	 dtens=dtens+val
	else
	 ierr=1
	endif
!	write(cons_out,'("DEBUG(tensor_algebra::tensor_block_fcontract_dlf_r8): kernel time/error code: ",F10.4,1x,i3)') secnds(time_beg),ierr !debug
	return
	end subroutine tensor_block_fcontract_dlf_r8
!--------------------------------------------------------------------------------
	subroutine tensor_block_pcontract_dlf_r4(dl,dr,dc,ltens,rtens,dtens,ierr) !PARALLEL
!This subroutine multiplies two matrices derived from the corresponding tensors by index permutations:
!dtens(0:dl-1,0:dr-1)+=ltens(0:dc-1,0:dl-1)*rtens(0:dc-1,0:dr-1)
!The result is a matrix as well (cannot be a scalar, see tensor_block_fcontract).
!The algorithm is cache-efficient (Author: Dmitry I. Lyakh (Dmytro I. Liakh): quant4me@gmail.com).
	implicit none
!---------------------------------------------------
	integer, parameter:: real_kind=4             !real data kind
	integer(8), parameter:: red_mat_size=32      !the size of the local reduction matrix
	integer(8), parameter:: arg_cache_size=2**15 !cache-size dependent parameter (increase it as there are more cores per node)
	integer, parameter:: min_distr_seg_size=128  !min segment size of an omp distributed dimension
	integer, parameter:: cdim_stretch=2          !makes the segmentation of the contracted dimension coarser
	integer, parameter:: core_slope=16           !regulates the slope of the segment size of the distributed dimension w.r.t. the number of cores
	integer, parameter:: ker1=0                  !kernel 1 scheme #
	integer, parameter:: ker2=0                  !kernel 2 scheme #
	integer, parameter:: ker3=0                  !kernel 3 scheme #
!---------------------------------------------------
	logical, parameter:: no_case1=.false.
	logical, parameter:: no_case2=.false.
	logical, parameter:: no_case3=.false.
	logical, parameter:: no_case4=.false.
!---------------------------------------------------
	integer(8), intent(in):: dl,dr,dc !matrix dimensions
	real(real_kind), intent(in):: ltens(0:*),rtens(0:*) !input arguments
	real(real_kind), intent(inout):: dtens(0:*) !output argument
	integer, intent(inout):: ierr !error code
	integer i,j,k,l,m,n,nthr
	integer(8) l0,l1,l2,ll,lr,ld,ls,lf,b0,b1,b2,e0,e1,e2,cl,cr,cc,chunk
	real(real_kind) val,redm(0:red_mat_size-1,0:red_mat_size-1)
	real(4) time_beg
	integer, external:: omp_get_max_threads

	ierr=0
!	time_beg=secnds(0.) !debug
	if(dl.gt.0_8.and.dr.gt.0_8.and.dc.gt.0_8) then
#ifndef NO_OMP
	 nthr=omp_get_max_threads()
#else
	 nthr=1
#endif
	 if(dr.ge.core_slope*nthr.and.(.not.no_case1)) then !the right dimension is large enough to be distributed
!	  write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r4): kernel case/scheme: 1/",i1)') ker1 !debug
	  select case(ker1)
	  case(0)
!SCHEME 0:
	   cr=min(dr,max(core_slope*nthr,min_distr_seg_size))
	   cc=min(dc,max(arg_cache_size*cdim_stretch/cr,1_8))
	   cl=min(dl,min(max(arg_cache_size/cc,1_8),max(arg_cache_size/cr,1_8)))
!	   write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r4): cl,cr,cc,dl,dr,dc:",6(1x,i9))') cl,cr,cc,dl,dr,dc !debug
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(b0,b1,b2,e0,e1,e2,l0,l1,l2,ll,lr,ld,val)
	   do b0=0_8,dc-1_8,cc
	    e0=min(b0+cc-1_8,dc-1_8)
	    do b1=0_8,dl-1_8,cl
	     e1=min(b1+cl-1_8,dl-1_8)
	     do b2=0_8,dr-1_8,cr
	      e2=min(b2+cr-1_8,dr-1_8)
!$OMP DO SCHEDULE(GUIDED)
	      do l2=b2,e2
	       lr=l2*dc; ld=l2*dl
	       do l1=b1,e1
	        ll=l1*dc
	        val=dtens(ld+l1)
	        do l0=b0,e0; val=val+ltens(ll+l0)*rtens(lr+l0); enddo
	        dtens(ld+l1)=val
	       enddo
	      enddo
!$OMP END DO NOWAIT
	     enddo
	    enddo
!$OMP BARRIER
	   enddo
!$OMP END PARALLEL
	  case(1)
!SCHEME 1:
	   chunk=max(arg_cache_size/dc,1_8)
!           write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r4): chunk,dl,dr,dc:",4(1x,i9))') chunk,dl,dr,dc !debug
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(l0,l1,l2,ll,lr,ld,ls,lf,val)
	   do ls=0_8,dl-1_8,chunk
	    lf=min(ls+chunk-1_8,dl-1_8)
!!$OMP DO SCHEDULE(DYNAMIC,chunk)
!$OMP DO SCHEDULE(GUIDED)
	    do l2=0_8,dr-1_8
	     lr=l2*dc; ld=l2*dl
	     do l1=ls,lf
	      ll=l1*dc
	      val=dtens(ld+l1)
	      do l0=0_8,dc-1_8; val=val+ltens(ll+l0)*rtens(lr+l0); enddo
	      dtens(ld+l1)=val
	     enddo
	    enddo
!$OMP END DO NOWAIT
	   enddo
!$OMP END PARALLEL
	  case(2)
!SCHEME 2:
	   chunk=max(arg_cache_size/dc,1_8)
	   if(mod(dl,chunk).ne.0) then; ls=dl/chunk+1_8; else; ls=dl/chunk; endif
	   if(mod(dr,chunk).ne.0) then; lf=dr/chunk+1_8; else; lf=dr/chunk; endif
!	   write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r4): chunk,ls,lf,dl,dr,dc:",6(1x,i9))') chunk,ls,lf,dl,dr,dc !debug
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(b0,b1,b2,l0,l1,l2,ll,lr,ld,val) SCHEDULE(GUIDED)
	   do b0=0_8,lf*ls-1_8
	    b2=b0/ls*chunk; b1=mod(b0,ls)*chunk
	    do l2=b2,min(b2+chunk-1_8,dr-1_8)
	     lr=l2*dc; ld=l2*dl
	     do l1=b1,min(b1+chunk-1_8,dl-1_8)
	      ll=l1*dc
	      val=dtens(ld+l1)
	      do l0=0_8,dc-1_8; val=val+ltens(ll+l0)*rtens(lr+l0); enddo
	      dtens(ld+l1)=val
	     enddo
	    enddo
	   enddo
!$OMP END PARALLEL DO
	  case(3)
!SCHEME 3:
!	   write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r4): dl,dr,dc:",3(1x,i9))') dl,dr,dc !debug
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0,l1,l2,ll,lr,ld,val) SCHEDULE(DYNAMIC)
	   do l2=0_8,dr-1_8
	    lr=l2*dc; ld=l2*dl
	    do l1=0_8,dl-1_8
	     ll=l1*dc
	     val=dtens(ld+l1)
	     do l0=0_8,dc-1_8; val=val+ltens(ll+l0)*rtens(lr+l0); enddo
	     dtens(ld+l1)=val
	    enddo
	   enddo
!$OMP END PARALLEL DO
	  case default
	   ierr=-1
	  end select
	 else !dr is small
	  if(dl.ge.core_slope*nthr.and.(.not.no_case2)) then !the left dimension is large enough to be distributed
!	   write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r4): kernel case/scheme: 2/",i1)') ker2 !debug
	   select case(ker2)
	   case(0)
!SCHEME 0:
!            write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r4): dl,dr,dc:",3(1x,i9))') dl,dr,dc !debug
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(l0,l1,l2,ll,lr,ld,val)
	    do l2=0_8,dr-1_8
	     lr=l2*dc; ld=l2*dl
!$OMP DO SCHEDULE(GUIDED)
	     do l1=0_8,dl-1_8
	      ll=l1*dc
	      val=dtens(ld+l1)
	      do l0=0_8,dc-1_8; val=val+ltens(ll+l0)*rtens(lr+l0); enddo
	      dtens(ld+l1)=val
	     enddo
!$OMP END DO NOWAIT
	    enddo
!$OMP END PARALLEL
	   case(1)
!SCHEME 1:
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0,l1,l2,ll,lr,val) SCHEDULE(GUIDED) COLLAPSE(2)
	    do l2=0_8,dr-1_8
	     do l1=0_8,dl-1_8
	      ll=l1*dc; lr=l2*dc
	      val=dtens(l2*dl+l1)
	      do l0=0_8,dc-1_8; val=val+ltens(ll+l0)*rtens(lr+l0); enddo
	      dtens(l2*dl+l1)=val
	     enddo
	    enddo
!$OMP END PARALLEL DO
	   case default
	    ierr=-2
	   end select
	  else !dr & dl are both small
	   if(dc.ge.core_slope*nthr.and.(.not.no_case3)) then !the contraction dimension is large enough to be distributed
!	    write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r4): kernel case/scheme: 3/",i1)') ker3 !debug
	    select case(ker3)
	    case(0)
!SCHEME 0:
!             write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r4): dl,dr,dc:",3(1x,i9))') dl,dr,dc !debug
             redm(:,:)=0.0
             do b2=0_8,dr-1_8,red_mat_size
              e2=min(red_mat_size-1_8,dr-1_8-b2)
              do b1=0_8,dl-1_8,red_mat_size
               e1=min(red_mat_size-1_8,dl-1_8-b1)
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(l0,l1,l2,ll,lr)
	       do l2=0_8,e2
	        lr=(b2+l2)*dc
	        do l1=0_8,e1
	         ll=(b1+l1)*dc
!$OMP MASTER
	         val=0.0
!$OMP END MASTER
!$OMP BARRIER
!$OMP DO SCHEDULE(GUIDED) REDUCTION(+:val)
	         do l0=0_8,dc-1_8; val=val+ltens(ll+l0)*rtens(lr+l0); enddo
!$OMP END DO
!$OMP MASTER
		 redm(l1,l2)=val
!$OMP END MASTER
	        enddo
	       enddo
!$OMP END PARALLEL
	       do l2=0_8,e2
	        ld=(b2+l2)*dl
	        do l1=0_8,e1
	         dtens(ld+b1+l1)=dtens(ld+b1+l1)+redm(l1,l2)
	        enddo
	       enddo
	      enddo
	     enddo
	    case default
	     ierr=-3
	    end select
	   else !dr & dl & dc are all small
	    if(dr*dl.ge.core_slope*nthr.and.(.not.no_case4)) then !the destination matrix is large enough to be distributed
!	     write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r4): kernel case: 4")') !debug
!	     write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r4): dl,dr,dc:",3(1x,i9))') dl,dr,dc !debug
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0,l1,l2,ll,lr,val) SCHEDULE(GUIDED) COLLAPSE(2)
	     do l2=0_8,dr-1_8
	      do l1=0_8,dl-1_8
	       ll=l1*dc; lr=l2*dc
	       val=dtens(l2*dl+l1)
	       do l0=0_8,dc-1_8; val=val+ltens(ll+l0)*rtens(lr+l0); enddo
	       dtens(l2*dl+l1)=val
	      enddo
	     enddo
!$OMP END PARALLEL DO
	    else !all matrices are very small (serial execution)
!	     write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r4): kernel case: 5 (serial)")') !debug
!	     write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r4): dl,dr,dc:",3(1x,i9))') dl,dr,dc !debug
	     do l2=0_8,dr-1_8
	      lr=l2*dc; ld=l2*dl
	      do l1=0_8,dl-1_8
	       ll=l1*dc
	       val=dtens(ld+l1)
	       do l0=0_8,dc-1_8; val=val+ltens(ll+l0)*rtens(lr+l0); enddo
	       dtens(ld+l1)=val
	      enddo
	     enddo
	    endif
	   endif
	  endif
	 endif
	else
	 ierr=1
	endif
!	write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r4): kernel time/error code: ",F10.4,1x,i3)') secnds(time_beg),ierr !debug
	return
	end subroutine tensor_block_pcontract_dlf_r4
!--------------------------------------------------------------------------------
	subroutine tensor_block_pcontract_dlf_r8(dl,dr,dc,ltens,rtens,dtens,ierr) !PARALLEL
!This subroutine multiplies two matrices derived from the corresponding tensors by index permutations:
!dtens(0:dl-1,0:dr-1)+=ltens(0:dc-1,0:dl-1)*rtens(0:dc-1,0:dr-1)
!The result is a matrix as well (cannot be a scalar, see tensor_block_fcontract).
!The algorithm is cache-efficient (Author: Dmitry I. Lyakh (Dmytro I. Liakh): quant4me@gmail.com).
	implicit none
!---------------------------------------------------
	integer, parameter:: real_kind=8             !real data kind
	integer(8), parameter:: red_mat_size=32      !the size of the local reduction matrix
	integer(8), parameter:: arg_cache_size=2**15 !cache-size dependent parameter (increase it as there are more cores per node)
	integer, parameter:: min_distr_seg_size=128  !min segment size of an omp distributed dimension
	integer, parameter:: cdim_stretch=2          !makes the segmentation of the contracted dimension coarser
	integer, parameter:: core_slope=16           !regulates the slope of the segment size of the distributed dimension w.r.t. the number of cores
	integer, parameter:: ker1=0                  !kernel 1 scheme #
	integer, parameter:: ker2=0                  !kernel 2 scheme #
	integer, parameter:: ker3=0                  !kernel 3 scheme #
!---------------------------------------------------
	logical, parameter:: no_case1=.false.
	logical, parameter:: no_case2=.false.
	logical, parameter:: no_case3=.false.
	logical, parameter:: no_case4=.false.
!---------------------------------------------------
	integer(8), intent(in):: dl,dr,dc !matrix dimensions
	real(real_kind), intent(in):: ltens(0:*),rtens(0:*) !input arguments
	real(real_kind), intent(inout):: dtens(0:*) !output argument
	integer, intent(inout):: ierr !error code
	integer i,j,k,l,m,n,nthr
	integer(8) l0,l1,l2,ll,lr,ld,ls,lf,b0,b1,b2,e0,e1,e2,cl,cr,cc,chunk
	real(real_kind) val,redm(0:red_mat_size-1,0:red_mat_size-1)
	real(4) time_beg
	integer, external:: omp_get_max_threads

	ierr=0
!	time_beg=secnds(0.) !debug
	if(dl.gt.0_8.and.dr.gt.0_8.and.dc.gt.0_8) then
#ifndef NO_OMP
	 nthr=omp_get_max_threads()
#else
	 nthr=1
#endif
	 if(dr.ge.core_slope*nthr.and.(.not.no_case1)) then !the right dimension is large enough to be distributed
!	  write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r8): kernel case/scheme: 1/",i1)') ker1 !debug
	  select case(ker1)
	  case(0)
!SCHEME 0:
	   cr=min(dr,max(core_slope*nthr,min_distr_seg_size))
	   cc=min(dc,max(arg_cache_size*cdim_stretch/cr,1_8))
	   cl=min(dl,min(max(arg_cache_size/cc,1_8),max(arg_cache_size/cr,1_8)))
!	   write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r8): cl,cr,cc,dl,dr,dc:",6(1x,i9))') cl,cr,cc,dl,dr,dc !debug
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(b0,b1,b2,e0,e1,e2,l0,l1,l2,ll,lr,ld,val)
	   do b0=0_8,dc-1_8,cc
	    e0=min(b0+cc-1_8,dc-1_8)
	    do b1=0_8,dl-1_8,cl
	     e1=min(b1+cl-1_8,dl-1_8)
	     do b2=0_8,dr-1_8,cr
	      e2=min(b2+cr-1_8,dr-1_8)
!$OMP DO SCHEDULE(GUIDED)
	      do l2=b2,e2
	       lr=l2*dc; ld=l2*dl
	       do l1=b1,e1
	        ll=l1*dc
	        val=dtens(ld+l1)
	        do l0=b0,e0; val=val+ltens(ll+l0)*rtens(lr+l0); enddo
	        dtens(ld+l1)=val
	       enddo
	      enddo
!$OMP END DO NOWAIT
	     enddo
	    enddo
!$OMP BARRIER
	   enddo
!$OMP END PARALLEL
	  case(1)
!SCHEME 1:
	   chunk=max(arg_cache_size/dc,1_8)
!           write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r8): chunk,dl,dr,dc:",4(1x,i9))') chunk,dl,dr,dc !debug
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(l0,l1,l2,ll,lr,ld,ls,lf,val)
	   do ls=0_8,dl-1_8,chunk
	    lf=min(ls+chunk-1_8,dl-1_8)
!!$OMP DO SCHEDULE(DYNAMIC,chunk)
!$OMP DO SCHEDULE(GUIDED)
	    do l2=0_8,dr-1_8
	     lr=l2*dc; ld=l2*dl
	     do l1=ls,lf
	      ll=l1*dc
	      val=dtens(ld+l1)
	      do l0=0_8,dc-1_8; val=val+ltens(ll+l0)*rtens(lr+l0); enddo
	      dtens(ld+l1)=val
	     enddo
	    enddo
!$OMP END DO NOWAIT
	   enddo
!$OMP END PARALLEL
	  case(2)
!SCHEME 2:
	   chunk=max(arg_cache_size/dc,1_8)
	   if(mod(dl,chunk).ne.0) then; ls=dl/chunk+1_8; else; ls=dl/chunk; endif
	   if(mod(dr,chunk).ne.0) then; lf=dr/chunk+1_8; else; lf=dr/chunk; endif
!	   write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r8): chunk,ls,lf,dl,dr,dc:",6(1x,i9))') chunk,ls,lf,dl,dr,dc !debug
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(b0,b1,b2,l0,l1,l2,ll,lr,ld,val) SCHEDULE(GUIDED)
	   do b0=0_8,lf*ls-1_8
	    b2=b0/ls*chunk; b1=mod(b0,ls)*chunk
	    do l2=b2,min(b2+chunk-1_8,dr-1_8)
	     lr=l2*dc; ld=l2*dl
	     do l1=b1,min(b1+chunk-1_8,dl-1_8)
	      ll=l1*dc
	      val=dtens(ld+l1)
	      do l0=0_8,dc-1_8; val=val+ltens(ll+l0)*rtens(lr+l0); enddo
	      dtens(ld+l1)=val
	     enddo
	    enddo
	   enddo
!$OMP END PARALLEL DO
	  case(3)
!SCHEME 3:
!	   write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r8): dl,dr,dc:",3(1x,i9))') dl,dr,dc !debug
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0,l1,l2,ll,lr,ld,val) SCHEDULE(DYNAMIC)
	   do l2=0_8,dr-1_8
	    lr=l2*dc; ld=l2*dl
	    do l1=0_8,dl-1_8
	     ll=l1*dc
	     val=dtens(ld+l1)
	     do l0=0_8,dc-1_8; val=val+ltens(ll+l0)*rtens(lr+l0); enddo
	     dtens(ld+l1)=val
	    enddo
	   enddo
!$OMP END PARALLEL DO
	  case default
	   ierr=-1
	  end select
	 else !dr is small
	  if(dl.ge.core_slope*nthr.and.(.not.no_case2)) then !the left dimension is large enough to be distributed
!	   write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r8): kernel case/scheme: 2/",i1)') ker2 !debug
	   select case(ker2)
	   case(0)
!SCHEME 0:
!            write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r8): dl,dr,dc:",3(1x,i9))') dl,dr,dc !debug
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(l0,l1,l2,ll,lr,ld,val)
	    do l2=0_8,dr-1_8
	     lr=l2*dc; ld=l2*dl
!$OMP DO SCHEDULE(GUIDED)
	     do l1=0_8,dl-1_8
	      ll=l1*dc
	      val=dtens(ld+l1)
	      do l0=0_8,dc-1_8; val=val+ltens(ll+l0)*rtens(lr+l0); enddo
	      dtens(ld+l1)=val
	     enddo
!$OMP END DO NOWAIT
	    enddo
!$OMP END PARALLEL
	   case(1)
!SCHEME 1:
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0,l1,l2,ll,lr,val) SCHEDULE(GUIDED) COLLAPSE(2)
	    do l2=0_8,dr-1_8
	     do l1=0_8,dl-1_8
	      ll=l1*dc; lr=l2*dc
	      val=dtens(l2*dl+l1)
	      do l0=0_8,dc-1_8; val=val+ltens(ll+l0)*rtens(lr+l0); enddo
	      dtens(l2*dl+l1)=val
	     enddo
	    enddo
!$OMP END PARALLEL DO
	   case default
	    ierr=-2
	   end select
	  else !dr & dl are both small
	   if(dc.ge.core_slope*nthr.and.(.not.no_case3)) then !the contraction dimension is large enough to be distributed
!	    write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r8): kernel case/scheme: 3/",i1)') ker3 !debug
	    select case(ker3)
	    case(0)
!SCHEME 0:
!             write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r8): dl,dr,dc:",3(1x,i9))') dl,dr,dc !debug
             redm(:,:)=0d0
             do b2=0_8,dr-1_8,red_mat_size
              e2=min(red_mat_size-1_8,dr-1_8-b2)
              do b1=0_8,dl-1_8,red_mat_size
               e1=min(red_mat_size-1_8,dl-1_8-b1)
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(l0,l1,l2,ll,lr)
	       do l2=0_8,e2
	        lr=(b2+l2)*dc
	        do l1=0_8,e1
	         ll=(b1+l1)*dc
!$OMP MASTER
	         val=0d0
!$OMP END MASTER
!$OMP BARRIER
!$OMP DO SCHEDULE(GUIDED) REDUCTION(+:val)
	         do l0=0_8,dc-1_8; val=val+ltens(ll+l0)*rtens(lr+l0); enddo
!$OMP END DO
!$OMP MASTER
		 redm(l1,l2)=val
!$OMP END MASTER
	        enddo
	       enddo
!$OMP END PARALLEL
	       do l2=0_8,e2
	        ld=(b2+l2)*dl
	        do l1=0_8,e1
	         dtens(ld+b1+l1)=dtens(ld+b1+l1)+redm(l1,l2)
	        enddo
	       enddo
	      enddo
	     enddo
	    case default
	     ierr=-3
	    end select
	   else !dr & dl & dc are all small
	    if(dr*dl.ge.core_slope*nthr.and.(.not.no_case4)) then !the destination matrix is large enough to be distributed
!	     write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r8): kernel case: 4")') !debug
!	     write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r8): dl,dr,dc:",3(1x,i9))') dl,dr,dc !debug
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(l0,l1,l2,ll,lr,val) SCHEDULE(GUIDED) COLLAPSE(2)
	     do l2=0_8,dr-1_8
	      do l1=0_8,dl-1_8
	       ll=l1*dc; lr=l2*dc
	       val=dtens(l2*dl+l1)
	       do l0=0_8,dc-1_8; val=val+ltens(ll+l0)*rtens(lr+l0); enddo
	       dtens(l2*dl+l1)=val
	      enddo
	     enddo
!$OMP END PARALLEL DO
	    else !all matrices are very small (serial execution)
!	     write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r8): kernel case: 5 (serial)")') !debug
!	     write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r8): dl,dr,dc:",3(1x,i9))') dl,dr,dc !debug
	     do l2=0_8,dr-1_8
	      lr=l2*dc; ld=l2*dl
	      do l1=0_8,dl-1_8
	       ll=l1*dc
	       val=dtens(ld+l1)
	       do l0=0_8,dc-1_8; val=val+ltens(ll+l0)*rtens(lr+l0); enddo
	       dtens(ld+l1)=val
	      enddo
	     enddo
	    endif
	   endif
	  endif
	 endif
	else
	 ierr=1
	endif
!	write(cons_out,'("DEBUG(tensor_algebra::tensor_block_pcontract_dlf_r8): kernel time/error code: ",F10.4,1x,i3)') secnds(time_beg),ierr !debug
	return
	end subroutine tensor_block_pcontract_dlf_r8
!------------------------------------------------------------------------------------------------------
	subroutine tensor_block_ftrace_dlf_r8(contr_ptrn,ord_rest,tens_in,rank_in,dims_in,val_out,ierr) !PARALLEL
!This subroutine takes a full trace in a tensor block and accumulates it into a scalar.
!A full trace consists of one or more pairwise index contractions such that no single index is left uncontracted.
!Consequently, only even rank tensor blocks can be passed here.
!INPUT:
! - contr_ptrn(1:rank_in) - index contraction pattern;
! - ord_rest(1:rank_in) - index ordering restrictions (for contracted indices);
! - tens_in - input tensor block;
! - rank_in - rank of <tens_in>;
! - dims_in(1:rank_in) - dimension extents of <tens_in>;
! - val_out - initialized! scalar;
!OUTPUT:
! - val_out - modified scalar (the trace has been accumulated in);
! - ierr - error code (0:success).
!NOTES:
! - The algorithm used here is not cache-efficient, and I doubt there is any (D.I.L.).
! - No thorough argument checks.
!`Enable index ordering restrictions.
	implicit none
!---------------------------------------
	integer, parameter:: real_kind=8
!---------------------------------------
	integer, intent(in):: rank_in,contr_ptrn(1:rank_in),ord_rest(1:rank_in),dims_in(1:rank_in)
	real(real_kind), intent(in):: tens_in(0:*)
	real(real_kind), intent(inout):: val_out
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n,ks,kf,im(1:rank_in),ic(1:rank_in)
	integer(8) bases_in(1:rank_in),bases_tr(1:rank_in),segs(0:max_threads),ls,lc,l_in,l0
	real(real_kind) val_tr
	real(4) time_beg
	integer, external:: omp_get_thread_num,omp_get_num_threads

	ierr=0
!	time_beg=secnds(0.) !debug
	if(rank_in.gt.0.and.mod(rank_in,2).eq.0) then !even rank since index contractions are pairwise
!Set index links:
	 do i=1,rank_in
	  j=contr_ptrn(i)
	  if(j.lt.0) then !contracted index
	   if(-j.gt.rank_in) then; ierr=5; return; endif
	   if(contr_ptrn(-j).ne.-i) then; ierr=8; return; endif
	   if(dims_in(-j).ne.dims_in(i)) then; ierr=6; return; endif
	   if(-j.gt.i) then; ic(i)=-j; elseif(-j.lt.i) then; ic(i)=0; else; ierr=3; return; endif
	  else
	   ierr=4; return
	  endif
	 enddo
!Compute indexing bases:
	 ls=1_8; do i=1,rank_in; bases_in(i)=ls; ls=ls*dims_in(i); enddo !total size of the tensor block
	 lc=1_8; do i=1,rank_in; if(ic(i).gt.0) then; bases_tr(i)=lc; lc=lc*dims_in(i); else; bases_tr(i)=1_8; endif; enddo !size of the trace range
!Trace:
	 if(lc.gt.1_8) then !tracing over multiple elements
	  val_tr=0d0
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(i,j,m,n,l0,l_in,im) REDUCTION(+:val_tr)
#ifndef NO_OMP
	  n=omp_get_thread_num(); m=omp_get_num_threads()
#else
	  n=0; m=1
#endif
!$OMP MASTER
	  segs(0)=0_8; call divide_segment(lc,int(m,8),segs(1:),ierr); do i=2,m; segs(i)=segs(i)+segs(i-1); enddo
!$OMP END MASTER
!$OMP BARRIER
!$OMP FLUSH(segs)
	  l0=segs(n); do i=rank_in,1,-1; if(ic(i).gt.0) then; im(i)=l0/bases_tr(i); l0=mod(l0,bases_tr(i)); im(ic(i))=im(i); endif; enddo !init multiindex for each thread
	  l_in=im(1); do i=2,rank_in; l_in=l_in+im(i)*bases_in(i); enddo !start offset for each thread
	  tloop: do l0=segs(n),segs(n+1)-1_8
	   val_tr=val_tr+tens_in(l_in)
	   do i=1,rank_in
	    j=ic(i)
	    if(j.gt.0) then
	     if(im(i)+1.lt.dims_in(i)) then
	      im(i)=im(i)+1; im(j)=im(j)+1; l_in=l_in+bases_in(i)+bases_in(j)
	      cycle tloop
	     else
	      l_in=l_in-im(i)*bases_in(i)-im(j)*bases_in(j); im(i)=0; im(j)=0
	     endif
	    endif
	   enddo
	   exit tloop
	  enddo tloop
!$OMP END PARALLEL
	  val_out=val_out+val_tr
	 elseif(lc.eq.1_8) then !tracing over only one element
	  if(ls.ne.1_8) then; ierr=7; return; endif
	  val_out=val_out+tens_in(0)
	 else
	  ierr=2 !negative or zero trace range
	 endif
	else
	 ierr=1 !negative or zero tensor rank
	endif
!	write(cons_out,'("DEBUG(tensor_algebra::tensor_block_ftrace_dlf_r8): kernel time/error code: ",F10.4,1x,i3)') secnds(time_beg),ierr !debug
	return
	end subroutine tensor_block_ftrace_dlf_r8
!-------------------------------------------------------------------------------------------------------------------------
	subroutine tensor_block_ptrace_dlf_r8(contr_ptrn,ord_rest,tens_in,rank_in,dims_in,tens_out,rank_out,dims_out,ierr) !PARALLEL
!This subroutine takes a partial trace in a tensor block and accumulates it into the destination tensor block.
!A partial trace consists of one or more pairwise index contractions such that at least one index is left uncontracted.
!INPUT:
! - contr_ptrn(1:rank_in) - index contraction pattern;
! - ord_rest(1:rank_in) - index ordering restrictions (for contracted indices);
! - tens_in - input tensor block;
! - rank_in - rank of <tens_in>;
! - dims_in(1:rank_in) - dimension extents of <tens_in>;
! - tens_out - initialized! output tensor block;
! - rank_out - rank of <tens_out>;
! - dims_out(1:rank_out) - dimension extents of <tens_out>;
!OUTPUT:
! - tens_out - modified output tensor block;
! - ierr - error code (0:success).
!NOTES:
! - The algorithm used here is not cache-efficient, and I doubt there is any (D.I.L.).
! - No thorough argument checks.
!`Enable index ordering restrictions.
	implicit none
!---------------------------------------
	integer, parameter:: real_kind=8
!---------------------------------------
	integer, intent(in):: rank_in,rank_out,contr_ptrn(1:rank_in),ord_rest(1:rank_in),dims_in(1:rank_in),dims_out(1:rank_out)
	real(real_kind), intent(in):: tens_in(0:*)
	real(real_kind), intent(inout):: tens_out(0:*)
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n,ks,kf,im(1:rank_in),ic(1:rank_in),ip(1:rank_out)
	integer(8) bases_in(1:rank_in),bases_out(1:rank_out),bases_tr(1:rank_in),segs(0:max_threads),li,lo,lc,l_in,l_out,l0
	real(real_kind) val_tr
	real(4) time_beg
	integer, external:: omp_get_thread_num,omp_get_num_threads

	ierr=0
!	time_beg=secnds(0.) !debug
	if(rank_out.gt.0.and.rank_out.lt.rank_in.and.mod(rank_in-rank_out,2).eq.0) then !even rank difference because of pairwise index contractions
!Set index links:
	 ip(1:rank_out)=0
	 do i=1,rank_in
	  j=contr_ptrn(i)
	  if(j.lt.0) then !contracted index
	   if(-j.gt.rank_in) then; ierr=5; return; endif
	   if(contr_ptrn(-j).ne.-i) then; ierr=8; return; endif
	   if(dims_in(-j).ne.dims_in(i)) then; ierr=6; return; endif
	   if(-j.gt.i) then; ic(i)=-j; elseif(-j.lt.i) then; ic(i)=0; else; ierr=3; return; endif
	  elseif(j.gt.0) then !uncontracted index
	   if(j.gt.rank_out) then; ierr=4; return; endif
	   if(dims_out(j).ne.dims_in(i)) then; ierr=7; return; endif
	   if(ip(j).eq.0) then; ip(j)=ip(j)+1; else; ierr=9; return; endif
	   ic(i)=-j
	  else
	   ierr=2; return
	  endif
	 enddo
	 do i=1,rank_out; if(ip(i).ne.1) then; ierr=11; return; endif; enddo
	 do i=1,rank_in; if(ic(i).lt.0) then; ip(-ic(i))=i; endif; enddo
!Compute indexing bases:
	 li=1_8; lc=1_8
	 do i=1,rank_in
	  bases_in(i)=li; li=li*dims_in(i) !input indexing bases
	  if(ic(i).gt.0) then; bases_tr(i)=lc; lc=lc*dims_in(i); else; bases_tr(i)=1_8; endif !trace range bases
	 enddo
	 lo=1_8; do i=1,rank_out; bases_out(i)=lo; lo=lo*dims_out(i); enddo !output indexing bases
!Trace:
	 if(lo.ge.1_8.and.li.gt.1_8) then
	  if(lo.gt.lc) then !Scheme 1
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(i,j,m,n,l0,l_in,l_out,im,val_tr)
#ifndef NO_OMP
	   n=omp_get_thread_num(); m=omp_get_num_threads()
#else
	   n=0; m=1
#endif
!$OMP MASTER
	   segs(0)=0_8; call divide_segment(lo,int(m,8),segs(1:),ierr); do i=2,m; segs(i)=segs(i)+segs(i-1); enddo
!$OMP END MASTER
!$OMP BARRIER
!$OMP FLUSH(segs)
	   do l_out=segs(n),segs(n+1)-1_8
	    im(1:rank_in)=0; l0=l_out; do i=rank_out,1,-1; im(ip(i))=l0/bases_out(i); l0=mod(l0,bases_out(i)); enddo
	    l_in=im(1); do i=2,rank_in; l_in=l_in+im(i)*bases_in(i); enddo
	    val_tr=0d0
	    cloop: do l0=0_8,lc-1_8
	     val_tr=val_tr+tens_in(l_in)
	     do i=1,rank_in
	      j=ic(i)
	      if(j.gt.0) then
	       if(im(i)+1.lt.dims_in(i)) then
	        im(i)=im(i)+1; im(j)=im(j)+1; l_in=l_in+bases_in(i)+bases_in(j)
	        cycle cloop
	       else
	        l_in=l_in-im(i)*bases_in(i)-im(j)*bases_in(j); im(i)=0; im(j)=0
	       endif
	      endif
	     enddo
	     exit cloop
	    enddo cloop
	    tens_out(l_out)=tens_out(l_out)+val_tr
	   enddo
!$OMP END PARALLEL
	  else !Scheme 2
!$OMP PARALLEL DEFAULT(SHARED) PRIVATE(i,j,m,n,l0,l_in,l_out,im,val_tr)
#ifndef NO_OMP
	   n=omp_get_thread_num(); m=omp_get_num_threads()
#else
	   n=0; m=1
#endif
!$OMP MASTER
	   segs(0)=0_8; call divide_segment(lc,int(m,8),segs(1:),ierr); do i=2,m; segs(i)=segs(i)+segs(i-1); enddo
!$OMP END MASTER
!$OMP BARRIER
!$OMP FLUSH(segs)
	   do l_out=0_8,lo-1_8
	    l0=l_out; do i=rank_out,1,-1; im(ip(i))=l0/bases_out(i); l0=mod(l0,bases_out(i)); enddo
	    l0=segs(n); do i=rank_in,1,-1; if(ic(i).gt.0) then; im(i)=l0/bases_tr(i); l0=mod(l0,bases_tr(i)); im(ic(i))=im(i); endif; enddo
	    l_in=im(1); do i=2,rank_in; l_in=l_in+im(i)*bases_in(i); enddo
	    val_tr=0d0
	    tloop: do l0=segs(n),segs(n+1)-1_8
	     val_tr=val_tr+tens_in(l_in)
	     do i=1,rank_in
	      j=ic(i)
	      if(j.gt.0) then
	       if(im(i)+1.lt.dims_in(i)) then
	        im(i)=im(i)+1; im(j)=im(j)+1; l_in=l_in+bases_in(i)+bases_in(j)
	        cycle tloop
	       else
	        l_in=l_in-im(i)*bases_in(i)-im(j)*bases_in(j); im(i)=0; im(j)=0
	       endif
	      endif
	     enddo
	     exit tloop
	    enddo tloop
!$OMP ATOMIC
	    tens_out(l_out)=tens_out(l_out)+val_tr
	   enddo
!$OMP END PARALLEL
	  endif
	 elseif(lo.eq.1_8.and.li.eq.1_8) then
	  tens_out(0)=tens_out(0)+tens_in(0)
	 else
	  ierr=10
	 endif
	else
	 ierr=1
	endif
!	write(cons_out,'("DEBUG(tensor_algebra::tensor_block_ptrace_dlf_r8): kernel time/error code: ",F10.4,1x,i3)') secnds(time_beg),ierr !debug
	return
	end subroutine tensor_block_ptrace_dlf_r8

       end module tensor_algebra

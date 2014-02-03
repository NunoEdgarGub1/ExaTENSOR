        subroutine proceed(ierr) !PARALLEL
!This subroutine assigns a role to each MPI process:
! - MPI process 0: Global Root.
! - The subsequent range of MPI process numbers is divided into
!   Computing Groups (contiguous segments of process numbers),
!   each group comprising a Local Root (1st process in the segment)
!   and Computing Processes (all other processes in the segment).
!   The number of computing processes per local root is determined
!   by qforce::c_procs_per_local_root. Thus, each computing group initially
!   contains (1+c_procs_per_local_root) processes. This number, as well
!   as process roles may change during run-time for load balancing purposes.
        use qforce
        use c_process
        implicit none
        integer, intent(inout):: ierr
        integer i,j,k,l,m,n,k0,k1,k2,k3

        ierr=0; write(jo,'("###LAUNCHED PROCESS ",i9)') impir

        call mpi_barrier(MPI_COMM_WORLD,ierr); if(ierr.ne.0) call quit(ierr,'#ERROR(proceed): MPI_BARRIER error (1)!')

	my_role=c_process_private
	call c_proc_life(ierr); if(ierr.ne.0) call quit(ierr,'#ERROR(proceed): C_PROCESS failed!')
	call mpi_barrier(MPI_COMM_WORLD,ierr); if(ierr.ne.0) call quit(ierr,'#ERROR(proceed): MPI_BARRIER error (2)!')
	return

        if(impir.eq.0) then !MPI root --> Global Root
         my_role=global_root; my_group=-1
!        call global_root_life(ierr); if(ierr.ne.0) call quit(ierr,'#ERROR(proceed): GLOBAL ROOT failed!')
        else !MPI slave --> Local Root OR Computing Process (C-process)
         i=impir-1; my_group=i/(1+c_procs_per_local_root)
         if(mod(i,(1+c_procs_per_local_root)).eq.0) then
          my_role=local_root
!         call local_root_life(ierr); if(ierr.ne.0) call quit(ierr,'#ERROR(proceed): LOCAL ROOT failed!')
         else
          my_role=c_process_private
          call c_proc_life(ierr); if(ierr.ne.0) call quit(ierr,'#ERROR(proceed): C_PROCESS failed!')
         endif
        endif
        call mpi_barrier(MPI_COMM_WORLD,ierr); if(ierr.ne.0) call quit(ierr,'#ERROR(proceed): MPI_BARRIER error (2)!')
        return
        end subroutine proceed

!--------------------------------------!DEBUG (everything below)
	subroutine test_stuff(ierr)
	use qforce
	use, intrinsic:: ISO_C_BINDING
	implicit none
	integer, intent(inout):: ierr
	integer i,j,k,l,m,n
	integer id1,id2,mnii,ia1
	integer(8) ivol(1:64),iba(0:127,1:64)

	ierr=0
!TEST MULTIINDEX ADDRESSING:
!	if(impir.eq.0) then
!	 do id2=1,9
!	  do id1=id2,id2+22,3
!	   do mnii=0,id2
!	    do ia1=max(id2-mnii-1,0),id1
!	     print *,'A:',id2,id1,mnii,ia1
!	     ierr=1; call get_mlndx_addressing(2,id1,id2,mnii,ia1,ivol(1:id2),iba(0:id1,1:id2),ierr); if(ierr.ne.0) call quit(-1,'I_FUCK!!!!!!!!')
!	    enddo
!	   enddo
!	  enddo
!	 enddo
!	 do id2=1,9
!	  do id1=id2,id2+22,3
!	   do mnii=0,id2
!	    do ia1=min(id1-(id2-mnii)+1,id1),0,-1
!	     print *,'I:',id2,id1,mnii,ia1
!	     ierr=1; call get_mlndx_addressing(1,id1,id2,mnii,ia1,ivol(1:id2),iba(0:id1,1:id2),ierr); if(ierr.ne.0) call quit(-1,'A_FUCK!!!!!!!!')
!	    enddo
!	   enddo
!	  enddo
!	 enddo
!	endif
!	call mpi_barrier(MPI_COMM_WORLD,ierr)

	return
	end subroutine test_stuff

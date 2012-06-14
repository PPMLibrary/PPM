      SUBROUTINE equi_mesh_map_ghost_put(this,info)
      !!! This routine sends the values of ghost mesh points
      !!! back to their origin in order to add their contribution to the
      !!! corresponding real mesh point.
      !!!
      !!! [IMPORTANT]
      !!! `ppm_map_field_ghost_init` must not be called anymore. This routine
      !!! checks wheterh the ghost mappings have been initialized already and
      !!! if not, the routine is called by the library.
      !!!
      !!! [NOTE]
      !!! The first part of the send/recv lists contains the on-processor data.

      !-------------------------------------------------------------------------
      !  Includes
      !-------------------------------------------------------------------------

      !-------------------------------------------------------------------------
      !  Modules
      !-------------------------------------------------------------------------
      USE ppm_module_data_mesh
      USE ppm_module_topo_typedef
      IMPLICIT NONE
      !-------------------------------------------------------------------------
      !  Arguments
      !-------------------------------------------------------------------------
      CLASS(ppm_t_equi_mesh)                  :: this
      INTEGER                 , INTENT(  OUT) :: info
      !!! Returns status, 0 upon success
      !-------------------------------------------------------------------------
      !  Local variables
      !-------------------------------------------------------------------------
      INTEGER, DIMENSION(3)            :: ldu
      INTEGER                          :: i,j,lb,ub
      INTEGER                          :: iopt,ibuffer,pdim
      INTEGER                          :: nsendlist,nrecvlist
      LOGICAL                          :: valid
      TYPE(ppm_t_topo), POINTER        :: topo => NULL()
      !-------------------------------------------------------------------------
      !  Externals
      !-------------------------------------------------------------------------

      start_subroutine("mesh_map_ghost_put")

      pdim = ppm_dim

      topo => ppm_topo(this%topoid)%t

      !-------------------------------------------------------------------------
      !  Check if ghost mappings have been initalized, if no do so now.
      !-------------------------------------------------------------------------
      IF (.NOT. this%ghost_initialized) THEN
        CALL this%map_ghost_init(info)
            or_fail("map_field_ghost_init failed")
      ENDIF

      !-------------------------------------------------------------------------
      !  Save the map type for the subsequent calls (used to set pop type)
      !-------------------------------------------------------------------------
      ppm_map_type = ppm_param_map_ghost_put

      !-------------------------------------------------------------------------
      !  Reset the buffer size counters
      !-------------------------------------------------------------------------
      ppm_nsendbuffer = 0
      ppm_nrecvbuffer = 0

      !-------------------------------------------------------------------------
      !  Number of mesh blocks to be sent/recvd is reverse from the get
      !-------------------------------------------------------------------------
      nrecvlist = this%ghost_nsend
      nsendlist = this%ghost_nrecv

      !-------------------------------------------------------------------------
      !  Allocate memory for the global mesh sendlists
      !-------------------------------------------------------------------------
      iopt   = ppm_param_alloc_fit
      ldu(1) = nsendlist
      CALL ppm_alloc(ppm_mesh_isendfromsub,ldu,iopt,info)
           or_fail_alloc("ppm_mesh_isendfromsub")
      ldu(1) = pdim
      ldu(2) = nsendlist
      CALL ppm_alloc(ppm_mesh_isendblkstart,ldu,iopt,info)
            or_fail_alloc("ppm_mesh_isendblkstart")
      CALL ppm_alloc(ppm_mesh_isendblksize,ldu,iopt,info)
            or_fail_alloc("ppm_mesh_isendblksize")
      CALL ppm_alloc(ppm_mesh_isendpatchid,ldu,iopt,info)
            or_fail_alloc("ppm_mesh_isendpatchid")

      !-------------------------------------------------------------------------
      !  Allocate memory for the global mesh receive lists
      !-------------------------------------------------------------------------
      iopt   = ppm_param_alloc_fit
      ldu(1) = nrecvlist
      CALL ppm_alloc(ppm_mesh_irecvtosub,ldu,iopt,info)
            or_fail_alloc("ppm_mesh_irecvtosub")
      ldu(1) = pdim
      ldu(2) = nrecvlist
      CALL ppm_alloc(ppm_mesh_irecvblkstart,ldu,iopt,info)
            or_fail_alloc("ppm_mesh_irecvblkstart")
      CALL ppm_alloc(ppm_mesh_irecvblksize,ldu,iopt,info)
            or_fail_alloc("ppm_mesh_irecvblksize")
      CALL ppm_alloc(ppm_mesh_irecvpatchid,ldu,iopt,info)
            or_fail_alloc("ppm_mesh_irecvpatchid")

      !-------------------------------------------------------------------------
      !  Allocate memory for the global send/recv lists
      !-------------------------------------------------------------------------
      ldu(1) = topo%ncommseq
      CALL ppm_alloc(ppm_isendlist,ldu,iopt,info)
            or_fail_alloc("ppm_isendlist")
      CALL ppm_alloc(ppm_irecvlist,ldu,iopt,info)
            or_fail_alloc("ppm_irecvlist")
      ldu(1) = topo%ncommseq + 1
      CALL ppm_alloc(ppm_psendbuffer,ldu,iopt,info)
            or_fail_alloc("ppm_psendbuffer")
      CALL ppm_alloc(ppm_precvbuffer,ldu,iopt,info)
            or_fail_alloc("ppm_precvbuffer")

      !-------------------------------------------------------------------------
      !  Reset the number of buffer entries
      !-------------------------------------------------------------------------
      ppm_buffer_set = 0

      !-------------------------------------------------------------------------
      !  Build the lists for ppm_map_field_push, _pop and _send to CREATE ghost
      !  meshpoints on the topology topoid
      !-------------------------------------------------------------------------
      ppm_psendbuffer(1) = 1
      ppm_precvbuffer(1) = 1
      ppm_nsendlist      = topo%ncommseq
      ppm_nrecvlist      = ppm_nsendlist
      ibuffer            = 0
      DO i=1,topo%ncommseq
         ibuffer = i + 1
         !----------------------------------------------------------------------
         !  Store the processor with which we will send/recv
         !----------------------------------------------------------------------
         ppm_isendlist(i) = topo%icommseq(i)
         ppm_irecvlist(i) = topo%icommseq(i)

         !----------------------------------------------------------------------
         !  Store the mesh block range for this processor interaction
         !----------------------------------------------------------------------
         ppm_psendbuffer(ibuffer)=this%ghost_recvblk(ibuffer)
         ppm_precvbuffer(ibuffer)=this%ghost_blk(ibuffer)

         !----------------------------------------------------------------------
         !  Store the definitions of the mesh blocks to be sent
         !----------------------------------------------------------------------
         lb = ppm_psendbuffer(i)
         ub = ppm_psendbuffer(ibuffer)
         DO j=lb,ub-1
             ppm_mesh_isendblkstart(1:pdim,j) = this%ghost_recvblkstart(1:pdim,j)
             ppm_mesh_isendblksize(1:pdim,j) = this%ghost_recvblksize(1:pdim,j)
             ppm_mesh_isendfromsub(j) = this%ghost_recvtosub(j)
             ppm_mesh_isendpatchid(1:pdim,j) = this%ghost_recvpatchid(1:pdim,j)
         ENDDO

         !----------------------------------------------------------------------
         !  Store the definitions of the mesh blocks to be received
         !----------------------------------------------------------------------
         lb = ppm_precvbuffer(i)
         ub = ppm_precvbuffer(ibuffer)
         DO j=lb,ub-1
             ppm_mesh_irecvblkstart(1:pdim,j) = this%ghost_blkstart(1:pdim,j)
             ppm_mesh_irecvblksize(1:pdim,j) = this%ghost_blksize(1:pdim,j)
             ppm_mesh_irecvtosub(j) = this%ghost_fromsub(j)
             ppm_mesh_irecvpatchid(1:pdim,j) = this%ghost_patchid(1:pdim,j)
         ENDDO
      ENDDO

      !DO i=1,ppm_nsendlist
          !DO j=ppm_psendbuffer(i),ppm_psendbuffer(i+1)-1
              !stdout("patchid in sendlist : ",'ppm_mesh_isendpatchid(1:2,j)',&
                  !" (i=",i,",j=",j,"jsub=",'ppm_mesh_isendfromsub(j)',")")
              !stdout("blkstart in sendlist : ",'ppm_mesh_isendblkstart(1:2,j)',&
                  !" (i=",i,",j=",j,"jsub=",'ppm_mesh_isendfromsub(j)',")")
          !ENDDO
      !ENDDO

      end_subroutine()

      END SUBROUTINE equi_mesh_map_ghost_put
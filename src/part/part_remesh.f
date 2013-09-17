      !------------------------------------------------------------------------!
      !     Subroutine   :                 ppm_remesh
      !------------------------------------------------------------------------!
      ! Copyright (c) 2012 CSE Lab (ETH Zurich), MOSAIC Group (ETH Zurich),
      !                    Center for Fluid Dynamics (DTU)
      !
      !
      ! This file is part of the Parallel Particle Mesh Library (PPM).
      !
      ! PPM is free software: you can redistribute it and/or modify
      ! it under the terms of the GNU Lesser General Public License
      ! as published by the Free Software Foundation, either
      ! version 3 of the License, or (at your option) any later
      ! version.
      !
      ! PPM is distributed in the hope that it will be useful,
      ! but WITHOUT ANY WARRANTY; without even the implied warranty of
      ! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
      ! GNU General Public License for more details.
      !
      ! You should have received a copy of the GNU General Public License
      ! and the GNU Lesser General Public License along with PPM. If not,
      ! see <http://www.gnu.org/licenses/>.
      !
      ! Parallel Particle Mesh Library (PPM)
      ! ETH Zurich
      ! CH-8092 Zurich, Switzerland
      !------------------------------------------------------------------------!

      SUBROUTINE DTYPE(part_remesh)(this,Mesh,kernel,info,p2m_bcdef,cutoff_val,cutoff_field)
      !!! This subroutine remesh the particle set.
      !!! If it has not been done already, it will call this%interp to
      !!!  carry out particle to mesh interpolation.
      !!!
      !!! Currently 2 interpolation schemes are supported:
      !!!
      !!! * ppm_param_rmsh_kernel_bsp2
      !!! * ppm_param_rmsh_kernel_mp4
      !!!
      !!! [WARNING]
      !!! Currently, this routine will destroy all properties that are stored on the
      !!! particles but had not been generated by discretizing a field on this
      !!! particle set.
      !!!
      !!! [TIP]
      !!! There is no need to perform a `ghost_get` before calling this routine
      !!! as the routine calls itself a `ghost_put` to the field after
      !!! interpolating from particles to the field.
      !------------------------------------------------------------------------!
      !  INCLUDES
      !------------------------------------------------------------------------!

      !------------------------------------------------------------------------!
      !  Modules
      !------------------------------------------------------------------------!
      IMPLICIT NONE

      DEFINE_MK()
      !-------------------------------------------------------------------------!
      ! Arguments
      !-------------------------------------------------------------------------!
      CLASS(DTYPE(ppm_t_particles))                   :: this
      CLASS(ppm_t_equi_mesh_)                         :: Mesh
      INTEGER                     ,     INTENT(IN   ) :: kernel
      !!! Choice of the kernel used to compute the weights.
      INTEGER                     ,     INTENT(  OUT) :: info
      !!! Returns status, 0 upon success
      INTEGER, DIMENSION(:  )     , POINTER, OPTIONAL :: p2m_bcdef
     !!! Boundary conditions used for the interpolation routines, they may be
     !!! different than the boundary conditions set in the topology.
     !!! The values in this array can be one of:
     !!!
     !!! - ppm_param_bcdef_symmetry
     !!! - ppm_param_bcdef_antisymmetry
      REAL(MK), DIMENSION(2),  OPTIONAL, INTENT(IN)   :: cutoff_val
      !!! Lower (element 1) and upper (element 2) bound of particle
      !!! strengths. Only particles with strengths in this band
      !!! will be created.
      CLASS(ppm_t_field_),    OPTIONAL, INTENT(IN)    :: cutoff_field
      !!! Field that the above cutoff values apply on (this is usually the field
      !!! that represents the strength of the particles)
     !-------------------------------------------------------------------------!
     ! Local variables
     !-------------------------------------------------------------------------!
      REAL(MK) , DIMENSION(:,:)     , POINTER  :: xp => NULL()
      REAL(MK) , DIMENSION(:)       , POINTER  :: wp_s => NULL()
      REAL(MK) , DIMENSION(:,:)     , POINTER  :: wp_v => NULL()
      INTEGER                                  :: kernel_support
      INTEGER,  DIMENSION(ppm_dim+2)           :: ldu
      INTEGER                                  :: ip,ndim
      INTEGER                                  :: nb_part
      ! aliases
      CLASS(ppm_t_subpatch_),POINTER           :: p    => NULL()
      CLASS(ppm_t_main_abstr),POINTER          :: abstr=> NULL()
      CLASS(ppm_t_field_),   POINTER           :: field=> NULL()
      CLASS(DTYPE(ppm_t_part_prop)_),POINTER   :: prop => NULL()

      start_subroutine("ppm_remesh")

     !-------------------------------------------------------------------------!
     !  This is a hack! Somehow having trouble with constructors in the
     !  ppm_module_data_rmsh module
     !-------------------------------------------------------------------------!
      ppm_rmsh_kernelsize = (/1,2,2,4/)

      ndim = ppm_dim

     !-------------------------------------------------------------------------!
     !  Check arguments
     !-------------------------------------------------------------------------!
      IF (ppm_debug .GT. 0) THEN
        CALL check
        IF (info .NE. 0) GOTO 9999
      ENDIF
      IF (    (PRESENT(cutoff_val) .AND. .NOT.PRESENT(cutoff_field)) &
          .OR.(PRESENT(cutoff_field) .AND. .NOT.PRESENT(cutoff_val)) ) THEN
          fail("Incompatible optional arguments: must provide cutoff_val AND cutoff_field, or neither")
      ENDIF

      !-------------------------------------------------------------------------!
      !  If there is nothing to do, do nothing
      !-------------------------------------------------------------------------!
      IF(this%Npart.EQ.0) GOTO 9999


      !-------------------------------------------------------------------------
      !  First, loop through all the fields that are discretized on the
      !  particle set and interpolate them on the mesh
      !-------------------------------------------------------------------------
      IF (.NOT. ASSOCIATED(this%field_ptr)) THEN
         stdout("No fields are currently discretized on this particle set,remeshing the postions only")
      ELSE
        abstr => this%field_ptr%begin()
        DO WHILE (ASSOCIATED(abstr))
            SELECT TYPE(field => abstr)
            CLASS IS (ppm_t_field_)
               CALL this%interp_to_mesh(Mesh,field,ppm_param_rmsh_kernel_mp4,info)
               or_fail("interp_to_mesh")
            END SELECT
            abstr => this%field_ptr%next()
        ENDDO
      ENDIF

      !-------------------------------------------------------------------------
      !  Now remesh the positions
      !-------------------------------------------------------------------------
      CALL this%get_xp(xp,info)
      or_fail("Get_xp failed")


      !-------------------------------------------------------------------------
      !  count number of particles that we will have on this proc after remesh
      !-------------------------------------------------------------------------
      nb_part = 0
      IF (.NOT. PRESENT(cutoff_val)) THEN
          !all mesh nodes will become particles
          p => Mesh%subpatch%begin()
          DO WHILE (ASSOCIATED(p))
              nb_part = nb_part + PRODUCT(p%nnodes(1:ppm_dim))
              p => Mesh%subpatch%next()
          ENDDO
      ELSE
        !only mesh nodes with cutoff_field in some range will become particles
        ! (macros are a bit ugly there....)
        IF (ndim.EQ.2 .AND. cutoff_field%lda.EQ.1) THEN
        foreach n in equi_mesh(Mesh) with sca_fields(cutoff_field) indices(i,j)
            for real
                 if (cutoff_field_n .ge. cutoff_val(1) .and. &
                     cutoff_field_n .le. cutoff_val(2) )  nb_part = nb_part + 1
        end foreach
        ELSE IF (ndim.EQ.2 .AND. cutoff_field%lda.GT.1) THEN
        foreach n in equi_mesh(Mesh) with vec_fields(cutoff_field) indices(i,j)
            for real
                 if (norm(cutoff_field_n(1:cutoff_field%lda,i,j)) .ge. cutoff_val(1) .and. &
                     norm(cutoff_field_n(1:cutoff_field%lda,i,j)) .le. cutoff_val(2) )  nb_part = nb_part + 1
        end foreach
        ELSE IF (ndim.EQ.3 .AND. cutoff_field%lda.EQ.1) THEN
        foreach n in equi_mesh(Mesh) with sca_fields(cutoff_field) indices(i,j,k)
            for real
                 if (cutoff_field_n .ge. cutoff_val(1) .and. &
                     cutoff_field_n .le. cutoff_val(2) )  nb_part = nb_part + 1
        end foreach
        ELSE IF (ndim.EQ.3 .AND. cutoff_field%lda.GT.1) THEN
        foreach n in equi_mesh(Mesh) with vec_fields(cutoff_field) indices(i,j,k)
            for real
                 if (norm(cutoff_field_n(1:cutoff_field%lda,i,j,k)) .ge. cutoff_val(1) .and. &
                     norm(cutoff_field_n(1:cutoff_field%lda,i,j,k)) .le. cutoff_val(2) )  nb_part = nb_part + 1
        end foreach
        ENDIF
      ENDIF

      !Re-allocate xp
      ldc(1) = ppm_dim
      ldc(2) = nb_part
      CALL ppm_alloc(this%xp,ldc,ppm_param_alloc_grow,info)
      or_fail_alloc("xp")

      this%Npart = nb_part


      !Reallocate property arrays if needed
      prop => this%props%begin()
      DO WHILE (ASSOCIATED(prop))
          CALL this%realloc_prop(prop,info)
          or_fail("reallocating property array failed")
          prop => this%props%next()
      ENDDO

      !-------------------------------------------------------------------------
      !  Copy the new particle positions
      !-------------------------------------------------------------------------
      ip = 0
      IF (.NOT. PRESENT(cutoff_val)) THEN
          !all mesh nodes will become particles
        IF (ndim.EQ.2) THEN
            foreach n in equi_mesh(Mesh) with indices(i,j)
                for real
                     ip = ip + 1
                     xp(1:ndim,ip) = sbpitr%get_pos(i,j)
            end foreach
        ELSE IF (ndim.EQ.3) THEN
            foreach n in equi_mesh(Mesh) with indices(i,j,k)
                for real
                     ip = ip + 1
                     xp(1:ndim,ip) = sbpitr%get_pos(i,j,k)
            end foreach
        ENDIF
      ELSE
        !only mesh nodes with cutoff_field in some range will become particles
        ! (macros are a bit ugly there....)
        IF (ndim.EQ.2 .AND. cutoff_field%lda.EQ.1) THEN
            foreach n in equi_mesh(Mesh) with sca_fields(cutoff_field) indices(i,j)
                for real
                     if (cutoff_field_n .ge. cutoff_val(1) .and. &
                         cutoff_field_n .le. cutoff_val(2) )  then
                         ip = ip + 1
                         xp(1:ndim,ip) = sbpitr%get_pos(i,j)
                     endif
            end foreach
        ELSE IF (ndim.EQ.2 .AND. cutoff_field%lda.GT.1) THEN
            foreach n in equi_mesh(Mesh) with vec_fields(cutoff_field) indices(i,j)
                for real
                     if (norm(cutoff_field_n(1:cutoff_field%lda,i,j)) .ge. cutoff_val(1) .and. &
                         norm(cutoff_field_n(1:cutoff_field%lda,i,j)) .le. cutoff_val(2) )  then
                         ip = ip + 1
                         xp(1:ndim,ip) = sbpitr%get_pos(i,j)
                     endif
            end foreach
        ELSE IF (ndim.EQ.3 .AND. cutoff_field%lda.EQ.1) THEN
            foreach n in equi_mesh(Mesh) with sca_fields(cutoff_field) indices(i,j,k)
                for real
                     if (cutoff_field_n .ge. cutoff_val(1) .and. &
                         cutoff_field_n .le. cutoff_val(2) )  then
                         ip = ip + 1
                         xp(1:ndim,ip) = sbpitr%get_pos(i,j,k)
                     endif
            end foreach
        ELSE IF (ndim.EQ.3 .AND. cutoff_field%lda.GT.1) THEN
            foreach n in equi_mesh(Mesh) with vec_fields(cutoff_field) indices(i,j,k)
                for real
                     if (norm(cutoff_field_n(1:cutoff_field%lda,i,j,k)) .ge. cutoff_val(1) .and. &
                         norm(cutoff_field_n(1:cutoff_field%lda,i,j,k)) .le. cutoff_val(2) )  then
                         ip = ip + 1
                         xp(1:ndim,ip) = sbpitr%get_pos(i,j,k)
                     endif
            end foreach
        ENDIF
      ENDIF

      !-------------------------------------------------------------------------
      !  Then copy the mesh values onto the particle properties
      !-------------------------------------------------------------------------
      IF (ASSOCIATED(this%field_ptr)) THEN
        abstr => this%field_ptr%begin()
        DO WHILE (ASSOCIATED(abstr))
          SELECT TYPE(field=>abstr)
          CLASS IS (ppm_t_field_)
          IF (field%lda.EQ.1) THEN
          CALL this%get_field(field,wp_s,info)
          or_fail("interp_to_mesh")
          ELSE
          CALL this%get_field(field,wp_v,info)
          or_fail("interp_to_mesh")
          ENDIF

          ip = 0
          IF (field%lda.EQ.1) THEN
              !Scalar field
              IF (.NOT. PRESENT(cutoff_val)) THEN
                  IF (ndim.EQ.2) THEN
                      foreach n in equi_mesh(Mesh) with sca_fields(V=field) indices(i,j)
                          for real
                              ip = ip + 1
                              wp_s(ip) = V_n
                      end foreach
                  ELSE IF (ndim.EQ.3) THEN
                      foreach n in equi_mesh(Mesh) with sca_fields(V=field) indices(i,j,k)
                          for real
                              ip = ip + 1
                              wp_s(ip) = V_n
                      end foreach
                  ENDIF
              ELSE
                  IF (ndim.EQ.2 .and. cutoff_field%lda.eq.1) THEN
                      foreach n in equi_mesh(Mesh) with sca_fields(V=field,cutoff_field) indices(i,j)
                          for real
                                if (cutoff_field_n .ge. cutoff_val(1) .and. &
                                    cutoff_field_n .le. cutoff_val(2) )  then
                                    ip = ip + 1
                                    wp_s(ip) = V_n
                                endif
                          end foreach
                  ELSE IF (ndim.EQ.3 .and. cutoff_field%lda.eq.1) THEN
                      foreach n in equi_mesh(Mesh) with sca_fields(V=field,cutoff_field) indices(i,j,k)
                          for real
                                if (cutoff_field_n .ge. cutoff_val(1) .and. &
                                    cutoff_field_n .le. cutoff_val(2) )  then
                                    ip = ip + 1
                                    wp_s(ip) = V_n
                                endif
                          end foreach
                  ELSE IF (ndim.EQ.2 .and. cutoff_field%lda.gt.1) THEN
                      foreach n in equi_mesh(Mesh) with sca_fields(V=field) vec_fields(cutoff_field) indices(i,j)
                          for real
                                if (norm(cutoff_field_n(1:cutoff_field%lda,i,j)) .ge. cutoff_val(1) .and. &
                                    norm(cutoff_field_n(1:cutoff_field%lda,i,j)) .le. cutoff_val(2) )  then
                                    ip = ip + 1
                                    wp_s(ip) = V_n
                                endif
                          end foreach
                  ELSE IF (ndim.EQ.3 .and. cutoff_field%lda.gt.1) THEN
                      foreach n in equi_mesh(Mesh) with sca_fields(V=field) vec_fields(cutoff_field) indices(i,j,k)
                          for real
                                if (norm(cutoff_field_n(1:cutoff_field%lda,i,j,k)) .ge. cutoff_val(1) .and. &
                                    norm(cutoff_field_n(1:cutoff_field%lda,i,j,k)) .le. cutoff_val(2) )  then
                                    ip = ip + 1
                                    wp_s(ip) = V_n
                                endif
                          end foreach
                  ENDIF
              ENDIF
          ELSE !Vector field
              IF (.NOT. PRESENT(cutoff_val)) THEN
                  IF (ndim.EQ.2) THEN
                      foreach n in equi_mesh(Mesh) with vec_fields(V=field) indices(i,j)
                          for real
                              ip = ip + 1
                              wp_v(1:field%lda,ip) = V_n(1:field%lda)
                      end foreach
                  ELSE IF (ndim.EQ.3) THEN
                      foreach n in equi_mesh(Mesh) with vec_fields(V=field) indices(i,j,k)
                          for real
                              ip = ip + 1
                              wp_v(1:field%lda,ip) = V_n(1:field%lda)
                      end foreach
                  ENDIF
              ELSE
                  IF (ndim.EQ.2 .and. cutoff_field%lda.eq.1) THEN
                      foreach n in equi_mesh(Mesh) with sca_fields(cutoff_field) vec_fields(V=field) indices(i,j)
                          for real
                                if (cutoff_field_n .ge. cutoff_val(1) .and. &
                                    cutoff_field_n .le. cutoff_val(2) )  then
                                    ip = ip + 1
                                    wp_v(1:field%lda,ip) = V_n(1:field%lda)
                                endif
                          end foreach
                  ELSE IF (ndim.EQ.3 .and. cutoff_field%lda.eq.1) THEN
                      foreach n in equi_mesh(Mesh) with sca_fields(cutoff_field) vec_fields(V=field) indices(i,j,k)
                          for real
                                if (cutoff_field_n .ge. cutoff_val(1) .and. &
                                    cutoff_field_n .le. cutoff_val(2) )  then
                                    ip = ip + 1
                                    wp_v(1:field%lda,ip) = V_n(1:field%lda)
                                endif
                          end foreach
                  ELSE IF (ndim.EQ.2 .and. cutoff_field%lda.gt.1) THEN
                      foreach n in equi_mesh(Mesh) with vec_fields(V=field, cutoff_field) indices(i,j)
                          for real
                                if (norm(cutoff_field_n(1:cutoff_field%lda,i,j)) .ge. cutoff_val(1) .and. &
                                    norm(cutoff_field_n(1:cutoff_field%lda,i,j)) .le. cutoff_val(2) )  then
                                    ip = ip + 1
                                    wp_v(1:field%lda,ip) = V_n(1:field%lda)
                                endif
                          end foreach
                  ELSE IF (ndim.EQ.3 .and. cutoff_field%lda.gt.1) THEN
                      foreach n in equi_mesh(Mesh) with vec_fields(V=field, cutoff_field) indices(i,j,k)
                          for real
                                if (norm(cutoff_field_n(1:cutoff_field%lda,i,j,k)) .ge. cutoff_val(1) .and. &
                                    norm(cutoff_field_n(1:cutoff_field%lda,i,j,k)) .le. cutoff_val(2) )  then
                                    ip = ip + 1
                                    wp_v(1:field%lda,ip) = V_n(1:field%lda)
                                endif
                          end foreach
                  ENDIF
              ENDIF
            ENDIF !vector field
            END SELECT
            abstr => this%field_ptr%next()
        ENDDO
      ENDIF

      !Updating internal state variables
      CALL this%set_xp(xp,info,read_only=.true.)
      or_fail("Set_xp failed")

      end_subroutine()
      RETURN
      CONTAINS
      SUBROUTINE check
        IF (.NOT. ppm_initialized) THEN
            fail("Please call ppm_init first!",&
            ppm_err_ppm_noinit,exit_point=8888)
        ENDIF
        IF ((kernel.LT.1).OR.(kernel.GT.4)) THEN
            fail("Wrong kernel definition",&
                ppm_err_ppm_noinit,exit_point=8888)
        END IF
        kernel_support = ppm_rmsh_kernelsize(kernel)*2
        IF(.NOT.((kernel_support.EQ.2).OR.(kernel_support.EQ.4) &
     &               .OR.(kernel_support.EQ.6))) THEN
            fail("Wrong kernel support",ppm_err_argument,exit_point=8888)
        END IF
        IF (this%Npart .GT. 0) THEN
           IF (SIZE(this%xp,2) .LT. this%Npart) THEN
            fail("this%Npart is wrong. Corrupted data structure?",exit_point=8888)
           ENDIF
        ENDIF
 8888   CONTINUE
      END SUBROUTINE check

      PURE FUNCTION norm(vec)
      DEFINE_MK()
      REAL(MK) , DIMENSION(:),INTENT(IN) :: vec
      REAL(MK)                           :: norm
          norm = SQRT(SUM(ABS(vec)**2))
      END FUNCTION

      END SUBROUTINE DTYPE(part_remesh)


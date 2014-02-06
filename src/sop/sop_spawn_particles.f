      SUBROUTINE DTYPE(sop_spawn_particles)(Particles,opts,info,nb_part_added,&
      &          nneigh_threshold,level_fun,wp_fun,nb_fun)
          !!!----------------------------------------------------------------------------!
          !!!
          !!! Insert particles around those with too few neighbours
          !!!
          !!! Uses ppm_alloc to grow/shrink arrays
          !!!
          !!! Warning: on output, some particles may be outside the computational domain
          !!! Call impose_boundary_conditions to fix this.
          !!!----------------------------------------------------------------------------!

          USE ppm_module_alloc, ONLY: ppm_alloc

          IMPLICIT NONE
#ifdef __MPI
          INCLUDE 'mpif.h'
#endif

          DEFINE_MK()
          ! arguments
          TYPE(DTYPE(ppm_t_particles)), POINTER,INTENT(INOUT)   :: Particles
          TYPE(DTYPE(sop_t_opts)), POINTER,     INTENT(IN   )   :: opts
          INTEGER,                              INTENT(  OUT)   :: info

          INTEGER, OPTIONAL,                    INTENT(  OUT)   :: nb_part_added
          INTEGER, OPTIONAL,                    INTENT(IN   )   :: nneigh_threshold
          OPTIONAL                                              :: wp_fun
          OPTIONAL                                              :: nb_fun
          OPTIONAL                                              :: level_fun
          !!! if level function is known analytically
          INTERFACE
              FUNCTION wp_fun(pos)
                  USE ppm_module_data, ONLY: ppm_dim
                  USE ppm_module_typedef
                  DEFINE_MK()
                  REAL(MK),DIMENSION(ppm_dim),INTENT(IN)           :: pos
                  REAL(MK)                                      :: wp_fun
              END FUNCTION wp_fun

              !Level function (usually known only during initialisation)
              FUNCTION level_fun(pos)
                  USE ppm_module_data, ONLY: ppm_dim
                  USE ppm_module_typedef
                  DEFINE_MK()
                  REAL(MK),DIMENSION(ppm_dim),INTENT(IN)        :: pos
                  REAL(MK)                                      :: level_fun
              END FUNCTION level_fun

              !Function that returns the width of the narrow band
              FUNCTION nb_fun(kappa,scale_D)
                  USE ppm_module_typedef
                  DEFINE_MK()
                  REAL(MK)                             :: nb_fun
                  REAL(MK),                INTENT(IN)  :: kappa
                  REAL(MK),                INTENT(IN)  :: scale_D
              END FUNCTION nb_fun

          END INTERFACE

          ! local variables
          REAL(MK),     DIMENSION(:,:),POINTER   :: xp
          REAL(MK),     DIMENSION(:),  POINTER   :: rcp
          REAL(MK),     DIMENSION(:),  POINTER   :: D
          REAL(MK),     DIMENSION(:),  POINTER   :: Dtilde
          REAL(MK),     DIMENSION(:),  POINTER   :: wp
          REAL(MK),     DIMENSION(:),  POINTER   :: level
          INTEGER                                :: Npart
          INTEGER,      DIMENSION(:),  POINTER   :: nvlist
          INTEGER                                :: ip,iq,ineigh,i,di
          CHARACTER(LEN=256)                     :: cbuf
          CHARACTER(LEN=256)                     :: caller='sop_spawn_particles'
          REAL(KIND(1.D0))                       :: t0
          REAL(MK)                               :: lev
          REAL(MK)                               :: theta1,theta2
          INTEGER                                :: nvlist_theoretical
          INTEGER                                :: add_part
          INTEGER                                :: add_part_alloc
          INTEGER,        DIMENSION(2)           :: lda
          INTEGER,        DIMENSION(1)           :: lda1
          INTEGER, PARAMETER                     :: nb_new_part = 1
          REAL(MK)                               :: angle
          REAL(MK),PARAMETER                     :: PI = ACOS(-1._MK)
          !!! number of new particles that are generated locally
          INTEGER,DIMENSION(:),POINTER           :: fuse_part
          INTEGER,DIMENSION(:),POINTER           :: nb_neigh
          REAL(MK), DIMENSION(ppm_dim,Particles%Npart+1:Particles%Mpart) :: xp_g
          REAL(MK)                               :: dist
          REAL(MK),DIMENSION(3,12)               :: default_stencil

          !!-------------------------------------------------------------------------!
          !! Initialize
          !!-------------------------------------------------------------------------!
          info = 0
#if debug_verbosity > 0
          CALL substart(caller,t0,info)
#endif

          IF (opts%level_set) THEN
              IF (PRESENT(level_fun) .NEQV. PRESENT(wp_fun)) THEN
                  info = ppm_error_error
                  CALL ppm_error(ppm_err_argument,caller,   &
                      &    'incompatible optional arguments',__LINE__,info)
                  GOTO 9999
              ENDIF
          ENDIF

          IF (PRESENT(nneigh_threshold)) THEN
              nvlist_theoretical = nneigh_threshold
          ELSE
              nvlist_theoretical = opts%nneigh_theo
          ENDIF

          add_part = 0

          Npart = Particles%Npart
          nvlist => Particles%nvlist(1:Npart)

          !!-------------------------------------------------------------------------!
          !! Count number of new particles to insert
          !!-------------------------------------------------------------------------!
          ! counting how many particles have to be added
          ! if not enough neighbours, add nb_new_part particle
          IF (opts%level_set) THEN
              IF (PRESENT(wp_fun)) THEN
                  xp => Get_xp(Particles)
                  DO ip=1,Npart
                      IF (nvlist(ip) .LT. nvlist_theoretical) THEN
                          lev = level_fun(xp(1:ppm_dim,ip))
                          IF (ABS(lev) .LT. opts%nb_width*&
                              nb_fun(wp_fun(xp(1:ppm_dim,ip)),opts%scale_D)) THEN
                              add_part = add_part + nb_new_part
                          ENDIF
                      ENDIF
                  ENDDO
                  xp => Set_xp(Particles,read_only=.TRUE.)
              ELSE
                  level => Get_wps(Particles,Particles%level_id)
                  wp    => Get_wps(Particles,Particles%adapt_wpid)
                  DO ip=1,Npart
                      IF (nvlist(ip) .LT. nvlist_theoretical) THEN
                          IF (ABS(level(ip)).LT.opts%nb_width*nb_fun(wp(ip),&
                              opts%scale_D))&
                              add_part = add_part + nb_new_part
                      ENDIF
                  ENDDO
                  level => Set_wps(Particles,Particles%level_id,read_only=.TRUE.)
                  wp    => Set_wps(Particles,Particles%adapt_wpid,read_only=.TRUE.)
              ENDIF
          ELSE
              !DO ip=1,Npart
                  !IF (nvlist(ip) .LT. nvlist_theoretical) &
                  !IF (nvlist(ip) .LT. 2) &
                      !add_part = add_part + nb_new_part
              !ENDDO
              !CALL check_quadrants(Particles,info)
              CALL DTYPE(check_nn)(Particles,opts,info)
              !add_part = COUNT(Particles%nvlist .GT. 0) * nb_new_part
              add_part = SUM(ABS(Particles%nvlist(1:Particles%Npart)))
          ENDIF

          nvlist => NULL()

          !!-------------------------------------------------------------------------!
          !! Re-allocate (grow) arrays if necessary
          !!-------------------------------------------------------------------------!
          IF (add_part .GT. 0) THEN
              add_part_alloc  = add_part
              !Keep a copy of the ghosts
              xp_g(1:ppm_dim,Npart+1:Particles%Mpart) = Particles%xp(1:ppm_dim,Npart+1:Particles%Mpart)

              lda = (/ppm_dim,Npart+add_part/)
              CALL ppm_alloc(Particles%xp,lda,ppm_param_alloc_grow_preserve,info)
              IF (info .NE. 0) THEN
                  info = ppm_error_error
                  CALL ppm_error(ppm_err_alloc,caller,   &
                      &    'allocation of xp failed',__LINE__,info)
                  GOTO 9999
              ENDIF
              lda1 = Npart+add_part
              CALL ppm_alloc(Particles%wps(Particles%D_id)%vec,lda1,&
                  ppm_param_alloc_grow_preserve,info)
              IF (info .NE. 0) THEN
                  info = ppm_error_error
                  CALL ppm_error(ppm_err_alloc,caller,   &
                      &    'allocation of D failed',__LINE__,info)
                  GOTO 9999
              ENDIF
              CALL ppm_alloc(Particles%wps(Particles%Dtilde_id)%vec,lda1,&
                  ppm_param_alloc_grow_preserve,info)
              IF (info .NE. 0) THEN
                  info = ppm_error_error
                  CALL ppm_error(ppm_err_alloc,caller,   &
                      &    'allocation of Dtilde failed',__LINE__,info)
                  GOTO 9999
              ENDIF
              CALL ppm_alloc(Particles%wps(Particles%rcp_id)%vec,lda1,&
                  ppm_param_alloc_grow_preserve,info)
              IF (info .NE. 0) THEN
                  info = ppm_error_error
                  CALL ppm_error(ppm_err_alloc,caller,   &
                      &    'allocation of rcp failed',__LINE__,info)
                  GOTO 9999
              ENDIF
              CALL ppm_alloc(Particles%wpi(fuse_id)%vec,lda1,&
                  ppm_param_alloc_grow_preserve,info)
              IF (info .NE. 0) THEN
                  info = ppm_error_error
                  CALL ppm_error(ppm_err_alloc,caller,   &
                      &    'allocation of fuse_part failed',__LINE__,info)
                  GOTO 9999
              ENDIF
              CALL ppm_alloc(Particles%wpi(nb_neigh_id)%vec,lda1,&
                  ppm_param_alloc_grow_preserve,info)
              IF (info .NE. 0) THEN
                  info = ppm_error_error
                  CALL ppm_error(ppm_err_alloc,caller,   &
                      &    'allocation of nb_neigh failed',__LINE__,info)
                  GOTO 9999
              ENDIF

              !!-------------------------------------------------------------------------!
              !! Add particles
              !! (either randomly, or using fake random numbers based on particles'
              !! positions. This is a quick hack to ensure exact consistency between
              !! simulations run an different number of processors)
              !!-------------------------------------------------------------------------!

              xp => Particles%xp(1:ppm_dim,1:Npart+add_part)
              !Cannot use get_xp, because we need access to elements
              ! of the array xp that are beyond Particles%Npart
              D => Particles%wps(Particles%D_id)%vec(1:Npart+add_part)      !same reason
              Dtilde => Particles%wps(Particles%Dtilde_id)%vec(1:Npart+add_part)      !same reason
              rcp => Particles%wps(Particles%rcp_id)%vec(1:Npart+add_part)  !same reason
              nvlist => Particles%nvlist(1:Npart)
              fuse_part => Particles%wpi(fuse_id)%vec(1:Npart+add_part)      !same reason
              nb_neigh => Particles%wpi(nb_neigh_id)%vec(1:Npart+add_part)      !same reason
              IF (opts%level_set) THEN
                  IF (.NOT. PRESENT(level_fun)) THEN
                      level => Get_wps(Particles,Particles%level_id)
                      wp    => Get_wps(Particles,Particles%adapt_wpid)
                  ENDIF
              ENDIF

              !define some default stencils (inspired on sphere packings)
              ! for use when we want to insert a lot of particles
              ! near a given particle which do not yet have any neighbours

              !the 2d stencil (unit cell)
              DO i=1,6
                  angle = PI/3._MK*REAL(i,MK)
                  default_stencil(1:3,i) =  &
                      (/COS(angle),SIN(angle),0._mk/)
              ENDDO
              !the 3d stencil (2d stencil completed by 2 additional layers)
              DO i=1,3
                  angle = PI/6._MK + 2._MK*PI/3._MK* REAL(i,MK)
                  default_stencil(1:3,6+i)=sqrt(3._mk)/2._mk*&
                      (/COS(angle),SIN(angle),1._mk/sqrt(3._mk)/)
              ENDDO
              DO i=1,3
                  angle = PI/6._MK + 2._MK*PI/3._MK* REAL(i,MK)
                  default_stencil(1:3,9+i)=sqrt(3._mk)/2._mk*&
                      (/COS(angle),SIN(angle),-1._mk/sqrt(3._mk)/)
              ENDDO


              add_part = 0
              angle = PI/3._MK

              add_particles: DO ip=1,Npart

                  IF (nvlist(ip).NE.0) THEN
                      !FOR LEVEL SETS ONLY
                      IF (opts%level_set) THEN
                          IF (PRESENT(wp_fun)) THEN
                              lev = level_fun(xp(1:ppm_dim,ip))
                              IF (ABS(lev) .GE. opts%nb_width*&
                                  nb_fun(wp_fun(xp(1:ppm_dim,ip)),opts%scale_D)) &
                                  CYCLE add_particles
                          ELSE
                              IF (ABS(level(ip)).GE.opts%nb_width*nb_fun(wp(ip),opts%scale_D)) &
                                  CYCLE add_particles
                          ENDIF
                      ENDIF

                      new_part_list: DO i=1,abs(nvlist(ip))
                          add_part = add_part + 1

                          if(nvlist(ip) .gt.0) then
                              iq = Particles%vlist(i,ip)
                              !if (iq.gt.ip) then
                                  !add_part = add_part -1
                                  !cycle new_part_list
                              !endif
                              if (iq .le. Npart) then
                                  dist = sqrt(sum((xp(1:ppm_dim,ip)-xp(1:ppm_dim,iq))**2))
                                  xp(1:ppm_dim,Npart + add_part) = xp(1:ppm_dim,ip) + &
                                      0.1_MK*D(ip) * &
                                      ((xp(1:ppm_dim,ip) - xp(1:ppm_dim,iq))/dist + & !mirror image of q
                                      default_stencil(1:ppm_dim,1))

                              else
                                  dist = sqrt(sum((xp(1:ppm_dim,ip)-xp_g(1:ppm_dim,iq))**2))
                                  xp(1:ppm_dim,Npart + add_part) = xp(1:ppm_dim,ip) + &
                                      0.1_MK*D(ip) * &
                                      ((xp(1:ppm_dim,ip) - xp_g(1:ppm_dim,iq))/dist + & !mirror image of q
                                      default_stencil(1:ppm_dim,1))
                              endif
                          else
                              xp(1:ppm_dim,Npart + add_part) = xp(1:ppm_dim,ip) + &
                                  D(ip) * 0.8_mk * default_stencil(1:ppm_dim,i)
                          endif


                          D(Npart + add_part)   = D(ip)
                          Dtilde(Npart + add_part)   = Dtilde(ip)
                          rcp(Npart + add_part) = rcp(ip)
                          fuse_part(Npart + add_part)   = fuse_part(ip)
                          nb_neigh(Npart + add_part)   = -abs(nb_neigh(ip))
                      ENDDO new_part_list
                  ENDIF
              ENDDO add_particles

              IF (opts%level_set) THEN
                  IF (.NOT. PRESENT(level_fun)) THEN
                      level => Set_wps(Particles,Particles%level_id)
                      wp    => Set_wps(Particles,Particles%adapt_wpid)
                  ENDIF
              ENDIF
              !!-------------------------------------------------------------------------!
              !!new size Npart
              !!-------------------------------------------------------------------------!

              xp => Set_xp(Particles)
              D => Set_wps(Particles,Particles%D_id)
              Dtilde => Set_wps(Particles,Particles%Dtilde_id)
              rcp => Set_wps(Particles,Particles%rcp_id)
              fuse_part => Set_wpi(Particles,fuse_id)
              nb_neigh => Set_wpi(Particles,nb_neigh_id)
              nvlist => NULL()
              Particles%Npart = Npart + add_part

              CALL particles_updated_nb_part(Particles,info,&
                  preserve_wpi=(/nb_neigh_id,fuse_id/),&
                  preserve_wps=(/Particles%D_id,Particles%Dtilde_id,Particles%rcp_id/),&
                  preserve_wpv= (/ (i, i=1,0) /)) !F90-friendly way to init an empty array
              !preserve_wpv=(/ INTEGER :: /)) !valid only in F2003
              IF (info .NE.0) THEN
                  info = ppm_error_error
                  CALL ppm_error(ppm_err_sub_failed,caller,   &
                      &    'particles_updated_nb_part failed',__LINE__,info)
                  GOTO 9999
              ENDIF

              IF (add_part .ne. add_part_alloc) THEN
                  WRITE(cbuf,'(A,I0,A,I0)') 'add_part = ',add_part,' add_part_alloc = ',add_part_alloc
                  CALL ppm_write(ppm_rank,caller,cbuf,info)
                  stop
              ENDIF


          ENDIF !add_part .NE.0


          !!-------------------------------------------------------------------------!
          !! Finalize
          !!-------------------------------------------------------------------------!
#if debug_verbosity > 1
#ifdef __MPI
          CALL MPI_Allreduce(add_part,add_part,1,MPI_INTEGER,MPI_SUM,ppm_comm,info)
#endif
          IF (ppm_rank .EQ.0) THEN
              WRITE(cbuf,'(A,I8,A)') 'Adding ', add_part,' particles'
              CALL ppm_write(ppm_rank,caller,cbuf,info)
          ENDIF
#endif
          IF (PRESENT(nb_part_added)) THEN
              nb_part_added = add_part
          ENDIF

#if debug_verbosity > 0
          CALL substop(caller,t0,info)
#endif
          9999 CONTINUE ! jump here upon error

      END SUBROUTINE DTYPE(sop_spawn_particles)

      SUBROUTINE DTYPE(check_quadrants)(Particles,info)
          IMPLICIT NONE

          DEFINE_MK()
          ! arguments
          TYPE(DTYPE(ppm_t_particles)), POINTER,INTENT(INOUT)   :: Particles
          INTEGER,                              INTENT(  OUT)   :: info
          !local variables

          REAL(MK),DIMENSION(:,:), POINTER :: xp
          INTEGER,DIMENSION(:),    POINTER :: nvlist
          INTEGER,DIMENSION(:,:),  POINTER :: vlist
          INTEGER                          :: ip,iq,ineigh
          LOGICAL,DIMENSION(4)             :: needs_neigh_l
          REAL(MK),DIMENSION(:), POINTER   :: D
          !REAL(MK),DIMENSION(:), POINTER  :: Dtilde

          info = 0
          nvlist => Particles%nvlist
          vlist => Particles%vlist

          xp => Get_xp(Particles,with_ghosts=.TRUE.)

          D => Get_wps(Particles,Particles%D_id,with_ghosts=.TRUE.)
          !Dtilde => Get_wps(Particles,Particles%Dtilde_id,with_ghosts=.TRUE.)


          DO ip=1,Particles%Npart
              ineigh = 1
              !IF (D(ip)/Dtilde(ip) .LT. 1.5_mk) THEN
                  !needs_neigh_l = .FALSE.
                  !CYCLE
              !ENDIF
              needs_neigh_l = .TRUE.
              IF (nvlist(ip).GT.0) THEN
                  DO WHILE(ANY(needs_neigh_l) .AND. ineigh.LE.nvlist(ip))
                      iq = vlist(ineigh,ip)
                      IF (xp(1,iq) .GT. xp(1,ip)) THEN
                          IF (xp(2,iq) .GT. xp(2,ip)) THEN
                              needs_neigh_l(1) = .FALSE.
                          ELSE
                              needs_neigh_l(4) = .FALSE.
                          ENDIF
                      ELSE
                          IF (xp(2,iq) .GT. xp(2,ip)) THEN
                              needs_neigh_l(2) = .FALSE.
                          ELSE
                              needs_neigh_l(3) = .FALSE.
                          ENDIF
                      ENDIF
                      ineigh = ineigh + 1
                  ENDDO
              ENDIF

              !IF (ANY(needs_neigh_l)) THEN
              IF (COUNT(needs_neigh_l).ge.2) THEN
                  loop_quadrants: DO iq=1,4
                      IF(needs_neigh_l(iq)) THEN
                          nvlist(ip) = iq
                          EXIT loop_quadrants
                      ENDIF
                  ENDDO loop_quadrants
              ELSE
                  nvlist(ip) = 0
              ENDIF

          ENDDO
          xp => Set_xp(Particles,read_only=.TRUE.)
          vlist => NULL()
          nvlist => NULL()

          D => Set_wps(Particles,Particles%D_id,read_only=.TRUE.)
          !Dtilde => Set_wps(Particles,Particles%Dtilde_id,read_only=.TRUE.)

      END SUBROUTINE DTYPE(check_quadrants)


      SUBROUTINE DTYPE(check_duplicates)(Particles)
          IMPLICIT NONE

          DEFINE_MK()
          ! arguments
          TYPE(DTYPE(ppm_t_particles)), POINTER,INTENT(INOUT)   :: Particles
          !local variables

          REAL(MK),DIMENSION(:,:), POINTER :: xp
          INTEGER,DIMENSION(:,:),  POINTER :: vlist
          INTEGER                          :: ip,iq,ineigh
          INTEGER                          :: info
          CHARACTER(LEN=ppm_char)          :: cbuf
          CHARACTER(LEN=ppm_char)          :: caller = 'ppm_check_duplicates'


          info = 0

          CALL particles_apply_bc(Particles,Particles%active_topoid,info)
          CALL particles_mapping_partial(Particles,Particles%active_topoid,info)
          CALL particles_mapping_ghosts(Particles,Particles%active_topoid,info)
          CALL particles_neighlists(Particles,Particles%active_topoid,info)

          vlist => Particles%vlist
          xp => Get_xp(Particles,with_ghosts=.TRUE.)

          DO ip=1,Particles%Npart
              DO ineigh = 1,Particles%nvlist(ip)
                  iq = vlist(ineigh,ip)
                  IF (SUM((xp(1:ppm_dim,iq) - xp(1:ppm_dim,ip))**2).LT.1E-20) THEN
                      write(cbuf,*) 'duplicate particles'
                      CALL ppm_write(ppm_rank,caller,cbuf,info)
                      write(cbuf,'(2(A,I0))') 'ip = ',ip,' iq = ',iq
                      CALL ppm_write(ppm_rank,caller,cbuf,info)
                      write(cbuf,'(A,E12.5)') 'Distance between particles is ',&
                          SQRT((SUM((xp(1:ppm_dim,iq) - xp(1:ppm_dim,ip))**2)))
                      CALL ppm_write(ppm_rank,caller,cbuf,info)
                  stop
                  ENDIF
              ENDDO
          ENDDO
          xp => Set_xp(Particles,read_only=.TRUE.)
          vlist => NULL()

      END SUBROUTINE DTYPE(check_duplicates)


      SUBROUTINE DTYPE(check_nn)(Particles,opts,info)

          IMPLICIT NONE

          DEFINE_MK()
          ! arguments
          TYPE(DTYPE(ppm_t_particles)), POINTER,INTENT(INOUT)   :: Particles
          TYPE(DTYPE(sop_t_opts)), POINTER,     INTENT(IN   )   :: opts
          INTEGER,                              INTENT(  OUT)   :: info
          !local variables

          REAL(MK),DIMENSION(:,:), POINTER      :: xp
          INTEGER,DIMENSION(:),    POINTER      :: nvlist
          INTEGER,DIMENSION(:,:),  POINTER      :: vlist
          INTEGER                               :: ip,iq,ineigh
          REAL(MK),DIMENSION(:), POINTER        :: D
          REAL(MK),DIMENSION(:), POINTER        :: Dtilde
          REAL(MK)                              :: rr
          REAL(MK)                              :: nn,max_nn,avg_nn
          INTEGER                               :: close_neigh
          INTEGER                               :: very_close_neigh
          CHARACTER(LEN=ppm_char)               :: cbuf
          CHARACTER(LEN=ppm_char)               :: caller = 'sop_check_nn'
          INTEGER,DIMENSION(:),POINTER          :: fuse_part
          INTEGER,DIMENSION(:),POINTER          :: nb_neigh
          INTEGER                               :: nb_close_theo, nb_fuse_neigh

          info = 0
          nvlist => Particles%nvlist
          vlist => Particles%vlist
          xp => Get_xp(Particles,with_ghosts=.TRUE.)
          D => Get_wps(Particles,Particles%D_id,with_ghosts=.TRUE.)

          Dtilde => Get_wps(Particles,Particles%Dtilde_id,with_ghosts=.TRUE.)

          fuse_part => Get_wpi(Particles,fuse_id,with_ghosts=.true.)
          nb_neigh => Get_wpi(Particles,nb_neigh_id)

          !max_nn = 0._mk
          avg_nn = 0._mk
          particle_loop: DO ip = 1,Particles%Npart
              nn = HUGE(1._MK)
              close_neigh = 0
              nb_fuse_neigh = 0
              very_close_neigh = 0

              neighbour_loop: DO ineigh = 1,nvlist(ip)
                  iq = vlist(ineigh,ip)

                  rr = SQRT(SUM((xp(1:ppm_dim,ip) - xp(1:ppm_dim,iq))**2)) / &
                      Dtilde(ip)
                      !MIN(Dtilde(ip),Dtilde(iq))
                      !MIN(D(ip),D(iq))

                  !compute nearest-neighbour distance for each particle
                  ! rescaled by the MIN of D(ip) and D(iq)
                  IF (rr .LT. nn) THEN
                      nn = rr
                  ENDIF
                  IF (rr .LT. 1.0_mk) THEN
                      close_neigh = close_neigh + 1
                      IF (fuse_part(iq).GT.0) nb_fuse_neigh=nb_fuse_neigh + 1
                  ENDIF
                  IF (rr*Dtilde(ip)/MIN(D(ip),D(iq)) .LT. opts%attractive_radius0) THEN
                      very_close_neigh = very_close_neigh + 1
                  ENDIF

              ENDDO neighbour_loop

              IF (nvlist(ip).GT.0) avg_nn = avg_nn + nn


              fuse_part(ip) = very_close_neigh

              !when the density is not too high, don't fuse particles
              IF (close_neigh .le.6) fuse_part(ip) = 0

              IF (ppm_dim.EQ.2) THEN
                  nb_close_theo = 6
              ELSE
                  nb_close_theo = 6
              ENDIF

              IF (nb_fuse_neigh .GE.1) nb_close_theo = nb_close_theo / 2

              IF (close_neigh .LE. nb_close_theo-1) THEN
                  IF (close_neigh .LE. nb_close_theo-2) then
                      adaptation_ok = .false.
                  ENDIF
                  !IF (nn .gt. opts%attractive_radius0 .and. opts%add_parts) THEN
                  IF (opts%add_parts) THEN
                      close_neigh=0
                      DO ineigh=1,nvlist(ip)
                          iq=vlist(ineigh,ip)

                          rr = SQRT(SUM((xp(1:ppm_dim,ip) - xp(1:ppm_dim,iq))**2)) / &
                              Dtilde(ip)
                          IF (rr .LT. 1.0_mk) THEN
                              close_neigh=close_neigh+1
                              vlist(close_neigh,ip) = iq
                          ENDIF
                      ENDDO
                      nvlist(ip) = min(1,close_neigh) !close_neigh ! min(close_neigh,6-close_neigh)
                      if (nvlist(ip) .eq. 0) then
                          nvlist(ip) = -6
                      endif
                  ELSE
                      nvlist(ip) = 0
                  ENDIF
              ELSE
                  nvlist(ip) = 0
              ENDIF
              !max_nn = MAX(nn,max_nn)
              if (fuse_part(ip).ge.1) nvlist(ip) = 0

              nb_neigh(ip) = close_neigh


          ENDDO particle_loop

          avg_nn = avg_nn / Particles%Npart
#if debug_verbosity > 1
          write(cbuf,*) 'AVG nearest-neighbour dist ',avg_nn, 'nb fuse ',&
              COUNT(fuse_part(1:Particles%Npart).GE.1)
          CALL ppm_write(ppm_rank,caller,cbuf,info)
#endif

          xp => Set_xp(Particles,read_only=.TRUE.)
          D => Set_wps(Particles,Particles%D_id,read_only=.TRUE.)
          Dtilde => Set_wps(Particles,Particles%Dtilde_id,read_only=.TRUE.)
          fuse_part => set_wpi(Particles,fuse_id)
          nb_neigh => Set_wpi(Particles,nb_neigh_id)

      END SUBROUTINE DTYPE(check_nn)

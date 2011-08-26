!!!----------------------------------------------------------------------------!
!!! Compute gradient of the potential w.r.t particles' positions
!!! Get ghost values for Gradient_Psi
!!!----------------------------------------------------------------------------!
SUBROUTINE sop_gradient_psi(Particles,topo_id,&
        Gradient_Psi,Psi_global,Psi_max,opts,info,gradD,gradPsi_max)

    USE ppm_module_data, ONLY: ppm_dim,ppm_rank,ppm_comm,ppm_mpi_kind
    USE ppm_module_particles
    USE ppm_module_map_part

    IMPLICIT NONE
#ifdef __MPI
    INCLUDE 'mpif.h'
#endif
#if   __KIND == __SINGLE_PRECISION
    INTEGER, PARAMETER :: MK = ppm_kind_single
#elif __KIND == __DOUBLE_PRECISION
    INTEGER, PARAMETER :: MK = ppm_kind_double
#endif

    ! arguments
    TYPE(ppm_t_particles),POINTER,       INTENT(INOUT)   :: Particles
    INTEGER,                             INTENT(IN   )   :: topo_id
    REAL(MK),DIMENSION(:,:),POINTER,     INTENT(INOUT)   :: Gradient_Psi
    REAL(MK),                            INTENT(  OUT)   :: Psi_global
    REAL(MK),                            INTENT(  OUT)   :: Psi_max
    TYPE(sop_t_opts), POINTER,           INTENT(IN   )   :: opts
    INTEGER,                             INTENT(  OUT)   :: info

    ! Optional arguments
    REAL(MK),DIMENSION(:,:),POINTER,OPTIONAL,INTENT(IN):: gradD
    REAL(MK),OPTIONAL,                   INTENT(  OUT)   :: gradPsi_max

    ! local variables
    INTEGER                               :: ip,iq,ineigh,iunit,di
    REAL(KIND(1.D0))                      :: t0
    REAL(MK)                              :: rr,meanD,nn,rd,rc
    REAL(MK),DIMENSION(ppm_dim)           :: dist
    REAL(MK)                              :: Psi_part,gradPsi,attractive_radius
    CHARACTER (LEN = ppm_char)            :: caller='sop_gradient_psi'
    CHARACTER (LEN = ppm_char)            :: filename,cbuf
    REAL(MK),DIMENSION(:,:),POINTER       :: xp => NULL()
    REAL(MK),DIMENSION(:  ),POINTER       :: D => NULL()
    REAL(MK),DIMENSION(:  ),POINTER       :: rcp => NULL()
    INTEGER, DIMENSION(:  ),POINTER       :: nvlist => NULL()
    INTEGER, DIMENSION(:,:),POINTER       :: vlist => NULL()
    REAL(MK)                              :: rho,coeff
    LOGICAL                               :: no_fusion
    INTEGER,DIMENSION(:),POINTER          :: fuse


    !For debugging
#if debug_verbosity > 1
    REAL(MK),DIMENSION(Particles%Npart)             :: Potential
#endif
    !end debugging

    !!-------------------------------------------------------------------------!
    !! Initialize
    !!-------------------------------------------------------------------------!
    info = 0
#if debug_verbosity > 0
    CALL substart(caller,t0,info)
#endif

    DO ip=1,Particles%Mpart
        Gradient_Psi(1:ppm_dim,ip) = 0._MK
    ENDDO

    Psi_global = 0._MK
    Psi_max   = 0._MK

    Particles%h_min     = HUGE(1._MK)

    xp => Get_xp(Particles,with_ghosts=.TRUE.)
    D  => Get_wps(Particles,Particles%D_id,with_ghosts=.TRUE.)
    rcp  => Get_wps(Particles,Particles%rcp_id,with_ghosts=.TRUE.)
    IF (.NOT.Particles%neighlists) THEN
        CALL ppm_write(ppm_rank,caller,&
            'need to compute neighbour lists first',info)
        info = -1
        GOTO 9999
    ENDIF
    nvlist => Particles%nvlist
    vlist => Particles%vlist

    fuse  => Get_wpi(Particles,fuse_id,with_ghosts=.TRUE.)

    !!-------------------------------------------------------------------------!
    !! Compute interaction potential and its gradient
    !!-------------------------------------------------------------------------!
    IF(PRESENT(gradPsi_max)) gradPsi_max = 0._mk
    particle_loop: DO ip = 1,Particles%Npart
        Psi_part = 0._MK
        nn = HUGE(1._MK)
#ifdef finnis_sinclair
        rho_part = 0._MK
#endif

        !Particles with few neighbours are a bit more reluctant to fuse
        !(not really necessary, but makes insertion/deletion a bit faster
        !in some cases)
            !IF (nvlist(ip).GT.30) THEN
        attractive_radius = opts%attractive_radius0
            !ELSE
                !attractive_radius = 0._MK
            !ENDIF

        neighbour_loop: DO ineigh = 1,nvlist(ip)
            iq = vlist(ineigh,ip)

            dist = xp(1:ppm_dim,ip) - xp(1:ppm_dim,iq)
            rr = SQRT(SUM(dist**2))

            IF (rr .LE. 1e-12) THEN
                WRITE(cbuf,*) 'Distance between particles less than 1e-12! ',&
                rr, ' ',ip,' ',iq,' xp = ',xp(1,ip),xp(2,ip),&
                    ' xq = ',xp(1,iq),xp(2,iq)
                CALL ppm_write(ppm_rank,caller,cbuf,info)
                info = -1
                GOTO 9999
            ENDIF

            !compute nearest-neighbour distance for each particle
            IF (rr .LT. nn) THEN
                nn = rr
            ENDIF

            !meanD = 0.5_MK*(D(ip) + D(iq))
            !meanD = MAX(D(ip) , D(iq))
            meanD = MIN(D(ip) , D(iq))

            ! Do not interact with particles which are too far away
            IF (meanD .GT. opts%rcp_over_D * opts%maximum_D) CYCLE

            !------------------------------------------------------------------!
            !Compute the gradients with respect to rpq
            !------------------------------------------------------------------!
            !------------------------------------------------------------------!
            ! here we can choose between different interaction potentials
            !------------------------------------------------------------------!
            rd = rr / meanD

            !if (fuse(ip)*fuse(iq).GE.1) then 
            if (fuse(ip)*fuse(iq).GE.1 .and. max(fuse(ip),fuse(iq)).ge.4 ) then 
                no_fusion = .false.
            else
                !if (fuse(iq).eq.1) cycle neighbour_loop
                no_fusion = .true.
            endif

            if (fuse(ip)+fuse(iq).GE.1 .and. max(fuse(ip),fuse(iq)).ge.4 ) then 
                coeff = 1._mk / REAL(MAX(fuse(ip),fuse(iq)),MK)
            else 
                coeff = 1._mk
            endif

#include "potential/potential_gradient.f90"

        Gradient_Psi(1:ppm_dim,ip)=Gradient_Psi(1:ppm_dim,ip) + &
            dist/rr * gradPsi

        ENDDO neighbour_loop

        Psi_global = Psi_global + Psi_part

        !For debugging, not needed
#if debug_verbosity > 1
        Potential(ip)=Psi_part
#endif
        !end debugging

        !!---------------------------------------------------------------------!
        !! Cap the values of the gradient such that particle displacements 
        !! cannot be larger than the size of the ghost layers.
        !! FIXME (account for variable ghost layer sizes)
        !! FIXME vectorize loops
        !!---------------------------------------------------------------------!
        !DO di=1,ppm_dim
        !IF (ABS(Gradient_Psi(di,ip)) .GT. MIN(nn,cutoff * 0.5_MK)) THEN
        !Gradient_Psi(di,ip) = Gradient_Psi(di,ip) * &
        !MIN(nn,cutoff * 0.5_MK) / ABS(Gradient_Psi(di,ip))
        !ENDIF
        !ENDDO
        IF (SUM(Gradient_Psi(1:ppm_dim,ip)**2) .GT. &
            &          MIN(nn**2,Particles%cutoff**2)) THEN
            Gradient_Psi(1:ppm_dim,ip) = Gradient_Psi(1:ppm_dim,ip) * &
                MIN(nn,Particles%cutoff)* 0.9_MK / &
                SQRT(SUM(Gradient_Psi(1:ppm_dim,ip)**2))
        ENDIF

        IF(PRESENT(gradPsi_max)) &
            gradPsi_max = MAX(gradPsi_max, SQRT(SUM(Gradient_Psi(1:ppm_dim,ip)**2)/D(ip)))


        !----------------------------------------------------------------------!
        ! Save the minimum and maximum separation distance on this processor
        ! (used for checking stability conditions, for example)
        !----------------------------------------------------------------------!
        Particles%h_min = MIN(Particles%h_min,nn)

#if debug_verbosity > 1
        IF (ISNAN(Psi_part)) THEN
            WRITE(*,*) 'Psi_part = ',Psi_part, ip, gradPsi, D(ip), nn
            WRITE(*,*) xp(1:ppm_dim,ip)
            WRITE(*,*) 'Grad = ',Gradient_Psi(1:ppm_dim,ip)
            DO ineigh=1,nvlist(ip)
                iq = vlist(ineigh,ip)
                WRITE(*,*) 'xp(iq)= ',xp(1:ppm_dim,ip) - xp(1:ppm_dim,iq)
            ENDDO
            DO ineigh=1,nvlist(ip)
                iq = vlist(ineigh,ip)
                WRITE(*,*) 'D(iq)= ',D(iq)
            ENDDO
            info = -1
            GOTO 9999
        ENDIF
#endif

    ENDDO particle_loop

    xp => Set_xp(Particles,read_only=.TRUE.)
    D  => Set_wps(Particles,Particles%D_id,read_only=.TRUE.)
    rcp  => Set_wps(Particles,Particles%rcp_id,read_only=.TRUE.)
    nvlist => NULL()
    vlist => NULL()


#if debug_verbosity > 2
    !For debugging, not needed
    CALL sop_dump_debug(Potential,Particles%Npart,477,info)
    !end debugging
#endif

    !!-------------------------------------------------------------------------!
    !! Compute the global potential of the particles 
    !! (it can be viewed as an objective function)
    !!-------------------------------------------------------------------------!

#ifdef __MPI
    CALL MPI_Allreduce(Psi_global,Psi_global,1,ppm_mpi_kind,MPI_SUM,ppm_comm,info)
    CALL MPI_Allreduce(Psi_max,Psi_max,1,ppm_mpi_kind,MPI_MAX,ppm_comm,info)
    IF (PRESENT(gradPsi_max)) &
        CALL MPI_Allreduce(gradPsi_max,gradPsi_max,1,ppm_mpi_kind,MPI_MAX,ppm_comm,info)
    IF (info .NE. 0) THEN
        CALL ppm_write(ppm_rank,caller,'MPI_Allreduce failed',info)
        info = -1
        GOTO 9999
    ENDIF
#endif

    IF (PRESENT(gradPsi_max)) &
        write(*,*) 'in gradient_psi, Max Gradient = ',gradPsi_max

    !!-------------------------------------------------------------------------!
    !! Get ghosts for gradient_psi (then, during the linesearch, 
    !! we can move ghost particles directly, without communicating)
    !!-------------------------------------------------------------------------!
    CALL ppm_map_part_push(Gradient_Psi,ppm_dim,Particles%Npart,info)
    IF (info .NE. 0) THEN
        info = ppm_error_error
        CALL ppm_error(ppm_err_sub_failed,caller,&
            'ppm_map_part_push failed',__LINE__,info)
        GOTO 9999
    ENDIF
    CALL ppm_map_part_send(Particles%Npart,Particles%Mpart,info)
    IF (info .NE. 0) THEN
        info = ppm_error_error
        CALL ppm_error(ppm_err_sub_failed,caller,&
            'ppm_map_part_send failed',__LINE__,info)
        GOTO 9999
    ENDIF
    CALL ppm_map_part_pop(Gradient_Psi,ppm_dim,Particles%Npart, &
        Particles%Mpart,info)
    IF (info .NE. 0) THEN
        info = ppm_error_error
        CALL ppm_error(ppm_err_sub_failed,caller,&
            'ppm_map_part_pop failed',__LINE__,info)
        GOTO 9999
    ENDIF

    !!-------------------------------------------------------------------------!
    !! Finalize
    !!-------------------------------------------------------------------------!
#if debug_verbosity > 0
    CALL substop(caller,t0,info)
#endif

    9999 CONTINUE ! jump here upon error

END SUBROUTINE sop_gradient_psi


#undef __KIND
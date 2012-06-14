         SUBROUTINE DTYPE(ppm_vtk_particles)(filename, Pc, info, &
              step, with_ghosts, with_nvlist, Fields)
           !--------------------------------------------------------------------
           !  Arguments
           !--------------------------------------------------------------------
           DEFINE_MK()
           CHARACTER(LEN=*),                INTENT(IN   ) :: filename
           CLASS(DTYPE(ppm_t_particles)_),  INTENT(INOUT) :: Pc
           INTEGER,                         INTENT(  OUT) :: info
           INTEGER,               OPTIONAL, INTENT(IN   ) :: step
           LOGICAL,               OPTIONAL, INTENT(IN   ) :: with_ghosts
           LOGICAL,               OPTIONAL, INTENT(IN   ) :: with_nvlist
           CLASS(ppm_v_main_abstr),OPTIONAL               :: Fields
           !!!list of fields to print out (default = ALL)

           !--------------------------------------------------------------------
           !  Variables
           !--------------------------------------------------------------------
           CHARACTER(LEN=ppm_char)              :: scratch
           CHARACTER(LEN=ppm_char)              :: fname
           INTEGER                              :: i,j,k,l,nd,N,ii
           INTEGER                              :: nb_wps, nb_wpv, nb_wp_field
           INTEGER                              :: nb_wpi
           LOGICAL                              :: ghosts
           LOGICAL                              :: nvlist
           REAL(MK), DIMENSION(:,:),POINTER     :: xp  => NULL()
           REAL(MK), DIMENSION(:),  POINTER     :: wp  => NULL()
           REAL(MK), DIMENSION(:,:),  POINTER   :: wp2d  => NULL()
           INTEGER, DIMENSION(:),   POINTER     :: wpi  => NULL()

           TYPE(DTYPE(ppm_v_part_prop)_)        :: props_i
           TYPE(DTYPE(ppm_v_part_prop)_)        :: props_s
           TYPE(DTYPE(ppm_v_part_prop)_)        :: props_v
           TYPE(DTYPE(ppm_v_part_prop)_)        :: props_vf

           CLASS(DTYPE(ppm_t_part_prop)_),POINTER :: prop => NULL()
           CLASS(ppm_t_discr_data),       POINTER :: discr_data => NULL()
           CLASS(ppm_t_main_abstr),       POINTER :: el => NULL()

           start_subroutine("ppm_vtk_particles")
           
           IF (PRESENT(step)) THEN
              WRITE(fname,'(A,A,I0)') &
                   filename(1:LEN_TRIM(filename)), '.', step
           ELSE
              fname = filename
           END IF

           ! print ghosts?
           IF (PRESENT(with_ghosts)) THEN
              ghosts = with_ghosts
           ELSE
              ghosts = .FALSE.
           END IF

           ! print nvlists?
           IF (PRESENT(with_nvlist)) THEN
              nvlist = with_nvlist
           ELSE
              nvlist = .FALSE.
           END IF


           IF (nvlist .AND. ghosts) THEN
               fail("printout of nvlist for ghosts not supported (yet)",&
                   ppm_err_argument)
           ENDIF

           nb_wpi=0
           nb_wps=0
           nb_wpv=0
           nb_wp_field=0

           IF (PRESENT(Fields)) THEN
               el => Fields%begin()
               DO WHILE (ASSOCIATED(el))
                   SELECT TYPE(field => el)
                   CLASS IS(ppm_t_field_)
                       !hack, so that Pc%props%iter_id is now the id
                       !of the discretization of field in Pc.
                       CALL field%get_discr(Pc,discr_data,info)
                           or_fail("could not get discr data for this field")
                           check_associated("discr_data")
                           SELECT TYPE(discr_data)
                           CLASS IS (DTYPE(ppm_t_part_prop)_)
                           prop => discr_data
                           END SELECT
                       SELECT CASE(field%data_type)
                       CASE (ppm_type_int)
                           CALL props_i%push(prop,info)
                           or_fail("push integer property into print buffer list")
                       CASE (ppm_type_real)
                           IF (field%lda.EQ.1) THEN
                               CALL props_s%push(prop,info)
                               or_fail("push scalar property into print buffer list")
                           ELSE
                               CALL props_v%push(prop,info)
                               or_fail("push vector property into print buffer list")
                           ENDIF
                       CASE DEFAULT
                               fail("not a supported type for printout (yet)")
                       END SELECT
                   CLASS DEFAULT
                       fail("elements of printout list should be of type ppm_t_field (for now)")
                   END SELECT
                   el => Fields%next()
               ENDDO
           ELSE
               !printout all properties i that are mapped
               prop => Pc%props%begin()
               DO WHILE (ASSOCIATED(prop))
                   IF (prop%flags(ppm_ppt_partial)) THEN
                       SELECT CASE (prop%data_type)
                       CASE (ppm_type_int)
                           IF (prop%lda.EQ.1) THEN
                               CALL props_i%push(prop,info)
                               or_fail("push integer property into print buffer list")
                           ENDIF

                       CASE (ppm_type_real)
                           IF (prop%lda.EQ.1) THEN
                               CALL props_s%push(prop,info)
                               or_fail("push integer property into print buffer list")
                           ELSE
                               CALL props_v%push(prop,info)
                               or_fail("push integer property into print buffer list")
                           ENDIF
                       CASE DEFAULT
                           !not a supported type for printout (yet)
                               fail("elements of printout list should be of type ppm_t_field (for now)")
                       END SELECT
                       prop => Pc%props%next()
                   ENDIF
               ENDDO
           ENDIF

           nb_wpi=props_i%nb
           nb_wps=props_s%nb
           nb_wpv=props_v%nb
           nb_wp_field=props_vf%nb


#ifdef __MPI
           ! write parallel file
           IF (ppm_rank .EQ. 0) THEN
              WRITE(scratch,'(A,A)') fname(1:LEN_TRIM(fname)), '.pvtp'
              OPEN(iUnit, FILE=scratch(1:LEN_TRIM(scratch)), &
                   IOSTAT=info, ACTION='WRITE')
              IF (info .NE. 0) THEN
                 info = ppm_error_fatal
                 WRITE(errtxt,'(2A)') 'Failed to open file: ', &
                      scratch(1:LEN_TRIM(scratch))
                 CALL ppm_error(ppm_err_argument, caller, errtxt, __LINE__, info)
                 GOTO 9999
              END IF
#define VTK_FILE_TYPE "PPolyData"
#define VTK_PARALLEL
#include "vtk/print_header.f"
              WRITE(iUnit,'(A)') "    <PPointData>"
              IF (nvlist) THEN
              WRITE(iUnit,'(3A)') "      <PDataArray Name='nvlist' type='Float64' />"
              END IF

              prop => props_i%begin()
              DO WHILE (ASSOCIATED(prop))
                  WRITE(iUnit,'(3A)') "      <PDataArray Name='", &
                      prop%name (1:LEN_TRIM(prop%name)), &
                      "' type='Float64' />"
                  prop => props_i%next()
              ENDDO

              prop => props_s%begin()
              DO WHILE (ASSOCIATED(prop))
                  WRITE(iUnit,'(3A)') "      <PDataArray Name='", &
                      prop%name (1:LEN_TRIM(prop%name)), &
                      "' type='Float64' />"
                  prop => props_s%next()
              ENDDO

              prop => props_v%begin()
              DO WHILE (ASSOCIATED(prop))
                  DO l=1,prop%lda
                      WRITE(scratch,'(A,A,I0)') TRIM(prop%name), '_', l
                      WRITE(iUnit,'(3A)') "      <PDataArray Name='", &
                          scratch(1:LEN_TRIM(scratch)), "' type='Float64' />"
                  END DO
                  prop => props_v%next()
              ENDDO

              prop => props_vf%begin()
              DO WHILE (ASSOCIATED(prop))
                  WRITE(iUnit,'(3A)') "      <PDataArray Name='", &
                   prop%name (1:LEN_TRIM(prop%name)), &
                   "' type='Float64' />"
                  prop => props_vf%next()
              ENDDO
              WRITE(iUnit,'(A)') "    </PPointData>"              
              WRITE(iUnit,'(A)') "    <PPoints>"
              WRITE(iUnit,'(A)') "      <PDataArray NumberOfComponents='3' type='Float64' />"
              WRITE(iUnit,'(A)') "    </PPoints>"
              ! find the basename of the file
              DO i=0,ppm_nproc-1
                 WRITE(iUnit,'(A,A,A,I0,A)') "    <Piece Source='",     &
                      fname(INDEX(fname, '/', .true.)+1:LEN_TRIM(fname)), &
                      ".", i, ".vtp' />"
              END DO
              ! close
#include "vtk/print_end_header.f"
              CLOSE(iUnit)
           END IF
           ! append rank to name
           WRITE(scratch,'(A,A,I0,A)') fname(1:LEN_TRIM(fname)), &
                                       '.', ppm_rank, '.vtp'
#else
           WRITE(scratch,'(A,A)') fname(1:LEN_TRIM(fname)), '.vtp'
#endif

           ! open output file
           OPEN(iUnit, FILE=scratch(1:LEN_TRIM(scratch)), &
                IOSTAT=info, ACTION='WRITE')
           IF (info .NE. 0) THEN
              info = ppm_error_fatal
              WRITE(errtxt,'(2A)') 'Failed to open file: ', &
                    scratch(1:LEN_TRIM(scratch))
              CALL ppm_error(ppm_err_argument, caller, errtxt, __LINE__, info)
              GOTO 9999
           END IF

           ! write data
           IF (ghosts) THEN
              N = Pc%Mpart
           ELSE
              N = Pc%Npart
           END IF

           ! write header
#define VTK_FILE_TYPE "PolyData"
#define VTK_NPOINTS N
#define VTK_NVERTS  N
#include "vtk/print_header.f"

           ! print properties
           IF (nvlist .OR. nb_wpi .GT. 0 .OR. nb_wps .GT. 0 .OR. nb_wpv .GT. 0) THEN

              ! print names
              WRITE(iUnit,'(A)',advance='no') "      <PointData" 
              IF (nvlist .OR. nb_wpi .GT. 0) THEN
                 WRITE(iUnit,'(A)',advance='no') " Integers='"
              ENDIF
              IF (nvlist) THEN
                 WRITE(iUnit,'(A)',advance='no') "nvlist"
                 IF (nb_wpi .GT. 0) WRITE(iUnit,'(A)',advance='no') " "
              END IF
              IF (nb_wpi .GT. 0) THEN
                 prop => props_i%begin()
                 DO WHILE (ASSOCIATED(prop))
                    WRITE(iUnit,'(A)',advance='no') &
                         prop%name (1:LEN_TRIM(prop%name))
                    !IF (i .LT. nb_wpi) WRITE(iUnit,'(A)',advance='no') " "
                     prop => props_i%next()
                 ENDDO
              END IF
              IF (nb_wps .GT. 0) THEN
                 IF (nvlist .OR. nb_wpi .GT. 0) &
                      WRITE(iUnit,'(A)',advance='no') "'"
                 WRITE(iUnit,'(A)',advance='no') " Scalars='"
                 prop => props_s%begin()
                 DO WHILE (ASSOCIATED(prop))
                     WRITE(iUnit,'(A)',advance='no') &
                         prop%name (1:LEN_TRIM(prop%name))
                    ! IF (i .LT. nb_wps) WRITE(iUnit,'(A)',advance='no') " "
                     prop => props_s%next()
                 ENDDO
              END IF
              IF (nb_wpv .GT. 0) THEN
                 IF (nvlist .OR. nb_wpi .GT. 0 .OR. nb_wps .GT. 0) &
                      WRITE(iUnit,'(A)',advance='no') "'"
                 WRITE(iUnit,'(A)',advance='no') " Vectors='"
                 prop => props_v%begin()
                 DO WHILE (ASSOCIATED(prop))
                     WRITE(iUnit,'(A)',advance='no') &
                         prop%name (1:LEN_TRIM(prop%name))
                    ! IF (i .LT. nb_wpv) WRITE(iUnit,'(A)',advance='no') " "
                     prop => props_v%next()
                 ENDDO
                 IF (nb_wpv .GT. 0 .AND. nb_wp_field .GT. 0) &
                      WRITE(iUnit,'(A)',advance='no') " "

                 prop => props_vf%begin()
                 DO WHILE (ASSOCIATED(prop))
                    WRITE(iUnit,'(A)',advance='no') &
                         prop%name (1:LEN_TRIM(prop%name))
              !      IF (i .LT. nb_wp_field) WRITE(iUnit,'(A)',advance='no') " "
                     prop => props_vf%next()
                 ENDDO
              END IF
              WRITE(iUnit,'(A)') "'>"

              ! property values
              IF (nvlist) THEN
                 CALL Pc%get_nvlist(nvlist=wpi,info=info)
                    or_fail("could not access neighbour list")
#define VTK_NAME "nvlist"
#define VTK_TYPE "Float64"
#define VTK_INTEGER wpi
#include "vtk/print_data_array.f"
                 wpi => null()
              end if

              prop => props_i%begin()
              DO WHILE (ASSOCIATED(prop))
                  wpi => prop%data_1d_i(1:N)
                  check_associated("wpi")
#define VTK_NAME prop%name
#define VTK_TYPE "Float64"
#define VTK_INTEGER wpi
#include "vtk/print_data_array.f"
                  wpi => NULL()
                  prop => props_i%next()
              ENDDO

              prop => props_s%begin()
              DO WHILE (ASSOCIATED(prop))
                  wp => prop%data_1d_r(1:N)
                  check_associated("wp")
#define VTK_NAME prop%name
#define VTK_TYPE "Float64"
#define VTK_SCALAR wp
#include "vtk/print_data_array.f"
                  wp => NULL()
                  prop => props_s%next()
              ENDDO

              prop => props_v%begin()
              DO WHILE (ASSOCIATED(prop))
                  wp2d => prop%data_2d_r(1:prop%lda,1:N)
                  check_associated("wp2d")
                  DO l=1,prop%lda
                      WRITE(scratch,'(A,A,I0)') TRIM(prop%name), '_', l
                      wp => wp2d(l,:)
#define VTK_NAME scratch
#define VTK_TYPE "Float64"
#define VTK_SCALAR wp
#include "vtk/print_data_array.f"
                      wp => NULL()
                  END DO
                  prop => props_v%next()
              ENDDO

              prop => props_vf%begin()
              DO WHILE (ASSOCIATED(prop))
                  wp2d => prop%data_2d_r(1:prop%lda,1:N)
                  check_associated("wp2d")
#define VTK_NAME prop%name
#define VTK_TYPE "Float64"
#define VTK_NDIM "3"
#define VTK_VECTOR wp2d
#define APPEND_ZEROS
#include "vtk/print_data_array.f"
                  wp2d => NULL()
                  prop => props_vf%next()
              ENDDO

              WRITE(iUnit,'(A)') "      </PointData>"
           END IF

           ! print point coordinates
           WRITE(iUnit,'(A)') "      <Points>"
           CALL Pc%get_xp(xp,info,with_ghosts=ghosts)
                or_fail("get_xp")
           nd = SIZE(xp,1)
#define VTK_TYPE "Float64"
#define VTK_NDIM "3"
#define VTK_VECTOR xp
#define APPEND_ZEROS
#include "vtk/print_data_array.f"
           CALL Pc%set_xp(xp,info,read_only=.TRUE.)
                or_fail("set_xp")
           WRITE(iUnit,'(A)') "      </Points>"

           ! create a vertex for every point
           WRITE(iUnit,'(A)') "      <Verts>"
           ! connectivity
           N = N - 1
#define VTK_RANGE N
#define VTK_RANGE_START 0
#define VTK_NAME "connectivity"
#define VTK_TYPE "Int32"
#include "vtk/print_data_array.f"
           ! offsets
           N = N + 1
#define VTK_RANGE N
#define VTK_NAME "offsets"
#define VTK_TYPE "Int32"
#include "vtk/print_data_array.f"
           WRITE(iUnit,'(A)') "      </Verts>"

           ! close
#include "vtk/print_end_header.f"
           ! close file
           end_subroutine()
           CLOSE(iUnit)
         END SUBROUTINE DTYPE(ppm_vtk_particles)

#undef __KIND
#undef DTYPE
#undef DEFINE_MK

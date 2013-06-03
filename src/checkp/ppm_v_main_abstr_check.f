      ! Store routines for ppm_v_main_abstr
            SUBROUTINE make_type_ppm_v_main_abstr(dtype_id)
               IMPLICIT NONE
               INTEGER(HID_T), INTENT(OUT) :: dtype_id
               INTEGER(HID_T) :: parent_id
               INTEGER error
               INTEGER(HSIZE_T) :: tsize, offset

               offset = 0
               tsize = 0

               ! Start with the parent Type
               CALL make_type_ppm_t_container(parent_id)
               CALL h5tcopy_f(parent_id, dtype_id, error)

               ! Calculate datatype size
               CALL h5tget_size_f(dtype_id, tsize, error) ! initial size



               tsize = tsize



               ! Create/Expand the datatype
               CALL h5tset_size_f(dtype_id, tsize, error)
               CALL h5tcreate_f(H5T_COMPOUND_F, tsize, dtype_id, error)

               ! Insert the members
               ! Insert the members
               ! Integer members

               ! Real members

               ! Character members

               ! Logical members



            END SUBROUTINE make_type_ppm_v_main_abstr

            SUBROUTINE store_ppm_v_main_abstr(cpfile_id, &
                  type_ptr_id, type_ptr)
               INTEGER(HID_T), INTENT(IN) :: cpfile_id
               INTEGER(HID_T) :: group_id, type_id, dset_id, &
                  dspace_id
               CHARACTER(LEN=*), INTENT(IN) :: type_ptr_id
               CLASS(ppm_v_main_abstr), POINTER :: type_ptr
               INTEGER error

               CALL h5gopen_f(cpfile_id, 'ppm_v_main_abstr', &
                  group_id, error)


               ! Make our dataset
               CALL make_type_ppm_v_main_abstr(type_id) ! get type
               CALL h5screate_f(H5S_SCALAR_F, dspace_id, error)  ! get space
               CALL h5dcreate_f(group_id, type_ptr_id, type_id, &
                   dspace_id, dset_id, error)

               CALL write_ppm_v_main_abstr(dset_id, type_ptr)

               CALL h5dclose_f(dset_id, error)
               CALL h5sclose_f(dspace_id, error)

               CALL h5gclose_f(group_id, error)
            END SUBROUTINE store_ppm_v_main_abstr

            SUBROUTINE write_ppm_v_main_abstr(dset_id, type_ptr)
               IMPLICIT NONE
               INTEGER(HID_T), INTENT(IN) :: dset_id
               CLASS(ppm_v_main_abstr), POINTER :: type_ptr
               CLASS(ppm_t_container), POINTER :: parent



               parent => type_ptr
               CALL write_ppm_t_container(dset_id, parent)
            END SUBROUTINE write_ppm_v_main_abstr

               ! File autogenerated by my super script
      ! Store routines for ppm_t_part_mapping_d_
            SUBROUTINE make_type_ppm_t_part_mapping_d_(dtype_id)
               IMPLICIT NONE
               INTEGER(HID_T), INTENT(OUT) :: dtype_id
               INTEGER(HID_T) :: parent_id
               INTEGER error
               INTEGER(HSIZE_T) :: tsize, offset
               INTEGER(HSIZE_T) :: isize

               offset = 0
               tsize = 0

               ! Start with the parent Type
               CALL make_type_ppm_t_mapping_d_(parent_id)
               CALL h5tcopy_f(parent_id, dtype_id, error)

               ! Calculate datatype size
               CALL h5tget_size_f(dtype_id, tsize, error) ! initial size

               CALL h5tget_size_f(H5T_NATIVE_INTEGER, isize, error)


               tsize = tsize + isize*(2)



               ! Create/Expand the datatype
               CALL h5tset_size_f(dtype_id, tsize, error)
               CALL h5tcreate_f(H5T_COMPOUND_F, tsize, dtype_id, error)

               ! Insert the members
               ! Insert the members
               ! Integer members
               CALL h5tinsert_f(dtype_id, "newNpart", offset, &
                     H5T_NATIVE_INTEGER, error)
               offset = offset + isize
               CALL h5tinsert_f(dtype_id, "oldNpart", offset, &
                     H5T_NATIVE_INTEGER, error)
               offset = offset + isize

               ! Real members

               ! Character members

               ! Logical members

               ! Pointer members



            END SUBROUTINE make_type_ppm_t_part_mapping_d_

            SUBROUTINE store_ppm_t_part_mapping_d_(cpfile_id, &
                  type_ptr_id, type_ptr)
               INTEGER(HID_T), INTENT(IN) :: cpfile_id
               INTEGER(HID_T) :: group_id, type_id, dset_id, &
                  dspace_id
               CHARACTER(LEN=*), INTENT(IN) :: type_ptr_id
               CLASS(ppm_t_part_mapping_d_), POINTER :: type_ptr
               INTEGER error

               CALL h5gopen_f(cpfile_id, 'ppm_t_part_mapping_d_', &
                  group_id, error)


               ! Make our dataset
               CALL make_type_ppm_t_part_mapping_d_(type_id) ! get type
               CALL h5screate_f(H5S_SCALAR_F, dspace_id, error)  ! get space
               CALL h5dcreate_f(group_id, type_ptr_id, type_id, &
                   dspace_id, dset_id, error)

               CALL write_ppm_t_part_mapping_d_(cpfile_id, dset_id, type_ptr)
               !CALL write_TYPE(dset_id, type_ptr)

               CALL h5dclose_f(dset_id, error)
               CALL h5sclose_f(dspace_id, error)

               CALL h5gclose_f(group_id, error)
            END SUBROUTINE store_ppm_t_part_mapping_d_

            SUBROUTINE write_ppm_t_part_mapping_d_(cpfile_id, dset_id, type_ptr)
            !SUBROUTINE write_TYPE(cpfile_id, dset_id, type_ptr)
               IMPLICIT NONE
               INTEGER(HID_T), INTENT(IN) :: dset_id
               INTEGER(HID_T), INTENT(in) :: cpfile_id
               CLASS(ppm_t_part_mapping_d_), POINTER :: type_ptr
               CLASS(ppm_t_mapping_d_), POINTER :: parent

               CALL write_attribute(dset_id, 'newNpart', &
                   type_ptr%newNpart)
               CALL write_attribute(dset_id, 'oldNpart', &
                   type_ptr%oldNpart)


               parent => type_ptr
               CALL write_ppm_t_mapping_d_(cpfile_id, dset_id, parent)
            END SUBROUTINE write_ppm_t_part_mapping_d_

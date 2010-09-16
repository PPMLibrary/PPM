      !--*- f90 -*--------------------------------------------------------------
      !  Module       :            ppm_module_map_field
      !-------------------------------------------------------------------------
      !  Parallel Particle Mesh Library (PPM)
      !  ETH Zurich
      !  CH-8092 Zurich, Switzerland
      !-------------------------------------------------------------------------

      !-------------------------------------------------------------------------
      !  Define types
      !-------------------------------------------------------------------------
#define __SINGLE_PRECISION         1
#define __DOUBLE_PRECISION         2
#define __INTEGER                  3
#define __LOGICAL                  4
#define __SINGLE_PRECISION_COMPLEX 5
#define __DOUBLE_PRECISION_COMPLEX 6
#define __2D                       7
#define __3D                       8
#define __SFIELD                   9
#define __VFIELD                   10

    MODULE ppm_module_map_field
      !!! This module contains interfaces to the field mapping routines
      !!! and all data structures and definitions that
      !!! are `PRIVATE` to the mesh routines.
      !!!
      !!! [NOTE]
      !!! The terminology distinguishes between meshes and fields
      !!! (the data living on the meshes). Several fields can use the
      !!! same mesh. Meshes are defined as ppm-internal TYPES, whereas
      !!! fields are user-provided arrays.

         !----------------------------------------------------------------------
         !  Includes
         !----------------------------------------------------------------------
         USE ppm_module_data, ONLY: ppm_kind_single,ppm_kind_double
         USE ppm_module_data_mesh
         PRIVATE :: ppm_kind_single,ppm_kind_double
      
         !----------------------------------------------------------------------
         !  List memory
         !----------------------------------------------------------------------
         INTEGER, DIMENSION(:), POINTER :: invsublist,sublist

         PRIVATE :: invsublist,sublist
         
         !----------------------------------------------------------------------
         !  Work memory
         !----------------------------------------------------------------------
         INTEGER, DIMENSION(:  ), POINTER :: isendfromsub,isendtosub
         INTEGER, DIMENSION(:,:), POINTER :: isendblkstart,isendblksize,ioffset
         INTEGER, DIMENSION(:  ), POINTER :: irecvfromsub,irecvtosub
         INTEGER, DIMENSION(:,:), POINTER :: irecvblkstart,irecvblksize

         PRIVATE :: isendfromsub,isendtosub,isendblkstart,isendblksize
         PRIVATE :: ioffset,irecvfromsub,irecvtosub,irecvblkstart,irecvblksize

         !----------------------------------------------------------------------
         !  Work lists
         !----------------------------------------------------------------------
         REAL(ppm_kind_single), DIMENSION(:), POINTER :: sends,recvs
         REAL(ppm_kind_double), DIMENSION(:), POINTER :: sendd,recvd
         INTEGER, DIMENSION(:), POINTER   :: nsend,nrecv,psend,precv
         INTEGER, DIMENSION(:,:), POINTER :: pp,qq

         PRIVATE :: sends,recvs,sendd,recvd,nsend,nrecv,psend,precv,qq,pp
         
         !----------------------------------------------------------------------
         !  Define interface to ppm_map_field_global
         !----------------------------------------------------------------------
         INTERFACE ppm_map_field_init
             MODULE PROCEDURE ppm_map_field_init
         END INTERFACE

         !----------------------------------------------------------------------
         !  Define interface to ppm_map_field_pop_2d
         !----------------------------------------------------------------------
         INTERFACE ppm_map_field_pop
             ! 2d meshes with scalar fields
             MODULE PROCEDURE ppm_map_field_pop_2d_sca_d
             MODULE PROCEDURE ppm_map_field_pop_2d_sca_s
             MODULE PROCEDURE ppm_map_field_pop_2d_sca_i
             MODULE PROCEDURE ppm_map_field_pop_2d_sca_l
             MODULE PROCEDURE ppm_map_field_pop_2d_sca_sc
             MODULE PROCEDURE ppm_map_field_pop_2d_sca_dc

             ! 2d meshes with vector fields
             MODULE PROCEDURE ppm_map_field_pop_2d_vec_d
             MODULE PROCEDURE ppm_map_field_pop_2d_vec_s
             MODULE PROCEDURE ppm_map_field_pop_2d_vec_i
             MODULE PROCEDURE ppm_map_field_pop_2d_vec_l
             MODULE PROCEDURE ppm_map_field_pop_2d_vec_sc
             MODULE PROCEDURE ppm_map_field_pop_2d_vec_dc

             ! 3d meshes with scalar fields
             MODULE PROCEDURE ppm_map_field_pop_3d_sca_d
             MODULE PROCEDURE ppm_map_field_pop_3d_sca_s
             MODULE PROCEDURE ppm_map_field_pop_3d_sca_i
             MODULE PROCEDURE ppm_map_field_pop_3d_sca_l
             MODULE PROCEDURE ppm_map_field_pop_3d_sca_sc
             MODULE PROCEDURE ppm_map_field_pop_3d_sca_dc

             ! 3d meshes with vector fields
             MODULE PROCEDURE ppm_map_field_pop_3d_vec_d
             MODULE PROCEDURE ppm_map_field_pop_3d_vec_s
             MODULE PROCEDURE ppm_map_field_pop_3d_vec_i
             MODULE PROCEDURE ppm_map_field_pop_3d_vec_l
             MODULE PROCEDURE ppm_map_field_pop_3d_vec_sc
             MODULE PROCEDURE ppm_map_field_pop_3d_vec_dc
         END INTERFACE

         !----------------------------------------------------------------------
         !  Define interface to ppm_map_field_push
         !----------------------------------------------------------------------
         INTERFACE ppm_map_field_push
             ! 2d meshes with scalar fields 
             MODULE PROCEDURE ppm_map_field_push_2d_sca_d
             MODULE PROCEDURE ppm_map_field_push_2d_sca_s
             MODULE PROCEDURE ppm_map_field_push_2d_sca_i
             MODULE PROCEDURE ppm_map_field_push_2d_sca_l
             MODULE PROCEDURE ppm_map_field_push_2d_sca_sc
             MODULE PROCEDURE ppm_map_field_push_2d_sca_dc

             ! 2d meshes with vector fields 
             MODULE PROCEDURE ppm_map_field_push_2d_vec_d
             MODULE PROCEDURE ppm_map_field_push_2d_vec_s
             MODULE PROCEDURE ppm_map_field_push_2d_vec_i
             MODULE PROCEDURE ppm_map_field_push_2d_vec_l
             MODULE PROCEDURE ppm_map_field_push_2d_vec_sc
             MODULE PROCEDURE ppm_map_field_push_2d_vec_dc

             ! 3d meshes with scalar fields
             MODULE PROCEDURE ppm_map_field_push_3d_sca_d
             MODULE PROCEDURE ppm_map_field_push_3d_sca_s
             MODULE PROCEDURE ppm_map_field_push_3d_sca_i
             MODULE PROCEDURE ppm_map_field_push_3d_sca_l
             MODULE PROCEDURE ppm_map_field_push_3d_sca_sc
             MODULE PROCEDURE ppm_map_field_push_3d_sca_dc

             ! 3d meshes with vector fields
             MODULE PROCEDURE ppm_map_field_push_3d_vec_d
             MODULE PROCEDURE ppm_map_field_push_3d_vec_s
             MODULE PROCEDURE ppm_map_field_push_3d_vec_i
             MODULE PROCEDURE ppm_map_field_push_3d_vec_l
             MODULE PROCEDURE ppm_map_field_push_3d_vec_sc
             MODULE PROCEDURE ppm_map_field_push_3d_vec_dc
         END INTERFACE
         
         !----------------------------------------------------------------------
         !  Define interface to ppm_map_field_send
         !----------------------------------------------------------------------
         INTERFACE ppm_map_field_send
             MODULE PROCEDURE ppm_map_field_send
         END INTERFACE


#ifdef __MPI
         !----------------------------------------------------------------------
         !  Define interface to ppm_map_field_send_noblock
         !----------------------------------------------------------------------
         INTERFACE ppm_map_field_send_noblock
             MODULE PROCEDURE ppm_map_field_send_noblock
         END INTERFACE

         !----------------------------------------------------------------------
         !  Define interface to ppm_map_field_send_alltoall
         !----------------------------------------------------------------------
         INTERFACE ppm_map_field_send_alltoall
            MODULE PROCEDURE ppm_map_field_send_alltoall
         END INTERFACE
#endif

         !----------------------------------------------------------------------
         !  Include the source
         !----------------------------------------------------------------------
         CONTAINS

#include "map/ppm_map_field_init.f"

#define __DIM __SFIELD
#define __MESH_DIM __2D
#define __KIND __SINGLE_PRECISION
#include "map/ppm_map_field_pop_2d.f"
#undef __KIND

#define __KIND __DOUBLE_PRECISION
#include "map/ppm_map_field_pop_2d.f"
#undef __KIND
         
#define __KIND __SINGLE_PRECISION_COMPLEX
#include "map/ppm_map_field_pop_2d.f"
#undef __KIND
         
#define __KIND __DOUBLE_PRECISION_COMPLEX
#include "map/ppm_map_field_pop_2d.f"
#undef __KIND

#define __KIND __INTEGER
#include "map/ppm_map_field_pop_2d.f"
#undef __KIND

#define __KIND __LOGICAL
#include "map/ppm_map_field_pop_2d.f"
#undef __KIND
#undef __MESH_DIM

#define _MESH_DIM __3D
#define __KIND __SINGLE_PRECISION
#include "map/ppm_map_field_pop_3d.f"
#undef __KIND

#define __KIND __DOUBLE_PRECISION
#include "map/ppm_map_field_pop_3d.f"
#undef __KIND

#define __KIND __SINGLE_PRECISION_COMPLEX
#include "map/ppm_map_field_pop_3d.f"
#undef __KIND

#define __KIND __DOUBLE_PRECISION_COMPLEX
#include "map/ppm_map_field_pop_3d.f"
#undef __KIND

#define __KIND __INTEGER
#include "map/ppm_map_field_pop_3d.f"
#undef __KIND

#define __KIND __LOGICAL
#include "map/ppm_map_field_pop_3d.f"
#undef __KIND
#undef __MESH_DIM
#undef __DIM

#define __DIM __VFIELD
#define __MESH_DIM __2D
#define __KIND __SINGLE_PRECISION
#include "map/ppm_map_field_pop_2d.f"
#undef __KIND

#define __KIND __DOUBLE_PRECISION
#include "map/ppm_map_field_pop_2d.f"
#undef __KIND

#define __KIND __SINGLE_PRECISION_COMPLEX
#include "map/ppm_map_field_pop_2d.f"
#undef __KIND

#define __KIND __DOUBLE_PRECISION_COMPLEX
#include "map/ppm_map_field_pop_2d.f"
#undef __KIND

#define __KIND __INTEGER
#include "map/ppm_map_field_pop_2d.f"
#undef __KIND

#define __KIND __LOGICAL
#include "map/ppm_map_field_pop_2d.f"
#undef __KIND
#undef __MESH_DIM

#define __MESH_DIM __3D
#define __KIND __SINGLE_PRECISION
#include "map/ppm_map_field_pop_3d.f"
#undef __KIND

#define __KIND __DOUBLE_PRECISION
#include "map/ppm_map_field_pop_3d.f"
#undef __KIND

#define __KIND __SINGLE_PRECISION_COMPLEX
#include "map/ppm_map_field_pop_3d.f"
#undef __KIND

#define __KIND __DOUBLE_PRECISION_COMPLEX
#include "map/ppm_map_field_pop_3d.f"
#undef __KIND

#define __KIND __INTEGER
#include "map/ppm_map_field_pop_3d.f"
#undef __KIND

#define __KIND __LOGICAL
#include "map/ppm_map_field_pop_3d.f"
#undef __KIND
#undef __MESH_DIM
#undef __DIM


#define __DIM __SFIELD
#define __MESH_DIM __2D
#define __KIND __SINGLE_PRECISION
#include "map/ppm_map_field_push_2d.f"
#undef __KIND

#define __KIND __DOUBLE_PRECISION
#include "map/ppm_map_field_push_2d.f"
#undef __KIND

#define __KIND __SINGLE_PRECISION_COMPLEX
#include "map/ppm_map_field_push_2d.f"
#undef __KIND

#define __KIND __DOUBLE_PRECISION_COMPLEX
#include "map/ppm_map_field_push_2d.f"
#undef __KIND

#define __KIND __INTEGER
#include "map/ppm_map_field_push_2d.f"
#undef __KIND

#define __KIND __LOGICAL
#include "map/ppm_map_field_push_2d.f"
#undef __KIND
#undef __MESH_DIM

#define __MESH_DIM __3D
#define __KIND __SINGLE_PRECISION
#include "map/ppm_map_field_push_3d.f"
#undef __KIND

#define __KIND __DOUBLE_PRECISION
#include "map/ppm_map_field_push_3d.f"
#undef __KIND
         
#define __KIND __SINGLE_PRECISION_COMPLEX
#include "map/ppm_map_field_push_3d.f"
#undef __KIND
         
#define __KIND __DOUBLE_PRECISION_COMPLEX
#include "map/ppm_map_field_push_3d.f"
#undef __KIND

#define __KIND __INTEGER
#include "map/ppm_map_field_push_3d.f"
#undef __KIND

#define __KIND __LOGICAL
#include "map/ppm_map_field_push_3d.f"
#undef __KIND
#undef __MESH_DIM
#undef __DIM

#define __DIM __VFIELD
#define __MESH_DIM __2D
#define __KIND __SINGLE_PRECISION
#include "map/ppm_map_field_push_2d.f"
#undef __KIND

#define __KIND __DOUBLE_PRECISION
#include "map/ppm_map_field_push_2d.f"
#undef __KIND

#define __KIND __SINGLE_PRECISION_COMPLEX
#include "map/ppm_map_field_push_2d.f"
#undef __KIND

#define __KIND __DOUBLE_PRECISION_COMPLEX
#include "map/ppm_map_field_push_2d.f"
#undef __KIND

#define __KIND __INTEGER
#include "map/ppm_map_field_push_2d.f"
#undef __KIND

#define __KIND __LOGICAL
#include "map/ppm_map_field_push_2d.f"
#undef __KIND
#undef __MESH_DIM

#define __MESH_DIM __3D
#define __KIND __SINGLE_PRECISION
#include "map/ppm_map_field_push_3d.f"
#undef __KIND

#define __KIND __DOUBLE_PRECISION
#include "map/ppm_map_field_push_3d.f"
#undef __KIND

#define __KIND __SINGLE_PRECISION_COMPLEX
#include "map/ppm_map_field_push_3d.f"
#undef __KIND

#define __KIND __DOUBLE_PRECISION_COMPLEX
#include "map/ppm_map_field_push_3d.f"
#undef __KIND

#define __KIND __INTEGER
#include "map/ppm_map_field_push_3d.f"
#undef __KIND

#define __KIND __LOGICAL
#include "map/ppm_map_field_push_3d.f"
#undef __KIND
#undef __MESH_DIM
#undef __DIM


#include "map/ppm_map_field_send.f"

#ifdef __MPI
#include "map/ppm_map_field_send_noblock.f"

#include "map/ppm_map_field_send_alltoall.f"
#endif

      END MODULE ppm_module_map_field

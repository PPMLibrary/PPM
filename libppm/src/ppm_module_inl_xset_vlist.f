     !-------------------------------------------------------------------------
     !  Module   :                  ppm_module_inl_xset_vlist
     !-------------------------------------------------------------------------
     ! Copyright (c) 2010 CSE Lab (ETH Zurich), MOSAIC Group (ETH Zurich),
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
     !-------------------------------------------------------------------------
      MODULE ppm_module_inl_xset_vlist
      !!! This module contains routines and functions used in creating verlet lists
      !!! by use of inhomogeneous cell lists.

#define __SINGLE_PRECISION 1
#define __DOUBLE_PRECISION 2
#define __COUNT 3
#define __GET 4
        !-------------------------------------------------------------------------
        !  Used modules
        !-------------------------------------------------------------------------
        USE ppm_module_data
        USE ppm_module_inl_clist
        USE ppm_module_alloc
        USE ppm_module_error
        USE ppm_module_substart
        USE ppm_module_substop

        !-------------------------------------------------------------------------
        !  Declaration of arrays
        !-------------------------------------------------------------------------
        INTEGER,       DIMENSION(:),   POINTER :: own_red => NULL()
        INTEGER,       DIMENSION(:),   POINTER :: neigh_red => NULL()
        INTEGER,       DIMENSION(:),   POINTER :: own_blue => NULL()
        INTEGER,       DIMENSION(:),   POINTER :: neigh_blue => NULL()
        INTEGER(ppm_kind_int64), DIMENSION(:), POINTER :: empty_list => NULL()
        INTEGER,       DIMENSION(:,:), POINTER :: ncells => NULL()
        LOGICAL,       DIMENSION(:) ,  POINTER :: used => NULL()

        !-------------------------------------------------------------------------
        !  Declaration of variables
        !-------------------------------------------------------------------------
        TYPE(ppm_clist), SAVE :: red_clist
        TYPE(ppm_clist), SAVE :: blue_clist
        INTEGER               :: own_nred
        INTEGER               :: neigh_nred
        INTEGER               :: own_nblue
        INTEGER               :: neigh_nblue
        INTEGER               :: empty_pos
        INTEGER               :: max_nneigh

        !-------------------------------------------------------------------------
        !  Declaration of interfaces
        !-------------------------------------------------------------------------
        INTERFACE ppm_inl_xset_vlist
            MODULE PROCEDURE inl_xset_vlist_s
            MODULE PROCEDURE inl_xset_vlist_d
        END INTERFACE

        INTERFACE create_inl_xset_vlist
            MODULE PROCEDURE create_inl_xset_vlist_s
            MODULE PROCEDURE create_inl_xset_vlist_d
        END INTERFACE

        INTERFACE get_xset_VerletLists
            MODULE PROCEDURE get_xset_VerletLists_s
            MODULE PROCEDURE get_xset_VerletLists_d
        END INTERFACE


        INTERFACE count_xset_neigh
            MODULE PROCEDURE count_xset_neigh_s
            MODULE PROCEDURE count_xset_neigh_d
        END INTERFACE

        INTERFACE get_xset_neigh
            MODULE PROCEDURE get_xset_neigh_s
            MODULE PROCEDURE get_xset_neigh_d
        END INTERFACE



        !-------------------------------------------------------------------------
        !  Privatizing arrays, variables and parameters
        !-------------------------------------------------------------------------
!!! to be completed when test driver is removed!

        CONTAINS

#define __KIND __SINGLE_PRECISION
#include "neighlist/ppm_inl_xset_vlist.f"
#define __ACTION __COUNT
#include "neighlist/ppm_inl_xset_vlist_build.f"
#undef __ACTION
#define __ACTION __GET
#include "neighlist/ppm_inl_xset_vlist_build.f"
#undef __ACTION
#undef  __KIND
#define __KIND __DOUBLE_PRECISION
#include "neighlist/ppm_inl_xset_vlist.f"
#define __ACTION __COUNT
#include "neighlist/ppm_inl_xset_vlist_build.f"
#undef __ACTION
#define __ACTION __GET
#include "neighlist/ppm_inl_xset_vlist_build.f"
#undef __ACTION
#undef  __KIND

#undef __SINGLE_PRECISION
#undef __DOUBLE_PRECISION
#undef __COUNT
#undef __GET
      END MODULE ppm_module_inl_xset_vlist

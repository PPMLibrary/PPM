      !--*- f90 -*--------------------------------------------------------------
      !  Module       :                ppm_module_neighlist
      !-------------------------------------------------------------------------
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
      !-------------------------------------------------------------------------

      !-------------------------------------------------------------------------
      !  Define types
      !-------------------------------------------------------------------------
#define __SINGLE_PRECISION 1
#define __DOUBLE_PRECISION 2

      MODULE ppm_module_neighlist
      !!! This module provides neighbor
      !!! search routines (cell lists, Verlet lists).

         USE ppm_module_typedef, ONLY: ppm_t_clist


         TYPE(ppm_t_clist), DIMENSION(:), POINTER   :: ppm_clist => NULL()
         PRIVATE :: ppm_clist


         !----------------------------------------------------------------------
         !  Define interface to ppm_clist_destroy
         !----------------------------------------------------------------------
         INTERFACE ppm_clist_destroy
            MODULE PROCEDURE ppm_clist_destroy
         END INTERFACE

         !----------------------------------------------------------------------
         !  Define interface to ppm_neighlist_MkNeighIdx
         !----------------------------------------------------------------------
         INTERFACE ppm_neighlist_MkNeighIdx
            MODULE PROCEDURE ppm_neighlist_MkNeighIdx
         END INTERFACE

         INTERFACE ppm_neighlist_clist
            MODULE PROCEDURE ppm_neighlist_clist_d
            MODULE PROCEDURE ppm_neighlist_clist_s
         END INTERFACE

         !----------------------------------------------------------------------
         !  Define interface to ppm_neighlist_vlist
         !----------------------------------------------------------------------
         INTERFACE ppm_neighlist_vlist
            MODULE PROCEDURE ppm_neighlist_vlist_d
            MODULE PROCEDURE ppm_neighlist_vlist_s
         END INTERFACE



         !----------------------------------------------------------------------
         !  include the source
         !----------------------------------------------------------------------
         CONTAINS

#include "neighlist/ppm_clist_destroy.f"

#include "neighlist/ppm_neighlist_MkNeighIdx.f"

#define __KIND __SINGLE_PRECISION
#include "neighlist/ppm_neighlist_clist.f"
#undef  __KIND

#define __KIND __DOUBLE_PRECISION
#include "neighlist/ppm_neighlist_clist.f"
#undef  __KIND

#define __KIND __SINGLE_PRECISION
#include "neighlist/ppm_neighlist_vlist.f"
#undef  __KIND

#define __KIND __DOUBLE_PRECISION
#include "neighlist/ppm_neighlist_vlist.f"
#undef  __KIND

      END MODULE ppm_module_neighlist

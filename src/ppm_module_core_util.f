      !--*- f90 -*--------------------------------------------------------------
      !  Module       :                ppm_module_core_util
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

      MODULE ppm_module_core_util
      !!! This module contains all user-callable utility routines.
         !----------------------------------------------------------------------
         !  PPM modules
         !----------------------------------------------------------------------
         USE ppm_module_init
         USE ppm_module_finalize
         USE ppm_module_find_duplicates
         USE ppm_module_is_initialized
         USE ppm_module_time
         USE ppm_module_util_dbg
         USE ppm_module_util_netstat

      END MODULE ppm_module_core_util

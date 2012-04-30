!-------------------------------------------------------------------------
!  Subroutine   :                  field_interfaces
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
!CREATE
SUBROUTINE field_create_(this,lda,info,dtype,name,init_func)
    IMPORT ppm_t_field_,ppm_kind_double
    CLASS(ppm_t_field_)                     :: this
    INTEGER,                     INTENT(IN) :: lda
    INTEGER,                    INTENT(OUT) :: info
    INTEGER,OPTIONAL,            INTENT(IN) :: dtype
    CHARACTER(LEN=*),OPTIONAL,   INTENT(IN) :: name
    REAL(ppm_kind_double),EXTERNAL,POINTER,OPTIONAL,INTENT(IN) :: init_func
END SUBROUTINE
!DESTROY
SUBROUTINE field_destroy_(this,info)
    IMPORT ppm_t_field_
    CLASS(ppm_t_field_)                 :: this
    INTEGER,               INTENT(OUT) :: info
END SUBROUTINE
!CREATE
SUBROUTINE discr_info_create_(this,discr,discr_data,lda,flags,info,p_idx)
    IMPORT ppm_t_discr_info_,ppm_t_discr_kind,ppm_t_discr_data,ppm_mdata_lflags
    CLASS(ppm_t_discr_info_)                  :: this
    CLASS(ppm_t_discr_kind),TARGET,INTENT(IN) :: discr
    CLASS(ppm_t_discr_data),TARGET,INTENT(IN) :: discr_data
    INTEGER,                       INTENT(IN) :: lda
    LOGICAL,DIMENSION(ppm_mdata_lflags)       :: flags
    INTEGER,                       INTENT(OUT):: info
    INTEGER,OPTIONAL,              INTENT(IN) :: p_idx
END SUBROUTINE
!DESTROY
SUBROUTINE discr_info_destroy_(this,info)
    IMPORT ppm_t_discr_info_
    CLASS(ppm_t_discr_info_)           :: this
    INTEGER,               INTENT(OUT) :: info
END SUBROUTINE
!DISCRETIZE FIELD ON MESH OR PARTICLES
SUBROUTINE field_discretize_on_(this,discr,info,datatype,with_ghosts)
    IMPORT ppm_t_field_,ppm_t_discr_kind
    !!! Allocate field on a mesh or on a particle set
    !!! If the field has a procedure for initialization (e.g. an
    !!! initial condition), then the field is also initialized.
    CLASS(ppm_t_field_)                :: this
    CLASS(ppm_t_discr_kind),TARGET     :: discr
    INTEGER,               INTENT(OUT) :: info
    INTEGER, OPTIONAL                  :: datatype
    LOGICAL, OPTIONAL                  :: with_ghosts
END SUBROUTINE 
!ESTABLISH RELATIONSHIP BETWEEN FIELD AND DISCRETIZATION
SUBROUTINE field_set_rel_discr_(this,discr,discr_data,info,p_idx)
    IMPORT ppm_t_field_,ppm_t_discr_kind,ppm_t_discr_data
    CLASS(ppm_t_field_)                :: this
    CLASS(ppm_t_discr_kind)            :: discr
    CLASS(ppm_t_discr_data)            :: discr_data
    INTEGER,               INTENT(OUT) :: info
    INTEGER,OPTIONAL,      INTENT(IN)  :: p_idx
END SUBROUTINE
!PUSH FIELD DATA ON A MESH GHOST MAPPING BUFFERS
SUBROUTINE field_map_ghost_push_(this,mesh,info)
    IMPORT ppm_t_field_,ppm_t_equi_mesh_
    CLASS(ppm_t_field_)                 :: this
    CLASS(ppm_t_equi_mesh_)             :: mesh
    INTEGER,                INTENT(OUT) :: info
END SUBROUTINE
!POP FIELD DATA FROM A MESH GHOST MAPPING BUFFERS
SUBROUTINE field_map_ghost_pop_(this,mesh,info)
    IMPORT ppm_t_field_,ppm_t_equi_mesh_
    CLASS(ppm_t_field_)                 :: this
    CLASS(ppm_t_equi_mesh_)             :: mesh
    INTEGER,                INTENT(OUT) :: info
END SUBROUTINE


SUBROUTINE field_get_discr_(this,discr_kind,discr_data,info,tstep)
    IMPORT ppm_t_field_,ppm_t_discr_kind,ppm_t_discr_data
    CLASS(ppm_t_field_)                          :: this
    CLASS(ppm_t_discr_kind),TARGET,  INTENT(IN ) :: discr_kind
    CLASS(ppm_t_discr_data),POINTER, INTENT(OUT) :: discr_data
    !!! discretization
    INTEGER,                         INTENT(OUT) :: info
    INTEGER,OPTIONAL,                INTENT(IN ) :: tstep
END SUBROUTINE

FUNCTION field_get_pid_(this,discr_kind,tstep) RESULT(p_idx)
    IMPORT ppm_t_field_,ppm_t_discr_kind
    CLASS(ppm_t_field_)                          :: this
    CLASS(ppm_t_discr_kind),TARGET,  INTENT(IN ) :: discr_kind
    !!! discretization
    INTEGER,OPTIONAL,                INTENT(IN ) :: tstep
    INTEGER                                      :: p_idx
END FUNCTION

FUNCTION field_is_discretized_on_(this,discr_kind,tstep) RESULT(res)
    IMPORT ppm_t_field_,ppm_t_discr_kind
    CLASS(ppm_t_field_)                          :: this
    CLASS(ppm_t_discr_kind),TARGET,  INTENT(IN ) :: discr_kind
    !!! discretization
    LOGICAL                                      :: res
    INTEGER,OPTIONAL,                INTENT(IN ) :: tstep
END FUNCTION
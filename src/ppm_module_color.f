      !-------------------------------------------------------------------------
      !  Module       :                 ppm_module_color
      !-------------------------------------------------------------------------
      ! Copyright (c) 2016 CSE Lab (ETH Zurich), MOSAIC Group (MPI-CBG Dresden),
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
      !-------------------------------------------------------------------------
      !  MOSAIC Group
      !  Max Planck Institute of Molecular Cell Biology and Genetics
      !  Pfotenhauerstr. 108, 01307 Dresden, Germany
      !-------------------------------------------------------------------------

      MODULE ppm_module_color
      !!! This module provides the utility coloring routines,
      !!! to find coloring of a graph vertices & edges

      IMPLICIT NONE
      PRIVATE
      !-------------------------------------------------------------------------
      !  Declaration of types
      !-------------------------------------------------------------------------

      TYPE vertex
      !!! declaration of type: vertex
          INTEGER, DIMENSION(:), POINTER :: list => NULL()
          !!! list of vertices that the vertex is connected to
          INTEGER                        :: degree
          !!! degree of the vertex
          INTEGER                        :: color
          !!! color of the vertex
          INTEGER                        :: dsat
          !!! dsat-value of the vertex
          INTEGER                        :: loc_heap
          !!! location of vertex in heap list
          LOGICAL                        :: iscolored
          !!! TRUE if the vertex is colored
      END TYPE vertex

      TYPE list
      !!! declaration of type: list
          INTEGER, DIMENSION(:), POINTER :: adj_edge => NULL()
          !!! list of adjacent node of the node
      END TYPE list

      !-------------------------------------------------------------------------
      !  Declaration of arrays
      !-------------------------------------------------------------------------
      TYPE(vertex), DIMENSION(:),   ALLOCATABLE :: node
      !!! Array of nodes
      TYPE(list),   DIMENSION(:),   ALLOCATABLE :: edges_per_node
      !!! number of edges per node
      TYPE(list),   DIMENSION(:),   ALLOCATABLE :: lists
      !!! array of adjacency lists, one for each node

      INTEGER,      DIMENSION(:),   ALLOCATABLE :: nelem
      !!! array for number of nodes that are adjacent to each node
      INTEGER,      DIMENSION(:),   ALLOCATABLE :: offset
      !!! where to put the next node in the adjacency list of another
      INTEGER,      DIMENSION(:,:), ALLOCATABLE :: node_sat
      !!! 2-D array for keeping nodes according to their d-sat values
      !!! and degrees where rows are dsat values and columns are node
      !!! numbers sorted by degree of nodes
      INTEGER,      DIMENSION(:),   ALLOCATABLE :: size_heap
      !!! size of the heap for each row (d-sat value)

      LOGICAL,      DIMENSION(:),   ALLOCATABLE :: used_color
      !!! Array to be used to count number of distinct colors

      !-------------------------------------------------------------------------
      !  Declaration of variables
      !-------------------------------------------------------------------------
      INTEGER                                   :: nvertices
      !!! number of vertices in the graph
      INTEGER                                   :: nedges
      !!! number of edges in the graph
      INTEGER                                   :: max_degree
      !!! degree of the graph
      INTEGER                                   :: ncolor
      !!! number of colors to be used

      INTEGER,      DIMENSION(1)                :: ldc

      INTERFACE ppm_color_edge
          MODULE PROCEDURE ppm_color_edge
      END INTERFACE

      INTERFACE ppm_color_vertex
          MODULE PROCEDURE ppm_color_vertex
      END INTERFACE

      !----------------------------------------------------------------------
      !  PUBLIC
      !----------------------------------------------------------------------
      PUBLIC :: ppm_color_edge
      PUBLIC :: ppm_color_vertex

      !----------------------------------------------------------------------
      !  include the source
      !----------------------------------------------------------------------
      CONTAINS

#include "util/ppm_color_edge.f"
#include "util/ppm_color_vertex.f"

      END MODULE ppm_module_color

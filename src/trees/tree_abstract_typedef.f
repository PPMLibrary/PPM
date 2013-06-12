      TYPE pointer_trees
         INTEGER :: num_intrinsic = 1
         CLASS(derived_tree), POINTER :: dtree
         CLASS(intrinsic_tree), POINTER :: itree
         CONTAINS
            PROCEDURE :: pointer_insert
      END TYPE
      TYPE,abstract :: pointer_btree
         CHARACTER(LEN=32) :: key
      END TYPE pointer_btree
      TYPE, abstract, extends(pointer_btree) :: derived_tree
         CLASS(derived_tree), POINTER :: left
         CLASS(derived_tree), POINTER :: right
      END TYPE derived_tree
      TYPE, abstract, extends(pointer_btree) :: intrinsic_tree
         INTEGER :: hash
         CLASS(intrinsic_tree), POINTER :: left
         CLASS(intrinsic_tree), POINTER :: right
      END TYPE intrinsic_tree
      TYPE, extends(intrinsic_tree) :: integer_tree
         INTEGER, POINTER :: val
      END TYPE
      TYPE, extends(intrinsic_tree) :: integer1d_tree
         INTEGER, DIMENSION(:), POINTER :: val
      END TYPE

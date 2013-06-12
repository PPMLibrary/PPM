            SUBROUTINE pointer_insert(tree_group, node, intr_ptr)
               CLASS(pointer_trees), INTENT(INOUT) :: tree_group
               CLASS(pointer_btree) :: node
               CHARACTER(LEN=32), INTENT(OUT) :: intr_ptr
               SELECT TYPE (node)
               CLASS is (derived_tree)
                  CALL insert_derived(tree_group%dtree, node)
               CLASS is (intrinsic_tree)
                  ! generate our character pointer here
                  CALL insert_intrinsic(tree_group%itree, node, &
                     tree_group%num_intrinsic)
               END SELECT
               intr_ptr = node%key
            END SUBROUTINE pointer_insert

            ! Unbalanced insert, perhaps improve later
            RECURSIVE SUBROUTINE insert_derived(tree, node)
               CLASS(derived_tree), INTENT(INOUT), POINTER :: tree
               CLASS(derived_tree), INTENT(IN), TARGET :: node
               IF (.NOT. associated(tree)) THEN
                  tree => node
                  RETURN
               END IF
               IF (LGT(node%key, tree%key)) THEN
                  CALL insert_derived(tree%right, node)
               ELSE IF (LLT(node%key, tree%key)) THEN
                  CALL insert_derived(tree%left, node)
               ENDIF
            END SUBROUTINE insert_derived

            ! char_ptr arguemnt is next generated intrinsic pointer to
            ! assign
            RECURSIVE SUBROUTINE insert_intrinsic(tree, node, base)
               CLASS(intrinsic_tree), INTENT(INOUT), POINTER :: tree
               CLASS(intrinsic_tree), INTENT(IN), TARGET :: node
               INTEGER, INTENT(INOUT) ::  base
               IF (.NOT. associated(tree)) THEN
                  tree => node
                  WRITE (tree%key, *) "internal", base
                  base = base + 1
                  RETURN
               END IF
               IF (node%hash .GT. tree%hash) THEN
                  CALL insert_intrinsic(tree%right, node, base)
               ELSE IF (node%hash .LT. tree%hash) THEN
                  CALL insert_intrinsic(tree%left, node, base)
               ! Check associativity with subfunction
               ! to add later
               ELSE IF (.NOT. check_associated(tree, node)) THEN
                  CALL insert_intrinsic(tree%left, node, base)
               !     check associated is an select typefunction to
               !     check the ptrs if they are associated
               ENDIF
            END SUBROUTINE insert_intrinsic

            LOGICAL FUNCTION check_associated(treenode, newnode)
               CLASS (intrinsic_tree) :: treenode
               CLASS (intrinsic_tree) :: newnode
               check_associated = .FALSE.
               SELECT TYPE (treenode)
               TYPE is (integer1d_tree)
                  SELECT TYPE (newnode)
                  TYPE is (integer1d_tree)
                     check_associated = associated(treenode%val, &
                        TARGET=newnode%val)
                  END SELECT
               TYPE is (integer2d_tree)
                  SELECT TYPE (newnode)
                  TYPE is (integer2d_tree)
                     check_associated = associated(treenode%val, &
                        TARGET=newnode%val)
                  END SELECT
               TYPE is (integer_tree)
                  SELECT TYPE (newnode)
                  TYPE is (integer_tree)
                     check_associated = associated(treenode%val, &
                        TARGET=newnode%val)
                  END SELECT
               END SELECT
            END FUNCTION check_associated

            !SUBROUTINE lookup(tree, char_ptr)
            !   CLASS(pointer_btree) tree
            !   CHARACTER(LEN=32) :: char_ptr
            !END SUBROUTINE


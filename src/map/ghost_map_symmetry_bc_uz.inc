  !----------------------------------------------------------
  ! (Re)allocate memory for the symmetry ghosts.
  !----------------------------------------------------------
  
  iopt   = ppm_param_alloc_grow_preserve
  ldu(1) = ppm_dim
  ldu(2) = 2*nghostplus
  CALL ppm_alloc(xt,ldu,iopt,info) 
  CALL ppm_alloc(xt_offset,ldu,iopt,info) 
  CALL ppm_alloc(xt_off_fac,ldu,iopt,info) 
  IF (info.NE.0) THEN
     info = ppm_error_fatal
     CALL ppm_error(ppm_err_alloc,'ppm_map_part_ghost_get', &
          'xt',__LINE__,info)
     GOTO 9999
  ENDIF
  
  ldu(1) = ldu(2)
  CALL ppm_alloc(ighost,ldu,iopt,info) 
  IF (info.NE.0) THEN
     info = ppm_error_fatal
     CALL ppm_error(ppm_err_alloc,'ppm_map_part_ghost_get', &
          'ighost',__LINE__,info)
     GOTO 9999
  ENDIF
  
  !-------------------------------------------------------------------
  !  clear out the new segment of xt_offset to be able to copy the
  !  correct values from the previous loop through xt_offset
  !-------------------------------------------------------------------
  FORALL(i=1:ppm_dim,j=nghostplus+1:2*nghostplus) &
  &      xt_offset(i,j) = 0.0_MK
  
  !----------------------------------------------------------
  ! Symmetry ghosts in the z-direction.
  !----------------------------------------------------------

  k = nghostplus

  !----------------------------------------------------------
  ! those at upper boundary, 
  ! even using symmetry inter-communication.
  ! No '=' in the inequality checking.
  !----------------------------------------------------------
  
  zmaxf = max_phys(3) 
  zmaxi = max_phys(3) - ghostsize
  
  DO i = 1, nghostplus
     
     IF ( xt(3,i) > zmaxi .AND. xt(3,i) < zmaxf ) THEN
        k         = k + 1
        ighost(k) = ighost(i)
        xt(1,k)   = xt(1,i)
        xt(2,k)   = xt(2,i) 
        xt(3,k)   = 2.0_MK*zmaxf - xt(3,i)
        
        xt_offset(1,k) = xt_offset(1,i)
        xt_offset(2,k) = xt_offset(2,i)
        xt_offset(3,k) = 2.0_MK*zmaxf !2.0_MK*(zmaxf-xt(3,i))
        
        xt_off_fac(1,k) = xt_off_fac(1,i)
        xt_off_fac(2,k) = xt_off_fac(2,i)
        xt_off_fac(3,k) = -1.0_MK
     END IF
  END DO
  
  !----------------------------------------------------------
  ! update the ghost counter.
  !----------------------------------------------------------
  
  nghostplus = k
  
  

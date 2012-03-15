#define WRAP(a) a


#define __FUNCNAME DTYPE(WRAP(DATANAME)_check)_
SUBROUTINE __FUNCNAME(Pc,wp,id,info) 
    IMPORT DTYPE(ppm_t_particles)_,ppm_kind_single,ppm_kind_double,&
                                    ppm_kind_int64
    CLASS(DTYPE(ppm_t_particles)_)                      :: Pc
#if   __DIM == 1
    __TYPE,DIMENSION(:),POINTER,        INTENT(IN   )   :: wp
#elif __DIM == 2
    __TYPE,DIMENSION(:,:),POINTER,      INTENT(IN   )   :: wp
#endif
    INTEGER,                            INTENT(IN   )   :: id
    !!! id where the data is stored
    INTEGER,                            INTENT(   OUT)  :: info
END SUBROUTINE
#undef __FUNCNAME
#undef __MYTYPE

#define __FUNCNAME DTYPE(WRAP(DATANAME)_get)_
#define __CHECKTYPE DTYPE(WRAP(DATANAME)_check)
SUBROUTINE __FUNCNAME(Pc,wp,ppt_id,with_ghosts)
    IMPORT DTYPE(ppm_t_particles)_, ppm_kind_single,ppm_kind_double,&
                                    ppm_kind_int64
    CLASS(DTYPE(ppm_t_particles)_)   :: Pc
    INTEGER                         :: ppt_id
#if   __DIM == 1
    __TYPE,DIMENSION(:),POINTER     :: wp
#elif __DIM == 2
    __TYPE,DIMENSION(:,:),POINTER   :: wp
#endif
    INTEGER                         :: info
END SUBROUTINE
#undef __FUNCNAME


#define __FUNCNAME DTYPE(WRAP(DATANAME)_set)_
SUBROUTINE __FUNCNAME(Pc,wp,ppt_id,read_only,ghosts_ok)
    IMPORT DTYPE(ppm_t_particles)_,ppm_kind_single,ppm_kind_double,&
                                    ppm_kind_int64
    CLASS(DTYPE(ppm_t_particles)_)    :: Pc
    INTEGER                          :: ppt_id
    LOGICAL,OPTIONAL                 :: read_only
    LOGICAL,OPTIONAL                 :: ghosts_ok
#if   __DIM == 1
    __TYPE,DIMENSION(:),POINTER      :: wp
#elif __DIM == 2
    __TYPE,DIMENSION(:,:),POINTER    :: wp
#endif
END SUBROUTINE
#undef __FUNCNAME

#undef DATANAME
#undef __TYPE

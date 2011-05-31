test_suite ppm_module_sop
#include "../../ppm_define.h"

#ifdef __MPI
    INCLUDE "mpif.h"
#endif


integer, parameter              :: debug = 0
integer, parameter              :: mk = kind(1.0d0) !kind(1.0e0)
real(mk),parameter              :: tol=epsilon(1._mk)*100
real(mk),parameter              :: pi = 3.1415926535897931_mk
real(mk),parameter              :: skin = 0._mk
integer,parameter               :: ndim=2
integer                         :: decomp,assig,tolexp
integer                         :: info,comm,rank,nproc
integer                         :: topoid,nneigh_theo
integer                         :: np_global = 10000
integer                         :: npart_g
real(mk),parameter              :: cutoff = 0.15_mk
real(mk),dimension(:,:),pointer :: xp=>NULL(),disp=>NULL()
real(mk),dimension(:  ),pointer :: min_phys,max_phys
real(mk),dimension(:  ),pointer :: len_phys
real(mk),dimension(:  ),pointer :: rcp,wp
integer                         :: i,j,k,isum1,isum2,ip,wp_id
real(mk)                        :: rsum1,rsum2
integer                         :: nstep
real(mk),dimension(:),pointer   :: delta
integer,dimension(3)            :: ldc
integer, dimension(6)           :: bcdef
real(mk),dimension(:  ),pointer :: cost
character(len=ppm_char)         :: dirname
integer                         :: isymm = 0
logical                         :: lsymm = .false.,ok
real(mk)                        :: t0,t1,t2,t3
type(ppm_t_particles),pointer   :: Particles=>NULL()
type(sop_t_opts),pointer        :: opts=>NULL()
integer                         :: seedsize
integer,  dimension(:),allocatable :: seed
integer, dimension(:),pointer   :: nvlist=>NULL()
integer, dimension(:,:),pointer :: vlist=>NULL()

    init

        use ppm_module_typedef
        use ppm_module_init
        use ppm_module_mktopo
        
        allocate(min_phys(ndim),max_phys(ndim),len_phys(ndim),&
            &         delta(ndim),stat=info)
        
        min_phys(1:ndim) = 0.0_mk
        max_phys(1:ndim) = 1.0_mk
        len_phys(1:ndim) = max_phys-min_phys
        bcdef(1:6) = ppm_param_bcdef_periodic
        
#ifdef __MPI
        comm = mpi_comm_world
        call mpi_comm_rank(comm,rank,info)
        call mpi_comm_size(comm,nproc,info)
#else
        rank = 0
        nproc = 1
#endif
        tolexp = int(log10(epsilon(1._mk)))+10
        call ppm_init(ndim,mk,tolexp,0,debug,info,99)

        call random_seed(size=seedsize)
        allocate(seed(seedsize))
        do i=1,seedsize
            seed(i)=10+i*i*(rank+1)
        enddo
        call random_seed(put=seed)

        !----------------
        ! make topology
        !----------------
        decomp = ppm_param_decomp_cuboid
        !decomp = ppm_param_decomp_xpencil
        assig  = ppm_param_assign_internal

        topoid = 0

        call ppm_mktopo(topoid,decomp,assig,min_phys,max_phys,bcdef,cutoff,cost,info)
    end init


    finalize
        use ppm_module_finalize

        call ppm_finalize(info)

        deallocate(min_phys,max_phys,len_phys,delta)

    end finalize


    setup


    end setup
        

    teardown
        
        call ppm_alloc_particles(Particles,np_global,ppm_param_dealloc,info)

    end teardown

    test adapt_particles
        ! test particle adaptation

        use ppm_module_typedef
        use ppm_module_topo_check

        call particles_initialize(Particles,np_global,info,ppm_param_part_init_cartesian,topoid)
        call particles_mapping_global(Particles,topoid,info)
        Assert_Equal(info,0)

        allocate(disp(ndim,Particles%Npart),stat=info)
        call random_number(disp)
        xp => get_xp(Particles)
        FORALL(ip=1:Particles%Npart) xp(1:ndim,ip) = xp(1:ndim,ip) + 0.0001_mk*disp(1:ndim,ip)
        xp => set_xp(Particles)
        call particles_apply_bc(Particles,topoid,info)
        Assert_Equal(info,0)
        call particles_mapping_partial(Particles,topoid,info)
        Assert_Equal(info,0)

        call particles_allocate_wps(Particles,Particles%rcp_id,info,with_ghosts=.true.)
        Assert_Equal(info,0)
        wp_id = 0
        call particles_allocate_wps(Particles,wp_id,info,zero=.true.)
        Assert_Equal(info,0)

        xp => get_xp(Particles)
        wp => get_wps(Particles,wp_id)
        rcp => get_wps(Particles,Particles%rcp_id)
        Assert_True(associated(xp))
        FORALL(ip=1:Particles%Npart) 
            wp(ip) = f0_fun(xp(1:ndim,ip)) 
            rcp(ip) = 1.9_mk*Particles%h_avg
        END FORALL
        xp => set_xp(Particles,read_only=.true.)
        rcp => set_wps(Particles,Particles%rcp_id)
        wp => set_wps(Particles,wp_id)

        call particles_updated_cutoff(Particles,info)
        Assert_Equal(info,0)
        call particles_mapping_ghosts(Particles,topoid,info)
        Assert_True(info.eq.0)
        call particles_neighlists(Particles,topoid,info)
        Assert_True(info.eq.0)

        call sop_init_opts(opts,info)
        Assert_Equal(info,0)

        opts%scale_D = 1._mk
        opts%minimum_D = 0.01_mk
        opts%maximum_D = 0.05_mk
        opts%adaptivity_criterion = 6._mk
        opts%fuse_radius = 0.2_mk
        opts%attractive_radius0 = 0.4_mk
        call sop_adapt_particles(topoid,Particles,D_fun,opts,info,&
            D_needs_gradients=.true.,wp_fun=f0_fun,wp_grad_fun=f0_grad_fun)
        Assert_Equal(info,0)

        write(dirname,*) './'
        call particles_io_xyz(Particles,0,dirname,info)
        Assert_Equal(info,0)

    end test

pure function f0_fun(pos)

    use ppm_module_data, ONLY: ppm_dim
    real(mk)                                 :: f0_fun
    real(mk), dimension(ppm_dim), intent(in) :: pos
    real(mk), dimension(ppm_dim)             :: centre
    real(mk)                                 :: radius,eps

    centre = 0.5_mk
    centre(2) = 0.75_mk
    radius=0.15_mk
    eps = 0.05_mk

    f0_fun = tanh((sqrt(sum((pos(1:ppm_dim)-centre)**2)) - radius)/eps)

end function f0_fun

pure function f0_grad_fun(pos)

    use ppm_module_data, ONLY: ppm_dim
    real(mk), dimension(ppm_dim)             :: f0_grad_fun
    real(mk), dimension(ppm_dim), intent(in) :: pos
    real(mk), dimension(ppm_dim)             :: centre
    real(mk)                                 :: radius,eps,f0,d

    centre = 0.5_mk
    centre(2) = 0.75_mk
    radius=0.15_mk
    eps = 0.05_mk

    d = sqrt(sum(pos(1:ppm_dim)-centre)**2)
    f0 = tanh((d - radius)/eps)
    f0_grad_fun = (1._mk - f0**2) * (pos(1:ppm_dim)-centre)/(eps*d)

end function f0_grad_fun

pure function level0_fun(pos)

    real(mk)                              :: level0_fun
    real(mk), dimension(ndim), intent(in) :: pos
    real(mk), dimension(ndim)             :: centre
    real(mk)                              :: radius

    centre = 0.5_mk
    centre(2) = 0.75_mk
    radius=0.15_mk

    level0_fun = sqrt(sum((pos(1:ppm_dim)-centre)**2)) - radius

end function level0_fun

pure function D_fun(wp,wp_grad,opts,level)
    real(mk)                               :: D_fun
    real(mk),                   intent(in) :: wp
    real(mk),dimension(ppm_dim),intent(in) :: wp_grad
    type(sop_t_opts),pointer,   intent(in) :: opts
    real(mk), optional,         intent(in) :: level
    real(mk)                               :: lengthscale

    D_fun =  opts%scale_d / sqrt(1._mk + SUM(wp_grad**2))

end function D_fun


end test_suite

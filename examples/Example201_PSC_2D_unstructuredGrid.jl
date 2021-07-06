#=
# 108: 1D PSC p-i-n device on 2D domain (unstructured grid).
([source code](SOURCE_URL))

Simulating a three layer PSC device Pedot| MAPI | PCBM with mobile ions 
where the ion vacancy accumulation is limited by the Fermi-Dirac integral of order -1.
The simulations are performed in 2D on an unstructured grid, out of equilibrium and with
abrupt interfaces. A linear I-V measurement protocol is included and the corresponding
solution vectors after the scan protocol can be depicted.

The paramters can be found here and are from
Calado et al.:
https://github.com/barnesgroupICL/Driftfusion/blob/master/Input_files/pedotpss_mapi_pcbm.csv.
(with adjustments on layer lengths)
=#

ENV["LC_NUMERIC"]="C" # put this in to work with Triangulate.jl, where the package is originally written in c++

module Example201_PSC_2D_unstructuredGrid

using VoronoiFVM
using ChargeTransportInSolids
using ExtendableGrids
using GridVisualize

# For using this example one additionally needs to add Triangulate. SimplexGridFactory is a wrapper for using this meshgenerator.
# using SimplexGridFactory
# using Triangulate


# problem with linux, when including PyPlot not until the end: "ERROR: LoadError: InitError: could not load library "/home/abdel/.julia/artifacts/8cc532f6a1ace8d1b756fc413f4ab340195ec3c3/lib/libgio-2.0.so"/home/abdel/.julia/artifacts/8cc532f6a1ace8d1b756fc413f4ab340195ec3c3/lib/libgobject-2.0.so.0: undefined symbol: g_uri_ref"
# It seems that this problem is common: https://discourse.julialang.org/t/could-not-load-library-librsvg-very-strange-error/21276


function main(Plotter = nothing, ;plotting = false, verbose = false, test = false, unknown_storage=:dense)

    ################################################################################
    if test == false
        println("Set up grid and regions")
    end
    ################################################################################

    # region numbers
    regionAcceptor          = 1                           # p doped region
    regionIntrinsic         = 2                           # intrinsic region
    regionDonor             = 3                           # n doped region
    regions                 = [regionAcceptor, regionIntrinsic, regionDonor]
    numberOfRegions         = length(regions)

    # boundary region numbers
    bregionAcceptor         = 1
    bregionDonor            = 2
    bregionJunction1        = 3
    bregionJunction2        = 4
    bregionNoFlux           = 5
    bregions                = [bregionAcceptor, bregionDonor, bregionJunction1, bregionJunction2, bregionNoFlux]
    numberOfBoundaryRegions = length(bregions)

    # grid
    h_pdoping       = 3.00e-6 * cm + 1.0e-7 *cm
    h_intrinsic     = 3.00e-5 * cm 
    h_ndoping       = 8.50e-6 * cm + 1.0e-7 *cm
    height          = 1.00e-5 * cm

    b               = SimplexGridBuilder(Generator=Triangulate)
    
    # specify boundary nodes
    length_0        = point!(b, 0.0, 0.0)
    length_p        = point!(b, h_pdoping, 0.0)
    length_pi       = point!(b, h_pdoping + h_intrinsic, 0.0)
    length_pin      = point!(b, h_pdoping + h_intrinsic + h_ndoping, 0.0)
            
    height_0        = point!(b, 0.0, height)
    height_p        = point!(b, h_pdoping, height)
    height_pi       = point!(b, h_pdoping + h_intrinsic, height)
    height_pin      = point!(b, h_pdoping + h_intrinsic + h_ndoping, height)
        
    # specify boundary regions
    # metal interface
    facetregion!(b, bregionAcceptor)
    facet!(b, length_0, height_0)
    facetregion!(b, bregionDonor)
    facet!(b, length_pin, height_pin)
            
    # no flux
    facetregion!(b, bregionNoFlux)
    facet!(b, length_0, length_pin)
    facetregion!(b, bregionNoFlux)
    facet!(b, height_0, height_pin)
    
    # inner interface
    facetregion!(b, bregionJunction1)
    facet!(b, length_p, height_p)
    facetregion!(b, bregionJunction2)
    facet!(b, length_pi, height_pi)

    # cell regions
    cellregion!(b, regionAcceptor)
	regionpoint!(b, h_pdoping/2, height/2) 
    cellregion!(b,regionIntrinsic)
	regionpoint!(b, (h_pdoping + h_intrinsic)/2, height/2) 
    cellregion!(b,regionDonor)
	regionpoint!(b, h_pdoping + h_intrinsic + h_ndoping/2, height/2) 

    options!(b,maxvolume=1.0e-16)

    grid           = simplexgrid(b;maxvolume=1.0e-16)
    numberOfNodes  = size(grid[Coordinates])[2]

    if plotting
        GridVisualize.gridplot(grid, Plotter= Plotter, resolution=(600,400),linewidth=0.5, legend=:lt)
        Plotter.title("Grid")
        Plotter.figure()
    end
 
    if test == false
        println("*** done\n")
    end
    ################################################################################
    if test == false
        println("Define physical parameters and model")
    end
    ################################################################################

    # indices 
    numberOfCarriers = 3 # iphin, iphip, ipsi

    # temperature
    T                =  300.0                 *  K

    # band edge energies    
    Eref             =  0.0        # reference energy 

    Ec_a             = -3.0                  *  eV 
    Ev_a             = -5.1                  *  eV 

    Ec_i             = -3.8                  *  eV 
    Ev_i             = -5.4                  *  eV 

    Ec_d             = -3.8                  *  eV 
    Ev_d             = -6.2                  *  eV 

    EC               = [Ec_a, Ec_i, Ec_d] 
    EV               = [Ev_a, Ev_i, Ev_d]
    

    # effective densities of state
    Nc_a             = 1.0e20                / (cm^3)
    Nv_a             = 1.0e20                / (cm^3)

    Nc_i             = 1.0e19                / (cm^3)
    Nv_i             = 1.0e19                / (cm^3)

    ###################### adjust Na, Ea here #####################
    Nanion           = 1.0e18                / (cm^3)
    Ea_i             = -4.4                  *  eV 
    # for the labels in the figures
    textEa           = Ea_i./eV
    textNa           = Nanion.*cm^3
    ###################### adjust Na, Ea here #####################
    EA               = [0.0,  Ea_i,  0.0]

    Nc_d             = 1.0e19                / (cm^3)
    Nv_d             = 1.0e19                / (cm^3)

    NC               = [Nc_a, Nc_i, Nc_d]
    NV               = [Nv_a, Nv_i, Nv_d]
    NAnion           = [0.0,  Nanion, 0.0]

    # mobilities 
    μn_a             = 0.1                   * (cm^2) / (V * s)  
    μp_a             = 0.1                   * (cm^2) / (V * s)  

    μn_i             = 2.00e1                * (cm^2) / (V * s)  
    μp_i             = 2.00e1                * (cm^2) / (V * s)
    μa_i             = 1.00e-10              * (cm^2) / (V * s)

    μn_d             = 1.0e-3                * (cm^2) / (V * s) 
    μp_d             = 1.0e-3                * (cm^2) / (V * s) 

    μn               = [μn_a, μn_i, μn_d] 
    μp               = [μp_a, μp_i, μp_d] 
    μa               = [0.0,  μa_i, 0.0 ] 

    # relative dielectric permittivity  

    ε_a              = 4.0                   *  1.0  
    ε_i              = 23.0                  *  1.0 
    ε_d              = 3.0                   *  1.0 

    ε               = [ε_a, ε_i, ε_d] 

    # recombination model
    bulk_recombination  = bulk_recombination_full

    # radiative recombination
    r0_a            = 6.3e-11               * cm^3 / s 
    r0_i            = 3.6e-12               * cm^3 / s  
    r0_d            = 6.8e-11               * cm^3 / s
        
    r0              = [r0_a, r0_i, r0_d]
        
    # life times and trap densities 
    τn_a            = 1.0e-6              * s 
    τp_a            = 1.0e-6              * s
        
    τn_i            = 1.0e-7              * s
    τp_i            = 1.0e-7              * s
    τn_d            = τn_a
    τp_d            = τp_a
        
    τn              = [τn_a, τn_i, τn_d]
    τp              = [τp_a, τp_i, τp_d]
        
    # SRH trap energies (needed for calculation of recombinationSRHTrapDensity)
    Ei_a            = -4.05              * eV   
    Ei_i            = -4.60              * eV   
    Ei_d            = -5.00              * eV   

    EI              = [Ei_a, Ei_i, Ei_d]
        
    # Auger recombination
    Auger           = 0.0

    # doping (doping values are from Phils paper, not stated in the parameter list online)
    Nd              =   2.089649130192123e17 / (cm^3) 
    Na              =   4.529587947185444e18 / (cm^3) 
    C0              =   1.0e18               / (cm^3) 

    # contact voltages: we impose an applied voltage only on one boundary.
    # At the other boundary the applied voltage is zero.
    voltageAcceptor =  1.0                  * V 

    # interface model (this is needed for giving the user the correct index set)
    interface_reaction  = interface_model_none

    # set the correct indices for each species (this is needed for giving the user the correct index set)
    # but likewise it is possible to define one owns index set, i.e. iphin, iphin, iphia, ipsi = 1:4
    indexSet            = set_indices!(grid, numberOfCarriers, interface_reaction)

    iphin               = indexSet["iphin"]
    iphip               = indexSet["iphip"]
    iphia               = indexSet["iphia"]
    ipsi                = indexSet["ipsi" ]

    if test == false
        println("*** done\n")
    end

    ################################################################################
    if test == false
        println("Define ChargeTransportSystem and fill in information about model")
    end
    ################################################################################

    # initialize ChargeTransportData instance and fill in data
    data                                = ChargeTransportData(grid, numberOfCarriers)

    #### declare here all necessary information concerning the model ###

    # Following variable declares, if we want to solve stationary or transient problem
    data.model_type                     = model_transient

    # Following choices are possible for F: Boltzmann, FermiDiracOneHalfBednarczyk, FermiDiracOneHalfTeSCA FermiDiracMinusOne, Blakemore
    data.F                              = [Boltzmann, Boltzmann, FermiDiracMinusOne]

    # Following choices are possible for recombination model: bulk_recombination_model_none, bulk_recombination_model_trap_assisted, bulk_recombination_radiative, bulk_recombination_full <: bulk_recombination_model 
    data.bulk_recombination_model       = bulk_recombination

    # Following choices are possible for boundary model: For contacts currently only ohmic_contact and schottky_contact are possible.
    # For inner boundaries we have interface_model_none, interface_model_surface_recombination, interface_model_ion_charge
    # (distinguish between left and right).
    data.boundary_type[bregionAcceptor] = ohmic_contact                       
    data.boundary_type[bregionDonor]    = ohmic_contact   
    
    # Following choices are possible for the flux_discretization scheme: ScharfetterGummel, ScharfetterGummel_Graded,
    # excessChemicalPotential, excessChemicalPotential_Graded, diffusionEnhanced, generalized_SG
    data.flux_approximation             = excessChemicalPotential

    if test == false
        println("*** done\n")
    end

    ################################################################################
    if test == false
        println("Define ChargeTransportParams and fill in physical parameters")
    end
    ################################################################################

    params                                              = ChargeTransportParams(grid, numberOfCarriers)

    params.temperature                                  = T
    params.UT                                           = (kB * params.temperature) / q
    params.chargeNumbers[iphin]                         = -1
    params.chargeNumbers[iphip]                         =  1
    params.chargeNumbers[iphia]                         =  1
    
    # boundary region data
    params.bDensityOfStates[iphin, bregionDonor]        = Nc_d
    params.bDensityOfStates[iphip, bregionDonor]        = Nv_d

    params.bDensityOfStates[iphin, bregionAcceptor]     = Nc_a
    params.bDensityOfStates[iphip, bregionAcceptor]     = Nv_a

    params.bBandEdgeEnergy[iphin, bregionDonor]         = Ec_d
    params.bBandEdgeEnergy[iphip, bregionDonor]         = Ev_d

    params.bBandEdgeEnergy[iphin, bregionAcceptor]      = Ec_a
    params.bBandEdgeEnergy[iphip, bregionAcceptor]      = Ev_a


  
    for ireg in 1:numberOfRegions # interior region data

        params.dielectricConstant[ireg]                 = ε[ireg]

        # effective DOS, band edge energy and mobilities
        params.densityOfStates[iphin, ireg]             = NC[ireg]
        params.densityOfStates[iphip, ireg]             = NV[ireg]
        params.densityOfStates[iphia, ireg]             = NAnion[ireg]

        params.bandEdgeEnergy[iphin, ireg]              = EC[ireg]
        params.bandEdgeEnergy[iphip, ireg]              = EV[ireg]
        params.bandEdgeEnergy[iphia, ireg]              = EA[ireg]

        params.mobility[iphin, ireg]                    = μn[ireg]
        params.mobility[iphip, ireg]                    = μp[ireg]
        params.mobility[iphia, ireg]                    = μa[ireg]

        # recombination parameters
        params.recombinationRadiative[ireg]             = r0[ireg]
        params.recombinationSRHLifetime[iphin, ireg]    = τn[ireg]
        params.recombinationSRHLifetime[iphip, ireg]    = τp[ireg]
        params.recombinationSRHTrapDensity[iphin, ireg] = trap_density!(iphin, ireg, data, EI[ireg])
        params.recombinationSRHTrapDensity[iphip, ireg] = trap_density!(iphip, ireg, data, EI[ireg])
        params.recombinationAuger[iphin, ireg]          = Auger
        params.recombinationAuger[iphip, ireg]          = Auger

    end

    # interior doping
    params.doping[iphin, regionDonor]                   = Nd
    params.doping[iphia, regionIntrinsic]               = C0
    params.doping[iphip, regionAcceptor]                = Na  

    # boundary doping
    params.bDoping[iphip, bregionAcceptor]              = Na      
    params.bDoping[iphin, bregionDonor]                 = Nd 

    # Region dependent params is now a substruct of data which is again a substruct of the system and will be parsed 
    # in next step.
    data.params                                         = params

    # in the last step, we initialize our system with previous data which is likewise dependent on the parameters. 
    # important that this is in the end, otherwise our VoronoiFVMSys is not dependent on the data we initialized
    # but rather on default data.
    ctsys                                               = ChargeTransportSystem(grid, data, unknown_storage=unknown_storage)

    # print data
    if test == false
        println(ctsys.data.params)
        println("*** done\n")
    end
    
    ################################################################################
    if test == false
        println("Define outerior boundary conditions and enabled layers")
    end
    ################################################################################

    # set ohmic contacts for each charge carrier at all outerior boundaries. First, 
    # we compute equilibrium solutions. Hence the boundary values at the ohmic contacts
    # are zero.
    set_ohmic_contact!(ctsys, iphin, bregionAcceptor, 0.0)
    set_ohmic_contact!(ctsys, iphip, bregionAcceptor, 0.0)
    set_ohmic_contact!(ctsys, iphin, bregionDonor, 0.0)
    set_ohmic_contact!(ctsys, iphip, bregionDonor, 0.0)

    # enable all three species in all regions
    # entweder ct_enable_species! oder ChargeTransportInSolids.enable_species!
    ct_enable_species!(ctsys, ipsi,  regions)
    ct_enable_species!(ctsys, iphin, regions)
    ct_enable_species!(ctsys, iphip, regions)
    ct_enable_species!(ctsys, iphia, [regionIntrinsic]) # ions restricted to active layer

    if test == false
        println("*** done\n")
    end

    ################################################################################
    if test == false
        println("Define control parameters for Newton solver")
    end
    ################################################################################

    control                   = VoronoiFVM.NewtonControl()
    control.verbose           = verbose
    control.max_iterations    = 300
    control.tol_absolute      = 1.0e-10
    control.tol_relative      = 1.0e-10
    control.handle_exceptions = true
    control.tol_round         = 1.0e-10
    control.max_round         = 5

    if test == false
        println("*** done\n")
    end

    ################################################################################
    if test == false
        println("Compute solution in thermodynamic equilibrium for Boltzmann")
    end
    ################################################################################

    ctsys.data.calculation_type    = inEquilibrium

    # initialize solution and starting vectors
    initialGuess                   = ct_unknowns(ctsys)
    solution                       = ct_unknowns(ctsys)
    @views initialGuess           .= 0.0

    # we slightly turn a linear Poisson problem to a nonlinear one with these variables.
    I      = collect(20.0:-1:0.0)
    LAMBDA = 10 .^ (-I) 
    prepend!(LAMBDA, 0.0)

    for i in 1:length(LAMBDA)
        if test == false
            println("λ1 = $(LAMBDA[i])")
        end
        ctsys.fvmsys.physics.data.λ1 = LAMBDA[i]     # DA: das hier ist noch unschön und müssen wir extrahieren!!!!!

        ct_solve!(solution, initialGuess, ctsys, control = control, tstep=Inf)

        initialGuess .= solution
    end

    if plotting # currently, plotting the solution was only tested with PyPlot.
        
        X = grid[Coordinates][1,:]
        Y = grid[Coordinates][2,:]

        Plotter.figure()
        Plotter.surf(X[:], Y[:], solution[ipsi, :])
        Plotter.title("Electrostatic potential \$ \\psi \$ in Equilibrium")
        Plotter.xlabel("length [m]")
        Plotter.ylabel("height [m]")
        Plotter.zlabel("potential [V]")
        Plotter.tight_layout()
        ################
        Plotter.figure()
        Plotter.surf(X[:], Y[:], solution[iphin,:] )
        Plotter.title("quasi Fermi potential \$ \\varphi_n \$ in Equilibrium")
        Plotter.xlabel("length [m]")
        Plotter.ylabel("height [m]")
        Plotter.zlabel("potential [V]")
        Plotter.tight_layout() 
    end

    if test == false
        println("*** done\n")
    end

    ################################################################################
    if test == false
        println("I-V Measurement Loop")
    end
    ################################################################################
    ctsys.data.calculation_type  = outOfEquilibrium

    # control.damp_initial      = 0.1
    # control.damp_growth       = 1.21 # >= 1
    # control.max_round         = 5


    # there are different way to control timestepping
    # Here we assume these primary data
    scanrate                     = 0.04 * V/s
    ntsteps                      = 41
    vend                         = voltageAcceptor # bias goes until the given contactVoltage at acceptor boundary
    v0                           = 0.0

    # The end time then is calculated here:
    tend                         = vend/scanrate

    # with fixed timestep sizes we can calculate the times
    # a priori
    tvalues                      = range(0, stop = tend, length = ntsteps)

    IV                           = zeros(0) # for IV values
    biasValues                   = zeros(0) # for bias values

    for istep = 2:length(tvalues)
        
        t                     = tvalues[istep] # Actual time
        Δu                    = v0 + t*scanrate # Applied voltage 
        Δt                    = t - tvalues[istep-1] # Time step size
        
        # Apply new voltage
        # set non equilibrium boundary conditions
        set_ohmic_contact!(ctsys, iphin, bregionAcceptor, Δu)
        set_ohmic_contact!(ctsys, iphip, bregionAcceptor, Δu)
        
        if test == false
            println("time value: t = $(t)")
        end

        # Solve time step problems with timestep Δt. initialGuess plays the role of the solution
        # from last timestep
        ct_solve!(solution, initialGuess, ctsys, control  = control, tstep = Δt)

        # get IV curve
        factory = VoronoiFVM.TestFunctionFactory(ctsys.fvmsys)

        # testfunction zero in bregionAcceptor and one in bregionDonor
        tf1     = testfunction(factory, [bregionDonor], [bregionAcceptor])
        I1      = integrate(ctsys.fvmsys, tf1, solution, initialGuess, Δt)

        currentI1 = (I1[ipsi] + I1[iphin] + I1[iphip] + I1[iphia] )

        push!(IV,  currentI1 )
        push!(biasValues, Δu)

        initialGuess .= solution
    end # time loop

    testval = solution[ipsi, 42]
    return testval

    if plotting
        Plotter.figure()
        Plotter.surf(X[:], Y[:], solution[ipsi, :])
        Plotter.title("Electrostatic potential \$ \\psi \$ at end time")
        Plotter.xlabel("length [m]")
        Plotter.ylabel("height [m]")
        Plotter.zlabel("potential [V]")
        ################
        Plotter.figure()
        Plotter.surf(X[:], Y[:], solution[iphin,:] )
        Plotter.title("quasi Fermi potential \$ \\varphi_n \$ at end time")
        Plotter.xlabel("length [m]")
        Plotter.ylabel("height [m]")
        Plotter.zlabel("potential [V]")
        ################
        Plotter.figure()
        Plotter.plot(biasValues, IV.*(cm)^2/height, label = "\$ E_a =\$$(textEa)eV;  \$ N_a =\$ $textNa\$\\mathrm{cm}^{⁻3}\$ (without internal BC)",  linewidth= 3, linestyle="--", color="red")
        Plotter.title("Forward; \$ E_a =\$$(textEa)eV;  \$ N_a =\$ $textNa\$\\mathrm{cm}^{⁻3}\$ ")
        Plotter.ylabel("total current [A]") # 
        Plotter.xlabel("Applied Voltage [V]")
    end

end #  main

function test()
    testval = -4.0688862213372134
    main(test = true, unknown_storage=:dense) ≈ testval #&& main(test = true, unknown_storage=:sparse) ≈ testval
end

if test == false
    println("This message should show when this module is successfully recompiled.")
end

end # module
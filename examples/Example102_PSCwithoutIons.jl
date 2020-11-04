"""
Simulating a three layer PSC device without mobile ions.
The simulations are performed in equilibrium.

This simulation coincides with the one made in Section 4.3
of Calado et al. (https://arxiv.org/abs/2009.04384).
The paramters can be found here:
https://github.com/barnesgroupICL/Driftfusion/blob/Methods-IonMonger-comparison/Input_files/IonMonger_default_noIR.csv.

"""

module Example102_PSCwithoutIons

using VoronoiFVM
using ChargeTransportInSolids
using ExtendableGrids
using PyPlot; PyPlot.pygui(true)
using Printf


function main(;n = 8, pyplot = false, verbose = false, test = false, unknown_storage=:sparse)

    # close all windows
    PyPlot.close("all")

    ################################################################################
    println("Set up grid and regions")
    ################################################################################

    # region numbers
    regionDonor     = 1                           # n doped region
    regionIntrinsic = 2                           # intrinsic region
    regionAcceptor  = 3                           # p doped region
    regions         = [regionDonor, regionIntrinsic, regionAcceptor]

    # boundary region numbers
    bregionDonor    = 1
    bregionAcceptor = 2
    bregions        = [bregionAcceptor, bregionDonor]

    # grid
    # NB: Using geomspace to create uniform mesh is not a good idea. It may create virtual duplicates at boundaries.
    h_ndoping       = 9.90e-6 * cm 
    h_intrinsic     = 4.00e-5 * cm + 2.0e-7 * cm # add 2.e-7 cm to this layer for agreement with grid of Driftfusion
    h_pdoping       = 1.99e-5 * cm

    x0              = 0.0 * cm 
    δ               = 2*n        # the larger, the finer the mesh
    t               = 0.5*(cm)/δ # tolerance for geomspace and glue (with factor 10)
    k               = 1.5        # the closer to 1, the closer to the boundary geomspace works

    coord_n_u       = collect(range(x0, h_ndoping/2, step=h_ndoping/(0.8*δ)))
    coord_n_g       = geomspace(h_ndoping/2, 
                                h_ndoping, 
                                h_ndoping/(1.1*δ), 
                                h_ndoping/(1.1*δ), 
                                tol=t)
    coord_i_g1      = geomspace(h_ndoping, 
                                h_ndoping+h_intrinsic/k, 
                                h_intrinsic/(2.8*δ), 
                                h_intrinsic/(2.8*δ), 
                                tol=t)
    coord_i_g2      = geomspace(h_ndoping+h_intrinsic/k, 
                                h_ndoping+h_intrinsic,               
                                h_intrinsic/(2.8*δ),    
                                h_intrinsic/(2.8*δ), 
                                tol=t)
    coord_p_g       = geomspace(h_ndoping+h_intrinsic,               
                                h_ndoping+h_intrinsic+h_pdoping/2, 
                                h_pdoping/(1.6*δ),   
                                h_pdoping/(1.6*δ),      
                                tol=t)
    coord_p_u       = collect(range(h_ndoping+h_intrinsic+h_pdoping/2, h_ndoping+h_intrinsic+h_pdoping, step=h_pdoping/(1.3*δ)))

    coord           = glue(coord_n_u,coord_n_g,  tol=10*t) 
    length_pcoord = length(coord)
    coord           = glue(coord,    coord_i_g1, tol=10*t)
    coord           = glue(coord,    coord_i_g2, tol=10*t) 
    coord           = glue(coord,    coord_p_g,  tol=10*t)
    coord           = glue(coord,    coord_p_u,  tol=10*t)
    grid            = ExtendableGrids.simplexgrid(coord)
    numberOfNodes   = length(coord)

    # set different regions in grid, doping profiles do not intersect
    cellmask!(grid, [0.0 * μm],                [h_ndoping],                           regionDonor)     # n-doped region   = 1
    cellmask!(grid, [h_ndoping],               [h_ndoping + h_intrinsic],             regionIntrinsic) # intrinsic region = 2
    cellmask!(grid, [h_ndoping + h_intrinsic], [h_ndoping + h_intrinsic + h_pdoping], regionAcceptor)  # p-doped region   = 3

    if pyplot
        ExtendableGrids.plot(grid, Plotter = PyPlot, p = PyPlot.plot()) 
        PyPlot.title("Grid")
        PyPlot.figure()
    end
    println("*** done\n")

    ################################################################################
    println("Define physical parameters and model")
    ################################################################################

    # indices
    iphin, iphip, ipsi      = 1:3
    species                 = [iphin, iphip, ipsi]

    # number of (boundary) regions and carriers
    numberOfRegions         = length(regions)
    numberOfBoundaryRegions = length(bregions) #+ length(iregions)
    numberOfSpecies         = length(species)

    # temperature
    T               = 300.0                 *  K

    # band edge energies    
    Eref            =  0.0        # reference energy 

    Ec_d            = -4.0                  *  eV 
    Ev_d            = -6.0                  *  eV 

    Ec_i            = -3.7                  *  eV 
    Ev_i            = -5.4                  *  eV 

    Ec_a            = -3.1                  *  eV 
    Ev_a            = -5.1                  *  eV 

    EC              = [Ec_d, Ec_i, Ec_a] 
    EV              = [Ev_d, Ev_i, Ev_a] 

    # effective densities of state
    Nc_d            = 5.0e19                / (cm^3)
    Nv_d            = 5.0e19                / (cm^3)

    Nc_i            = 8.1e18                / (cm^3)
    Nv_i            = 5.8e18                / (cm^3)

    Nc_a            = 5.0e19                / (cm^3)
    Nv_a            = 5.0e19                / (cm^3)

    NC              = [Nc_d, Nc_i, Nc_a]
    NV              = [Nv_d, Nv_i, Nv_a]

    # mobilities 
    μn_d            = 3.89                  * (cm^2) / (V * s)  
    μp_d            = 3.89                  * (cm^2) / (V * s)  

    μn_i            = 6.62e1                * (cm^2) / (V * s)  
    μp_i            = 6.62e1                * (cm^2) / (V * s)

    μn_a            = 3.89e-1               * (cm^2) / (V * s) 
    μp_a            = 3.89e-1               * (cm^2) / (V * s) 

    μn              = [μn_d, μn_i, μn_a] 
    μp              = [μp_d, μp_i, μp_a] 

    # relative dielectric permittivity  

    ε_d             = 10.0                  *  1.0  
    ε_i             = 24.1                  *  1.0 
    ε_a             = 3.0                   *  1.0 

    ε               = [ε_d, ε_i, ε_a] 

    # recombination model
    recombinationOn = false

    # doping (doping values are from Phils paper, not stated in the parameter list online)
    Nd              =   1.03e18             / (cm^3) 
    Na              =   1.03e18             / (cm^3) 
    Ni_acceptor     =   8.32e7              / (cm^3) 

    # contact voltages
    voltageAcceptor =  1.05                 * V 
    voltageDonor    =  0.0                  * V 


    println("*** done\n")

    ################################################################################
    println("Define ChargeTransport data and fill in previously defined data")
    ################################################################################

    # initialize ChargeTransport instance
    data      = ChargeTransportInSolids.ChargeTransportData(numberOfNodes, numberOfRegions, numberOfBoundaryRegions, numberOfSpecies)

    # region independent data
    data.F                              .= Boltzmann # Boltzmann, FermiDiracOneHalf, Blakemore
    data.temperature                     = T
    data.UT                              = (kB * data.temperature) / q
    data.contactVoltage[bregionAcceptor] = voltageAcceptor
    data.contactVoltage[bregionDonor]    = voltageDonor
    data.chargeNumbers[iphin]            = -1
    data.chargeNumbers[iphip]            =  1
    data.Eref                            =  Eref

    data.recombinationOn                 = recombinationOn

    # boundary region data
    data.bDensityOfStates[bregionDonor,iphin] = Nc_d
    data.bDensityOfStates[bregionDonor,iphip] = Nv_d

    data.bDensityOfStates[bregionAcceptor,iphin] = Nc_a
    data.bDensityOfStates[bregionAcceptor,iphip] = Nv_a

    data.bBandEdgeEnergy[bregionDonor,iphin]     = Ec_d + data.Eref
    data.bBandEdgeEnergy[bregionDonor,iphip]     = Ev_d + data.Eref

    data.bBandEdgeEnergy[bregionAcceptor,iphin]  = Ec_a + data.Eref
    data.bBandEdgeEnergy[bregionAcceptor,iphip]  = Ev_a + data.Eref

    # interior region data
    for ireg in 1:numberOfRegions

        data.dielectricConstant[ireg]    = ε[ireg]

        # dos, band edge energy and mobilities
        data.densityOfStates[ireg,iphin] = NC[ireg]
        data.densityOfStates[ireg,iphip] = NV[ireg]

        data.bandEdgeEnergy[ireg,iphin]  = EC[ireg] + data.Eref
        data.bandEdgeEnergy[ireg,iphip]  = EV[ireg] + data.Eref

        data.mobility[ireg,iphin]        = μn[ireg]
        data.mobility[ireg,iphip]        = μp[ireg]
    end

    # interior doping
    data.doping[regionDonor,iphin]      = Nd

    data.doping[regionIntrinsic,iphin]  = 0.0
    data.doping[regionIntrinsic,iphip]  = Ni_acceptor    

    data.doping[regionAcceptor,iphip]   = Na     
                             
    # boundary doping
    data.bDoping[bregionAcceptor,iphip] = Na        # data.bDoping  = [Na  0.0;
    data.bDoping[bregionDonor,iphin]    = Nd        #                  0.0  Nd]

    # print data
    if test == false
        println(data)
    end
    println("*** done\n")
    ################################################################################
    println("Define physics and system")
    ################################################################################

    ## initializing physics environment ##
    physics = VoronoiFVM.Physics(
    data        = data,
    num_species = numberOfSpecies,
    flux        = ChargeTransportInSolids.ScharfetterGummel!, #Sedan!, ScharfetterGummel!, diffusionEnhanced!, KopruckiGaertner!
    reaction    = ChargeTransportInSolids.reaction!,
    breaction   = ChargeTransportInSolids.breaction!
    )

    sys         = VoronoiFVM.System(grid,physics,unknown_storage=unknown_storage)

    # enable all three species in all regions
    enable_species!(sys, ipsi,  regions)
    enable_species!(sys, iphin, regions)
    enable_species!(sys, iphip, regions)

    println("*** done\n")
    sys.boundary_values[iphin,  bregionAcceptor] = data.contactVoltage[bregionAcceptor]
    sys.boundary_factors[iphin, bregionAcceptor] = VoronoiFVM.Dirichlet

    sys.boundary_values[iphin,  bregionDonor]    = data.contactVoltage[bregionDonor]
    sys.boundary_factors[iphin, bregionDonor]    = VoronoiFVM.Dirichlet

    sys.boundary_values[iphip,  bregionAcceptor] = data.contactVoltage[bregionAcceptor]
    sys.boundary_factors[iphip, bregionAcceptor] = VoronoiFVM.Dirichlet

    sys.boundary_values[iphip,  bregionDonor]    = data.contactVoltage[bregionDonor]
    sys.boundary_factors[iphip, bregionDonor]    = VoronoiFVM.Dirichlet

    ################################################################################
    println("Define control parameters for Newton solver")
    ################################################################################

    control                   = VoronoiFVM.NewtonControl()
    control.verbose           = verbose
    control.max_iterations    = 300
    control.tol_absolute      = 1.0e-13
    control.tol_relative      = 1.0e-13
    control.handle_exceptions = true
    control.tol_round         = 1.0e-13
    control.max_round         = 5

    println("*** done\n")

    ################################################################################
    println("Compute solution in thermodynamic equilibrium for Boltzmann")
    ################################################################################

    data.inEquilibrium = true

    # initialize solution and starting vectors
    initialGuess                   = unknowns(sys)
    solution                       = unknowns(sys)
    @views initialGuess[ipsi,  :] .= 0.0
    @views initialGuess[iphin, :] .= 0.0
    @views initialGuess[iphip, :] .= 0.0

    control.damp_initial      = 0.1
    control.damp_growth       = 1.61 # >= 1
    control.max_round         = 5

    sys.boundary_values[iphin, bregionAcceptor] = 0.0 * V
    sys.boundary_values[iphip, bregionAcceptor] = 0.0 * V
    sys.physics.data.contactVoltage             = 0.0 * sys.physics.data.contactVoltage

    I = collect(20.0:-1:0.0)
    LAMBDA = 10 .^ (-I) 
    prepend!(LAMBDA,0.0)
    for i in 1:length(LAMBDA)
        if test == false
            println("λ1 = $(LAMBDA[i])")
        end
        sys.physics.data.λ1 = LAMBDA[i]
        solve!(solution, initialGuess, sys, control = control, tstep=Inf)
        initialGuess .= solution
    end

    if pyplot
        ChargeTransportInSolids.plotEnergies(grid, data, solution, "EQULIBRIUM (NO illumination)")
        PyPlot.figure()
        ChargeTransportInSolids.plotDensities(grid, data, solution, "EQULIBRIUM (NO illumination)")
        PyPlot.figure()
        ChargeTransportInSolids.plotSolution(coord, solution, data.Eref, "EQULIBRIUM (NO illumination)")
    end

    println("*** done\n")

    testval = solution[ipsi, 20]
    return testval

end #  main

function test()
    testval=-4.196344422098774
    main(test = true, unknown_storage=:dense) ≈ testval && main(test = true, unknown_storage=:sparse) ≈ testval
end


println("This message should show when this module is successfully recompiled.")

end # module
Perovskite solar cell
================================
We simulate charge transport in perovskite solar cells (PSCs), where we have apart from holes and electrons also ionic charge carriers. Here, we assume to have three domains, denoted by 
$\mathbf{\Omega} = \mathbf{\Omega}_{\text{HTL}} \cup \mathbf{\Omega}_{\text{intr}} \cup \mathbf{\Omega}_{\text{ETL}}  $. 
The unknowns are the quasi Fermi potentials of electrons, holes and anion vacancies 
$\varphi_n, \varphi_p, \varphi_a$ 
as well as the electric potential 
$\psi$.
The underlying PDEs are given by
```math
\begin{aligned}
	- \nabla \cdot (\varepsilon_s \nabla \psi) &= q \Big( (p(\psi, \varphi_p) - N_A ) - (n(\psi, \varphi_n) - N_D) \Big),\\
	q \partial_t n(\psi, \varphi_n) - \nabla \cdot \mathbf{j}_n &= q\Bigl(G(\mathbf{x}) - R(n,p) \Bigr), \\
	q \partial_t p(\psi, \varphi_p) + \nabla \cdot \mathbf{j}_p &= \Bigl(G(\mathbf{x}) - R(n,p) \Bigr),
\end{aligned}
``` 
for 
$\mathbf{x} \in \mathbf{\Omega}_{\text{HTL}} \cup  \mathbf{\Omega}_{\text{ETL}} $, $t \in [0, t_F]$. In the middle, intrinsic region ($ \mathbf{x} \in \mathbf{\Omega}_{\text{intr}} $), we have 
```math
\begin{aligned}
	- \nabla \cdot (\varepsilon_s \nabla \psi) &= q \Big( p(\psi, \varphi_p)  - n(\psi, \varphi_n) + a(\psi, \varphi_a) - C_0 \Big),\\
q \partial_t n(\psi, \varphi_n)	- \nabla \cdot \mathbf{j}_n &= \Bigl(G(\mathbf{x}) - R(n,p) \Bigr), \\
	q \partial_t p(\psi, \varphi_p) + \nabla \cdot \mathbf{j}_p &= \Bigl(G(\mathbf{x}) - R(n,p) \Bigr),\\
	q \partial_t a(\psi, \varphi_a) + \nabla \cdot \mathbf{j}_a &= 0,
\end{aligned}
``` 
see [Abdel2021](https://www.sciencedirect.com/science/article/abs/pii/S0013468621009865).

Differences to the previous example include
- an additional charge carrier (the anion vacancy)
- parameter jumps across heterojunctions
- the transient case
- a generation rate $G$
- higher dimensional problem (2D and 3D).

A quick survey on how to use `ChargeTransport.jl` to adjust the input parameters such that these features can be simulated will be given in the following.

## Example 1: Graded interfaces
By default, we assume abrupt inner interfaces. If one wishes to simulate graded interfaces, where for example the effective density of states and the band-edge energy may vary, we refer to [Example105](https://github.com/PatricioFarrell/ChargeTransport.jl/blob/master/examples/Example105_PSC_gradedFlux.jl).

We sketch the relevant part here. First, we need to define two additional thin interface layers

```julia
# region numbers
regionDonor             = 1       # n doped region
regionJunction1         = 2
regionIntrinsic         = 3       # intrinsic region
regionJunction2         = 4
regionAcceptor          = 5       # p doped region
```
which need to be taken into account by the initialization of the grid.

Second, since we allow varying parameters within the thin interface layers, the flux discretization scheme needs to be chosen accordingly and we need to construct a nodally dependent parameter struct

```julia
data.flux_approximation = scharfetter_gummel_graded

paramsnodal             = ParamsNodal(grid, numberOfCarriers)
```

Finally, we introduce graded parameters. Currently, only a linear grading is implemented.

```julia
paramsnodal.bandEdgeEnergy[iphin, :]  = gradingParameter(paramsnodal.bandEdgeEnergy[iphin, :],
                                                        coord, regionTransportLayers, regionJunctions,
                                                        h, heightLayers, lengthLayers, EC)
```

## Example 2: Linear IV scan protocol
Here, we summarize the main parts of [Example106](https://github.com/PatricioFarrell/ChargeTransport.jl/blob/master/examples/Example106_PSC_withIons_IVMeasurement.jl).
Define three charge carriers.
```julia
iphin                       = 2 # electrons 
iphip                       = 1 # holes 
iphia                       = 3 # anion vacancies 
numberOfCarriers            = 3 
```
Consider the transient problem and enable the ionic charge carriers only in the active layer:
```julia
data.model_type             = model_transient
data.enable_ionic_carriers  = enable_ionic_carriers(ionic_carriers = [iphia], 
                                                    regions = [regionIntrinsic])
```

Specify the scan rate and scan protocol. Currently, only linear scan protocols are defined.

```julia
scanrate    = 1.0 * V/s
n           = 31
endVoltage  = voltageAcceptor 
tvalues     = set_time_mesh(scanrate, endVoltage, n, type_protocol = linearScanProtocol)
```
Solve the transient problem:
```julia    
for istep = 2:number_tsteps
        
    t             = tvalues[istep]                  # current time
    Δu            = t * scanrate                    # applied voltage 
    Δt            = t - tvalues[istep-1]            # time step 
    set_ohmic_contact!(ctsys, bregionAcceptor, Δu)
    solve!(solution, initialGuess, ctsys, control = control, tstep = Δt) # provide time step
    initialGuess .= solution

end 
```
## Example 3: Illumination
Add uniform illumination to the previous code by setting

```julia
data.generation_model    = generation_uniform
```
and specifing the uniform generation rate in each region, i.e.

```julia
for ireg in 1:numberOfRegions
    params.generationUniform[ireg]  = generationUniform[ireg]
end
```
for given data  stored in `generationUniform`. Note that also Beer-Lambert generation is implemented but yet not well tested.
Furthermore, we recommend to perform a time loop while increasing the generation rate and afterwards applying the scan protocol with a full generation due to numerical stability, see for this [Example107](https://github.com/PatricioFarrell/ChargeTransport.jl/blob/master/examples/Example107_PSC_uniform_Generation.jl).

## Example 4: 2D and 3D problems
It is also possible to perform multi-dimensional simulations.

For a 2D mesh you may use a structured grid via [ExtendableGrids.jl](https://github.com/j-fu/ExtendableGrids.jl), see [Example108](https://github.com/PatricioFarrell/ChargeTransport.jl/blob/master/examples/Example108_PSC_2D_tensorGrid.jl) or an unstructured mesh via the Julia wrapper [Triangulate.jl](https://github.com/JuliaGeometry/Triangulate.jl) for Jonathan Richard Shewchuk's Triangle mesh generator, see [Example201 for the simulation on a rectangular grid](https://github.com/PatricioFarrell/ChargeTransport.jl/blob/master/examples/Example201_PSC_2D_unstructuredGrid.jl) or [Example201 for a non-rectangular one](https://github.com/PatricioFarrell/ChargeTransport.jl/blob/master/examples/Example201_2D_non_rectangularGrid.jl).

Lastly, with help of the [TetGen.jl](https://github.com/JuliaGeometry/TetGen.jl) wrapper, three dimensional tetrahedral meshes can be generated, see [Example202](https://github.com/PatricioFarrell/ChargeTransport.jl/blob/master/examples/Example202_3D_grid.jl).
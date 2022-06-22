module RidePooling

#required packages for defining our own functions
using Plots
using Agents
using OpenStreetMapX
using OpenStreetMapXPlot
using SparseArrays
using Random
using LinearAlgebra
using PrettyTables
using Measures
using PolygonOps
using DelimitedFiles
using Pkg                 #for pkgversion
using Serialization       #for savemodel, loadmodel
import Base.length

export step!, dummystep  #from Agents.jl
export Job, Bus, Request, Subspace, ABM #our data types

# custom data structures
mutable struct Job
    start::Tuple{Int,Int,Float64}        #position where job starts. Positions are 3-tuples because:
                                         #('node id I've been last', 'node id I'm going to', 'distance travelled between them in meters')
    destination::Tuple{Int,Int,Float64}  #position where job ends
    route::Array{Int,1}                  #route from start to destination
    duration::Float64                    #route length in time (s)
    length::Float64                      #route length in distance (m)
    req_id::Int                          #request id that's to be served by end of tour.
    Δ::Int                               #number of passengers to be picked up at end of job. Can be negative. So far, it's only +1 (pickup) or -1 (dropoff).
end

mutable struct Bus <: AbstractAgent
    id::Int                              #bus id
    pos::Tuple{Int,Int,Float64}          #current position
    route::Array{Int,1}                  #route of currently active job.
    destination::Tuple{Int,Int,Float64}  #current destination (of active job)
    todo::Array{Job,1}                   #list of jobs. When current job is finished, next job from todo-list is started
    passengers::Array{Int,1}             #list of passenger ids currently on board
    capacity::Int                        #maximum number of passengers on board.
end

mutable struct Request
    id::Int                              #request id = "name of passenger"
    pickup::Tuple{Int,Int,Float64}       #pickup location
    dropoff::Tuple{Int,Int,Float64}      #dropoff location
    direct_route::Array{Int,1}           #direct route from pickup to dropoff
    direct_time::Float64                 #length of direct route in time (s)
    direct_length::Float64               #length of direct route in distance (m)
    t_submit::Float64                    #time when request is submitted by customer
    t_pickup::Float64                    #time when request is picked up by bus.      DEFAULT: '-1.0' until picked up
    t_dropoff::Float64                   #time when request is dropped off by bus.    DEFAULT: '-1.0' until dropped off
    bus_id::Int                          #id of bus that serves this request          DEFAULT: '-1' until bus is assigned
    plotcolor::RGB                       #random color, only for plotting. simulation ignores it.
end

struct Subspace
    weight::Float64                      # prob that any new request comes from here
    outflow::Array{Float64,1}            # list of probabilities of outflow towards (other) regions, ordered by their ids
    category::Symbol                     # see below
    content::Tuple                       # see below
### convention on Subspaces: ###
# category==:nodes
#    content=Tuple of node ids (Integers)
#category==:triplets
#    content=Tuple of position triples
#category==:edges
#    content[1]=list of edges
#    content[2]=list of weights
#category==:area_to_node
#    content[1]= polygon with LatLon vertices given by 'shape' and we're drawing from its area
#    content[2]= polygon bounding rectangle
#category==:area_to_edge
#    content[1]= polygon with LatLon vertices given by 'shape' and we're drawing from its area
#    content[2]= polygon bounding rectangle
#category==:latlon_to_node
#    content= Tuple of latlons
#category==:latlon_to_edge
#    content= Tuple of latlons
end


# Functions of RideShare.jl
include("functions/core.jl")                 #under-the-hood functions that are required to run a simulation
include("functions/top_level.jl")            #top-level functions that are typically used in jupyter notebooks
include("functions/dispatcher.jl")           #dispatcher logic: functions that are associated with assigning a request to a bus
include("functions/requests.jl")             #functions for drawing new requests; spatial distributions
include("functions/cost_functions.jl")       #cost functions used by dispatcher logic.
include("functions/rejections.jl")           #rejection criteria for incoming requests
include("functions/evaluation.jl")           #functions for evaluating simulations in form of model struct.
include("functions/custom_plots.jl")         #custom plot functions for agents, requests etc.
include("functions/custom_move_agents.jl")   #custom functions for moving agents on an OSM map in time.
                                             #These should eventually be incorporated into Agents.jl and are thus only temporary.
include("functions/synthetic_maps.jl")       #making artificial maps in the same format as MapSpace from OSM
end

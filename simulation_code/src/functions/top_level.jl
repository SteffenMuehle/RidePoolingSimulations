export get_model,
    get_map,
    get_route_matrix,
    calculate_route_matrix,
    get_subspaces,
    savemodel,
    loadmodel,
    report,
    run!


function run!(model::ABM,M::Int)
    step!(model, dummystep, model_step!, M)
end


function run!(model::ABM;requested::Int=1,accepted::Int=0,rejected::Int=0,picked::Int=0,dropped::Int=0,time::Float64=0.0)
    requested_so_far=length(model.requests)
    accepted_so_far=length([1 for req in model.requests if req.bus_id>0])
    picked_so_far=length([1 for req in model.requests if req.t_pickup>0.0])
    dropped_so_far=length([1 for req in model.requests if req.t_dropoff>0.0])

    while requested_so_far<requested || accepted_so_far<accepted || (requested_so_far-accepted_so_far)<rejected || picked_so_far<picked || dropped_so_far<dropped  || model.time<time
        picked_so_far += model.events[1][1]==:pickup
        dropped_so_far += model.events[1][1]==:dropoff

        type_check = (model.events[1][1]==:request)
        step!(model, dummystep, model_step!, 1)
        requested_so_far += type_check
        accepted_so_far += ( type_check && model.requests[end-1].bus_id>0 )
    end
end


"""
model_step!(model) performs one time step.
The length of this time step is chosen to be the minimum of model.time_step or the time until the next event happens.
This way, we never "pass by" an event.

1. Agents are moved
2. Model time is updated
3. If applicable, event is dealt with
"""
function model_step!(model::ABM)::Nothing
    #determine time until next event
    time_until_event=model.events[1][3]-model.time

    # determine length of time step. It's either the fixed model time step 'time_step' or the time until the next event (if that's sooner).
    Δt= model.time_step>0 ? min(time_until_event,model.time_step) : time_until_event

    #move all agents on map
    move_agents_by_time!(Δt,model)

    #update model's time accordingly
    model.time+=Δt

    #if we moved in time until the next event, that event's gotta be dealt with
    if Δt==time_until_event
        process_event!(model)
    end

    return nothing
end


"""
initiate() initiates and returns a model.

key word argument:
N_bus=1               (number of buses)
time_step=1.0     (time step length for one model step is either this value, or the time until the next event.
                       Make this large (10000.0 or so) for an invisible simulation, make it small (1.0 or so) for .gifs.)
ν=1.0/60.0            (Poissonian rate with which new requests come in (1/seconds).)
seed=42               (seed for RNG)
map_path=TEST_MAP     (file path of OSM map)
max_todo=0            (heuristic maximum length of a bus' to do list. '0' means no limitation)
dispatcher=:myopic    (dispatcher logic. ':random' means random insertion, ':myopic' uses cost function's argmin)
"""
function get_model(;
        N_bus=3,            #number of buses
        time_step=0.0,      #time step size if no event triggers
        ν=1.0/60.0,         #request frequency [1/s] - default 1 per minute
        seed=42,            #seed for random number generation

        #map related
        map=get_map(),   #OSM map
        subspaces=:all_edges,
        route_matrix=:not_specified,

        #bus travel velocities
        speed_factor=1.0,      #factor with which bus velocities are multiplied (take into account traffic etc)
        speed_dict=OpenStreetMapX.SPEED_ROADS_URBAN,

        #request related
        min_requested_distance=1e-8,            #minimum requested distance for new requests is 1e-8 m, along the network.

        #dispatcher related
        cost=:trajectory_length,   #cost function for picking best insertion
        rejection_criterion=(), #empty tuple = no rejection criteria
        routing=:live            # ':live' means that routes are calculated live during the simulation, ':lookup' means that a lookup table is provided
        )::ABM

 ## initiate dictionary with model properties..
    props=Dict([:version=>pkgversion(RidePooling),
                :time=>0.0,
                :job_history=>[Job[] for _ in 1:N_bus],
                :ν=>ν,
                :time_step=>time_step,
                :events=>Tuple{Symbol,Int,Float64}[],
                :requests=>Request[],
                :cost=>cost,
                :min_requested_distance=>min_requested_distance,
                :rejection_criterion=>rejection_criterion,
                :routing=>routing
            ])

 ### ..and obtain+add further model properties..

    #depending on routing mode, prepare model's route-memory or route-matrix
    if routing==:live
        props[:memory]=Dict{Tuple{Int64,Int64},Array{Int64,1}}()     #memory for recently calculated routes
    elseif routing==:lookup
        if route_matrix==:not_specified
            println("Routing=:lookup, but route_matrix wasn't specified. I'm calculating the route matrix myself now, which may take a while. Specify matrix yourself, or choose routing=:live if you want to avoid this!")
            route_matrix=calculate_route_matrix(map,save=false)    #if user wants us to calculate the matrix in here, we shall oblige
        end
        props[:route_matrix]=route_matrix
    else
        throw(error("Routing mode $(routing) not supported"))
    end

    #speed_dict (for routing)
    props[:speed_dict]=speed_dict

    #RNG+seed
    props[:rng]=MersenneTwister(seed)

    #map edge travel times
    props[:sparse_times]=get_travel_times(map.m,speed_dict)./speed_factor

    #map edge travel distances
    props[:sparse_distances]=map.m.w

    #specify subspace(s): weight, outflow, category, contents
    if typeof(subspaces)==Symbol
        props[:subspaces]=make_subspace(map,subspaces)  #make it here: :all_nodes or so
    else
        props[:subspaces]=subspaces  #externally provided
    end

    #initiate model
    model=ABM(Bus,map,properties=props)

    #set seed to make simulations reproducible
    seed!(model, seed)

    #add idle buses at random positions
    for id in 1:N_bus
        start=random_trip(model)[2]  #generate random request and take its dropoff as bus position
        add_agent!(start, model, Int[], start, [], [], 8)   #the '8' is a placeholder for bus capacity. not implemented yet.
    end

    #add one request
    new_request!(model)

    #update events list
    make_event_list!(model)

    return model
end


#returns string with package version, e.g. pkgversion(Agents) -> 4.1.3.
#we use this to save 'RidePooling's version as a model property
pkgversion(m::Module) = Pkg.TOML.parsefile(joinpath(dirname(string(first(methods(m.eval)).file)), "..", "Project.toml"))["version"]


function get_map(
        map_specs=(:grid_map,(8,8)),
        road_classes=1:8
    )
    #map=(:category,path/parameters)

    local m

    if map_specs[1] == :osm
        m=get_map_data(map_specs[2]*"map.osm",road_levels = Set(road_classes); use_cache=false, trim_to_connected_graph=true)

    elseif map_specs[1] == :grid_map
        m=grid_map(map_specs[2]...)

    elseif map_specs[1] == :star_grid_map
        m=star_grid_map(map_specs[2]...)

    elseif map_specs[1] == :grid_highway_map
        m=grid_highway_map(map_specs[2]...)

    elseif map_specs[1] == :htree4
        m=htree4()
    end

    #required field for Agents.jl to keep track of agent positions
    agent_positions = [Int[] for i in 1:length(m.n)]

    #this is model.space with fields 'm' and 's'.
    return OpenStreetMapSpace(m, agent_positions)
end


function get_route_matrix(map_folder)
    deserialize(map_folder*"route_matrix")
end


function calculate_route_matrix(map;save=true)
    model=get_model(map=map)
    M=length(model.space.m.n)
    route_matrix=Int.(zeros(M,M))

    for self in 1:M
        route_matrix[self,self]=self
    end

    for p1 in 1:M
        for p2 in 1:M

            pickup=(p1,p1,0.0)
            dropoff=(p2,p2,0.0)
            if route_matrix[p1,p2]!=0
                continue
            end

            route=osm_plan_route(pickup,dropoff,model,by=:fastest;speeds=model.speed_dict)
            target=dropoff[2]
            next=pickup[1]

            list=[pickup[2];route;dropoff[1]]
            for k in length(list):-1:1
                for j in 1:k-1
                    route_matrix[list[j],list[k]]=list[j+1]
                end
            end
        end

        if (10*p1)%M==0
            #println("$(Integer(round(100*p1/M;digits=0)))%")
        end
    end

    if save
        io=open("route_matrix","w")
        serialize(io,route_matrix)
        close(io)
    end

    return route_matrix
end


"""
get_subspaces(path::String,filenames::Tuple{String},J::Array{Float64,2}) reads in files 'filenames' at 'path' and returns a tuple of Subspaces.
Weights and outflows for the subspaces is taken from matrix 'J'. row=first_index='from' - column=second_index='to'.
"""
function get_subspaces(path::String,filenames::Tuple,categories::Tuple)
    J=readdlm(path*"subspaces/transition_matrix.txt")

    weights=[sum(J[row,:]) for row in 1:length(J[:,1])]
    for row in 1:length(J[:,1])
        J[row,:]/=weights[row]
    end
    weights/=sum(weights)

    subspace_array=Subspace[]

    for k in 1:length(filenames)
        category=categories[k]
        filecontent=eval(Meta.parse(readdlm(path*"subspaces/"*filenames[k])[1]))

        if (category == :nodes) || (category == :triplets) || (category == :latlon_to_node) || (category == :latlon_to_edge)
            content=filecontent

        elseif (category == :area_to_node) || (category == :area_to_edge)
            bounds=(minimum([element[1] for element in filecontent]),
                    maximum([element[1] for element in filecontent]),
                    minimum([element[2] for element in filecontent]),
                    maximum([element[2] for element in filecontent]))
            content=(filecontent,bounds)

        elseif category == :edges
            edge_weights=[1.0 for edge in filecontent]  #here we weigh all edges uniformly when really, we'd rather weigh them by their length.
                                                        #But that requires knowledge of the model's map, and we don't have that here. To be fixed later?
            content=(filecontent,edge_weights)
        end

        weight=weights[k]
        outflow=J[k,:]
        push!(subspace_array,Subspace(weight,outflow,category,content))
    end

    return Tuple(subspace_array)
end


"""
savemodel(str::String,model::ABM) serializes and saves a model to a filepath 'str'.
"""
function savemodel(str::String,model::ABM;route_matrix=false)::Nothing
    #strip requests of routes to save space, except the last one - it may still be needed
    for req in model.requests[1:end-1]
    req.direct_route=Int[]
    end

    #strip finished (!) jobs of routes to save space
    for bus_history in model.job_history
        for job in bus_history
            job.route=Int[]
        end
    end

    if route_matrix
        model.route_matrix=Array{Int,2}(undef,0,0)
    end

    #save to file
    io=open(str,"w")
    serialize(io,model)
    close(io);
end


"""
loadmodel(str::String) deserializes and returns a model from filepath 'str'.
"""
function loadmodel(str::String)::ABM
    return deserialize(str)
end


"""
report(model) is a top-level function that prints the status of all requests and buses, the model's time and returns the model's event list.
"""
function report(model::ABM,reqs::UnitRange{Int64};digits=1)
    ## REQUESTS ##
    #text colors in table
    hl_b=Highlighter((data,i,j)->(j==2 && typeof(data[i,j])==String),crayon"red bold")
    hl_p=Highlighter((data,i,j)->(j==5)&&(typeof(data[i,j])!=Float64),crayon"yellow bold")
    hl_d=Highlighter((data,i,j)->(j==6)&&(typeof(data[i,j])!=Float64),crayon"yellow bold")
    hl_t1=Highlighter((data,i,j)->(j==7)&&(typeof(data[i,j])==Float64 && data[i,j]<1.0),crayon"green bold")
    hl_t2=Highlighter((data,i,j)->(j==7)&&(typeof(data[i,j])==Float64 && 3.0>data[i,j]>2.0),crayon"yellow bold")
    hl_t3=Highlighter((data,i,j)->(j==7)&&(typeof(data[i,j])==Float64 && data[i,j]>3.0),crayon"red bold")

    #table data
    data=hcat(
    [string(req.id) for req in model.requests[reqs]],
    [(req.bus_id==-1 ? "rejected" : req.bus_id) for req in model.requests[reqs]],
    [round(req.direct_time/60;digits=1) for req in model.requests[reqs]],
    [round(req.t_submit/60;digits=1) for req in model.requests[reqs]],
    [(req.t_pickup>0 ? round((req.t_pickup-req.t_submit)/60;digits=digits) : (req.bus_id>0 ? "waiting for bus $(req.bus_id)" : "")) for req in model.requests[reqs]],
    [(req.t_dropoff>0 ? round((req.t_dropoff-req.t_pickup)/req.direct_time;digits=digits) : (req.bus_id>0 ? (req.t_pickup>0 ? "on bus $(req.bus_id)" : "") : "")) for req in model.requests[reqs]],
    [((req.t_pickup>0 && req.t_dropoff>0) ? round((req.t_dropoff-req.t_submit-req.direct_time)/req.direct_time;digits=digits) : "") for req in model.requests[reqs]]
    )

    #table header
    header=["request id" "bus id" "direct time" "submit time" "waiting time" "detour factor " "extra time"
            "" "" "(minutes)" "(minutes)" "(minutes)" "(direct times)" "(direct times)"]

    #print request table
    pretty_table(data,header,header_crayon=crayon"yellow bold",subheader_crayon=crayon"blue",highlighters=(hl_b,hl_p,hl_d,hl_t1,hl_t2,hl_t3),alignment=:c)

    ## BUSES ##
    #table data
    data=hcat(
    [(bus=model[key];string(bus.id)) for key in 1:length(model.agents)],
    [(bus=model[key];isempty(bus.passengers) ? "" : bus.passengers) for key in 1:length(model.agents)],
    [(bus=model[key];str="";
            for job in bus.todo
                str*="$(job.Δ*job.req_id); "
                end;
            str) for key in 1:length(model.agents)]
    )

    #table header
    header=["bus id" "passengers" "to do list"]

    #print bus table
    pretty_table(data,header,header_crayon=crayon"yellow bold",alignment=[:c,:c,:l])

    ## EVENTS ##
    return model.events
end

function report(model::ABM;digits=1)
    report(model,max(length(model.requests)-20,1):length(model.requests);digits)
end

function report(model::ABM, number::Int;digits=1)
    report(model,length(model.requests)-number:length(model.requests);digits)
end

"""
'process__event!(model)' returns nothing.
It looks at the model's event list, deletes the first one and processes it by checking which type of event it is ('pickup', 'dropoff' or 'request') and dispatching it to the appropriate subfunction ('process__pickup', 'process__dropoff' or 'process__request').
"""
function process_event!(model::ABM)::Nothing
    e=popfirst!(model.events)::Tuple{Symbol,Int,Float64};
    if e[1]==:pickup
        process_pickup!(e,model)
    elseif e[1]==:dropoff
        process_dropoff!(e,model)
    elseif e[1]==:request
        process_request!(e,model)
    end
end


"""
'process__pickup!(event,model)' returns nothing.
'event' is assumed to have the form ::Tuple{Symbol,Int,Float64}, namely (:pickup,req_id,time), and yields all the information we need here because we also have access to the model's request list.

1. The passenger is added to the passenger list of the bus it was assigned to.
2. The passenger remembers its pickup time.
3. The bus' current (pickup) job is finished and is thus moved to the bus' history
4. If todo-list is not empty, bus starts next job and this next job's finish time makes a new event, which is written on model's event list.
"""
function process_pickup!(e::Tuple{Symbol,Int,Float64},model::ABM)::Nothing
    #infos from events tuple
    req_id=e[2]
    req=model.requests[req_id]  
    bus=model[req.bus_id]
    
    #add passenger to bus
    push!(bus.passengers,req_id)
    
    #request remembers when it was picked up
    req.t_pickup=model.time
    
    #move job from bus' todo to its history
    job_to_history!(bus,model)
    
    #If the bus has more jobs on its todo list ...
    if !isempty(bus.todo)
        next_job!(bus,model)                             #... it starts its next job
        new_event=event_from_job(bus.todo[1],model)      #... creates a new event from it
        sort!(push!(model.events,new_event),by=x->x[3])  #... and writes it on model's event list + sorts it
    else
        throw(error("todo list of bus $(req.bus_id) is empty after a pickup. impossible."))   #we should never end up here, because after a pickup,
    end                                                                                  #there must always be a dropoff. Just checking..
    
    return nothing
end


"""
'process__dropoff!(event,model)' returns nothing.
'event' is assumed to have the form ::Tuple{Symbol,Int,Float64}, namely (:dropoff,req_id,time), and yields all the information we need here because we also have access to the model's request list.

1. The passenger is removed from the passenger list of the bus it was assigned to.
2. The passenger remembers its dropoff time.
3. The bus' current (dropoff) job is finished and is thus moved to the bus' history
4. If todo-list is not empty, bus starts next job and this next job's finish time makes a new event, which is written on model's event list.
"""
function process_dropoff!(e::Tuple{Symbol,Int,Float64},model::ABM)::Nothing
    #infos from events tuple
    req_id=e[2]
    req=model.requests[req_id]
    bus=model[req.bus_id]
    
    #remove passenger from bus
    index=findfirst(x->x==req_id,bus.passengers)
    isnothing(index) ? throw(error("request id not found in bus' passenger list.")) : deleteat!(bus.passengers,index)  #just checking if passenger was indeed on bus :)
    
    #request remembers when it was dropped off
    req.t_dropoff=model.time
    
    #move job from bus' todo to its history
    job_to_history!(bus,model)
    
    #If the bus has more jobs on its todo list ...
    if !isempty(bus.todo)
        next_job!(bus,model)                             #... it starts its next job
        new_event=event_from_job(bus.todo[1],model)      #... creates a new event from it
        sort!(push!(model.events,new_event),by=x->x[3])  #... and writes it on model's event list + sorts it
    end
    
    return nothing
end


"""
'process__request!(event,model)' returns nothing.
'event' is assumed to have the form ::Tuple{Symbol,Int,Float64}, namely (:request,req_id,time), and yields all the information we need here because we also have access to the model's request list.

1. Best-possible insertion is calculated via the 'best_insertion' function.
2. Request's pickup+dropoff are written on bus' todo list according to this insertion.
3. If the bus' immediate job got replaced (or if it was idle), bus route+destination and model's event list are updated.
4. Finally, a new request is drawn from Poisson distro and it's added to model's event list.
"""
function process_request!(e::Tuple{Symbol,Int,Float64},model::ABM)::Nothing
    #request id not actually needed because we know that the request at hand must be the last on the model's request list
    req=model.requests[end]
    
    #This is the performance critical step of the entire simulation.
    #The best insertion is found: The bus, request, and pickup+dropoff positions on todo list
    (bus,req,p1,p2)=best_insertion(req,model)
    
    #checking if bus was idle
    bus_was_idle=isempty(bus.todo)
    
    # (unrejected) request onto todo
    if p1!=0  #NOT rejected
        if p1==1 && !bus_was_idle               #first job is partially done and about to be overwritten.
            remember_current_job!(bus,model)    #we need to remember it for later evaluation of bus trajectory
        end
        
        request_onto_todo!(bus,req,p1,p2,model)  #write request onto bus' todo list according to best-found insertion from above
        req.bus_id=bus.id                        #request must also know which bus it's on.
    else      #rejected
        req.bus_id=-1   # Tell the request, it was rejected. -1 means rejected.
    end
    
    
    #Often, we are done here.
    #There are two scenarios in which we are not, though.
    #  (a) If the bus was idle, it needs to start its new job + put it on the model's event list
    #  (b) If the bus was not idle, but it's current job got replaced,
    #      model's event list must be informed about the replacement + the (new) first job must be started
    if bus_was_idle && p1 != 0  # case (a) (only if request was not rejected though)
        next_job!(bus,model)                             #start new job
        new_event=event_from_job(bus.todo[1],model)      #put it on model's event list
        sort!(push!(model.events,new_event),by=x->x[3])  #+sort it
    elseif p1==1     # case (b)
        #let's find the previously first (=to-be-replaced) job in todo list
        postponed_job= (p2==2 ? bus.todo[3] : bus.todo[2])
        
        #find it on model's event list
        event_index=findfirst(x->x[2]==postponed_job.req_id,model.events)
        
        #and remove it  (while double checking that it was indeed on the list as it should :-) )
        isnothing(event_index) ? throw(error("replaced request id not found in event list.")) : deleteat!(model.events,event_index)
        
        #write new first job onto event list
        new_event=event_from_job(bus.todo[1],model)
        sort!(push!(model.events,new_event),by=x->x[3])
                
        #finally, we also gotta tell the bus to go to its new first job
        next_job!(bus,model)
    end

    # draw next request
    new_request!(model)
    # and write it on event list
    sort!(push!(model.events,(:request,model.requests[end].id,model.requests[end].t_submit)),by=x->x[3])
    
    #clear model's memory of precalculated routes
    if model.routing==:live
        model.memory=Dict{Tuple{Int64,Int64},Array{Int64,1}}()
    end
    
    return nothing
end


"""
job_to_history!(bus) returns nothing.

1. Current job is removed from bus' todo list.
2. Removed job is added to bus' history.
"""
function job_to_history!(bus::Bus,model::ABM)::Nothing
    push!(model.job_history[bus.id],popfirst!(bus.todo))
    return nothing
end


"""
remember_current_job!(bus) returns nothing.

1. Current (partially done) job is put on bus' todo list as if it it was meant to finish where bus is now.
2. This "fake" job is related to no customers (req_id=Delta=0).
"""
function remember_current_job!(bus::Bus,model::ABM)::Nothing
    start= bus.todo[1].start  #from where current job started
    destination=bus.pos       #..to where bus is now.
    Δ=0                       #number of passengers doesn't change..
    req_id=0                  #..and noone's being picked up or dropped off here
    job=make_job(start,destination,req_id,Δ,model)
    push!(model.job_history[bus.id],job)
    
    return nothing
end


"""
next_job!(bus) returns nothing. It only alters the bus' status.

1. Bus' route is overwritten with that of the job on top of its todo list.
2. Bus' destination is overwritten with that of the job on top of its todo list.

We should be done then. Here is a subtle error that may occur though:
The bus has been moved for a time that should move it PRECISELY to its destination.
Due to round errors, it may still be a tiny distance away from where it should be.
In this case

3. Bus is moved to start of the job on top of its todo list, which is where it is expected to be anyway.
"""
function next_job!(a::Bus,model::ABM)::Nothing
    if !isempty(a.todo)
        #change bus' active route+destination
        a.route=copy(a.todo[1].route)
        a.destination=a.todo[1].destination
    else
        #we should never end up here, just a double-check.
        throw(error("bus $(a.id) can't start towards next job: todo list is empty."))
    end
    
    #correct possible rounding error.
    expected_position=a.todo[1].start  #this is where the bus should be. If it isn't it's possibly an expected round error:
    if a.pos != expected_position      #agent position is almost (within 1 meter) at the correct node -> manually update position -> problem solved
        almost_there= norm( cartesian_coords(a.pos,model)-cartesian_coords(expected_position,model) ) < 1.0 #1 meter will do. This is arbitrary.
        if almost_there                                   #already travelled on that edge btw)
            move_agent!(a,expected_position,model)  #gotta use this function rather than change position manually
                                                    #because model's space keeps track of agent positions, too.
        else
            #we should never end up here, just a double-check.
            throw(error("bus $(a.id) is at position $(a.pos) but its (now starting) job starts at $(a.todo[1].start). Impossible."))
        end
    end
    
    return nothing
end


"""
'event_from_request(request)' takes a request and returns an event in the form Tuple{Symbol,Int,Float64}, namely (sym,id,time).

'sym'  = 'event'
'id'   = associated request id (=passenger)
'time' = time when event occurs.
"""
function event_from_request(req::Request)::Tuple{Symbol,Int,Float64}
    sym=:request
    id=req.id
    time=req.t_submit
    
    return (sym,id,time)
end


"""
'event_from_job(job,model)' takes a job and returns an event in the form Tuple{Symbol,Int,Float64}, namely (sym,id,time).

'sym'  = 'pickup', 'dropoff' or 'event'
'id'   = associated request id (=passenger)
'time' = time when event occurs.
"""
function event_from_job(job::Job,model::ABM)::Tuple{Symbol,Int,Float64}
    sym= job.Δ>0 ? :pickup : :dropoff
    id=job.req_id
    time=model.time+job.duration
    
    return (sym,id,time)
end


"""
'events_from_jobs(model))' returns a sorted event list based on the model's agent's todo lists.
events have the form Tuple{Symbol,Int,Float64}, namely (sym,id,time).

'sym'  = 'event'
'id'   = associated request id (=passenger)
'time' = time when event occurs.

See also 'event_from_job'.
"""
function events_from_jobs(model::ABM)::Array{Tuple{Symbol,Int,Float64},1}
    events=Tuple{Symbol,Int,Float64}[]
    for id in model.scheduler(model)            #loop over all buses
        isempty(model[id].todo) ? continue :    #bus got nothing to contribute if it's got no todo list
        job=model[id].todo[1]                   #job on top of list is the next one finishing
        push!(events,event_from_job(job,model))
    end
    
    return sort!(events,by=x->x[3])             #sort events by the time they occur
end


"""
'make_job(start,destination,req_id,Δ,model) returns a job with the following field values:

(start,destination,req_id,Δ,model) as given in argument.

(route, duration, length) are calculated here.
This means that 'make_job' does calculate the route, its length and duration under the hood.
"""
function make_job(start::Tuple{Int,Int,Float64},destination::Tuple{Int,Int,Float64},req_id::Int,Δ::Int,model::ABM)::Job
    route=plan_route(start,destination,model)
    duration=route_time(start,route,destination,model)
    length=route_length(start,route,destination,model)
    
    return Job(start,destination,route,duration,length,req_id,Δ)   
end


"""
request_onto_todo!(bus::Bus,req::Request,p1::Int,p2::Int,model::ABM) takes a previously found insertion (bus,req,p1,p2) and applies it.

1. If p1==0, the request was rejected by convention and we do nothing.
Otherwise:
2. Request's bus id gets updated.
3. Pickup job onto todo list at position p1.
4. Dropoff job onto todo list at position p2.

Steps 3+4 require a case distinction depending on p1, p2 and todo-list's length.
If necessary, replaced jobs get removed.
"""
function request_onto_todo!(bus::Bus,req::Request,p1::Int,p2::Int,model::ABM)::Nothing
    
    
    #easiest case first:
    #insert pickup+dropoff at the very end:                            (.. A->B) --> (.. A->B, B->pickup, pickup->dropoff)
    #also includes case of empty todo    
    if size(bus.todo)[1]<p1
        #pickup job
        start=isempty(bus.todo) ? bus.pos : bus.todo[end].destination
        destination=req.pickup
        Δ=1
        push!(bus.todo,make_job(start,destination,req.id,Δ,model))

        #dropoff job
        start= bus.todo[end].destination
        destination=req.dropoff
        Δ=-1
        push!(bus.todo,make_job(start,destination,req.id,Δ,model))
        
        return nothing
    end
    
    ##now we know:
    ##todo is not empty.
    ##Let's do the pickup first, then the dropoff
    
    # PICKUP
    if p1==1 #at beginning:                                             (A->B ..)  -->  (pos->pickup, pickup->B ..)
        #previously first job gets replaced:
        prev=popfirst!(bus.todo)
        
        #pos to pickup
        start=bus.pos
        destination=req.pickup
        Δ=1
        pushfirst!(bus.todo,make_job(start,destination,req.id,Δ,model))
        
        #pickup to 'previous destination'
        start=req.pickup
        destination=prev.destination
        Δ=prev.Δ
        splice!(bus.todo,2:1,[make_job(start,destination,prev.req_id,Δ,model)])
        
    else #somewhere in the middle but not the end:                      (.. A->B ..) --> (.. A->pickup,pickup->B ..)
        #a job in the middle gets replaced
        prev=popat!(bus.todo,p1)
        
        #previous to pickup
        start=prev.start
        destination=req.pickup
        Δ=1
        splice!(bus.todo,p1:p1-1,[make_job(start,destination,req.id,Δ,model)])
        
        #pickup to next
        start=req.pickup
        destination=prev.destination
        Δ=prev.Δ
        splice!(bus.todo,p1+1:p1,[make_job(start,destination,prev.req_id,Δ,model)])
    end
    
    
    # DROPOFF
    if p2>size(bus.todo)[1] #at end, nothing needs to be replaced:       (.. A->B) --> (.. A->B, B->dropoff)
        start=bus.todo[end].destination
        destination=req.dropoff
        Δ=-1
        push!(bus.todo,make_job(start,destination,req.id,Δ,model))
    else #somewhere in the middle:                                       (.. A->B ..) --> (.. A->dropoff,dropoff->B ..)
        #a job in the middle gets replaced
        prev=popat!(bus.todo,p2)
        
        #previous to dropoff
        start=prev.start
        destination=req.dropoff
        Δ=-1
        splice!(bus.todo,p2:p2-1,[make_job(start,destination,req.id,Δ,model)])
        
        #pickup to next
        start=req.dropoff
        destination=prev.destination
        Δ=prev.Δ
        splice!(bus.todo,p2+1:p2,[make_job(start,destination,prev.req_id,Δ,model)])        
    end
    
    return nothing
end


"""
'new_request(model)' draws a new random request and adds it to model's request list.
This means a random pickup+dropoff location are drawn, route (+ its length and duration) are calculated and submit time is drawn from Poisson distribution.
"""
function new_request!(model::ABM)::Nothing
    (pickup,dropoff,route)=random_trip(model)          #random pickup+dropoff+route
    duration=route_time(pickup,route,dropoff,model)              #..its duration
    len=route_length(pickup,route,dropoff,model)                 #..and its length
    color=RGB(rand(model.rng),rand(model.rng),rand(model.rng))   #random color for plotting purposes only
    
    #make request
    req=Request(length(model.requests)+1,pickup,dropoff,route,duration,len,model.time+randexp()/model.ν,0.0,0.0,0,color)
    
    #and push it to model's request list.
    push!(model.requests,req)
    
    return nothing
end


"""
'route_length(start::Tuple{Int,Int,Float64},route::Array{Int,1},destination::Tuple{Int,Int,Float64},model::ABM)' returns the length (in meters)
of the route from 'start' to 'destination' via the nodes-in-between 'route'.

How?
By looking up the graph's weights in model.space.m.w and adding the last and first bit in between nodes.
"""
function route_length(start::Tuple{Int,Int,Float64},route::Array{Int,1},destination::Tuple{Int,Int,Float64},model::ABM)::Float64
    weights=model.space.m.w
    
    if !isempty(route)
        route_with_endpoints=[start[2];route;destination[1]]

        #bulk (probably)
        middle=sum([weights[route_with_endpoints[k],route_with_endpoints[k+1]] for k in 1:length(route_with_endpoints)-1])

        #from where we are to next node
        firstbit= start[1]==start[2] ? 0.0 :            weights[start[1:2]]*(1-start[3]/model.space.m.w[start[1:2]])

        #from last node to destination
        lastbit= destination[1]==destination[2] ? 0.0 : weights[destination[1:2]] * destination[3]/model.space.m.w[destination[1:2]]

        res= firstbit+middle+lastbit
        
    else
        #on final edge
        if start[1:2]==destination[1:2]
            #includes both cases: having (not) yet passed destination. Allowed because we allow hard U-turns on the edge in this case to avoid oneway-lane issues.
            res=abs(destination[3]-start[3])
            
        #on second-to-last-edge
        elseif start[2]==destination[1]
            edge_time=weights[start[1],start[2]]
            res= (edge_time-start[3]) + destination[3]
            
        #on third-to-last-edge
        else
            edge_time1=weights[start[1],start[2]]
            edge_time2=weights[start[2],destination[1]]
            res= (edge_time1-start[3]) + edge_time2 + destination[3]
            
        end
    end
    
    return res
end


"""
'route_time(start::Tuple{Int,Int,Float64},route::Array{Int,1},destination::Tuple{Int,Int,Float64},model::ABM)' returns the  (in meters)
of the route from 'start' to 'destination' via the nodes-in-between 'route'.

How?
By looking up the graph's weights in model.sparse_times and adding the last and first bit in between nodes.
These last bits are given in meters and are manually converted into seconds.
"""
function route_time(start::Tuple{Int,Int,Float64},route::Array{Int,1},destination::Tuple{Int,Int,Float64},model::ABM)::Float64
    weights=model.sparse_times
    start=distance_to_time(start,model)
    destination=distance_to_time(destination,model)
    
    if !isempty(route)
        route_with_endpoints=[start[2];route;destination[1]]

        #bulk (probably)
        middle=sum([weights[route_with_endpoints[k],route_with_endpoints[k+1]] for k in 1:length(route_with_endpoints)-1])

        #from where we are to next node
        firstbit= start[1]==start[2] ? 0.0 :            weights[start[1:2]] * (1-start[3]/weights[start[1:2]])

        #from last node to destination
        lastbit= destination[1]==destination[2] ? 0.0 : destination[3]

        res= firstbit+middle+lastbit
        
    else
        #on final edge
        if start[1:2]==destination[1:2]
            #includes both cases: having (not) yet passed destination. Allowed because we allow hard U-turns on the edge in this case to avoid oneway-lane issues.
            res=abs(destination[3]-start[3])
            
        #on second-to-last-edge
        elseif start[2]==destination[1]
            edge_time=weights[start[1],start[2]]
            res= (edge_time-start[3]) + destination[3]
            
        #on third-to-last-edge
        else
            edge_time1=weights[start[1],start[2]]
            edge_time2=weights[start[2],destination[1]]
            res= (edge_time1-start[3]) + edge_time2 + destination[3]
            
        end
    end
    
    
    start=time_to_distance(start,model)
    destination=time_to_distance(destination,model)
    
    return res
end


"""
'make_event_list(model)' creates the model's event list from scratch and overwrites mode.events with it.
It returns nothing.

1. get events from all buses' to do lists
2. get event from next request
3. combine + sort them
"""
function make_event_list!(model::ABM)::Nothing
    
    #events from todo lists
    bus_job_events=events_from_jobs(model)
    
    #event from next request
    request_events=event_from_request(model.requests[end])
    
    #combine + sort
    model.events=sort!(vcat(bus_job_events,request_events),by=x->x[3])
    
    return nothing
end


"""
plan_route(pickup::Tuple{Int,Int,Float64},dropoff::Tuple{Int,Int,Float64},model::ABM)
checks if the required route is already precalculated in model.memory.
If so, precalculated route is returned.
Otherwise, route is calculated, stored in model.memory and returned
"""
function plan_route(pickup::Tuple{Int,Int,Float64},dropoff::Tuple{Int,Int,Float64},model::ABM)::Array{Int,1}
    
    #calculate route here unless it's in model.memory
    if model.routing==:live
        try   #see if route is already known
            route=model.memory[(pickup[2],dropoff[1])]
            return route
        catch #apparently not. Let's calculate it, put into memory and return
            return model.memory[(pickup[2],dropoff[1])]=osm_plan_route(pickup,dropoff,model,by=:fastest;speeds=model.speed_dict)
        end
    
    #take route from lookup table
    elseif model.routing==:lookup
        return route_from_lookup(pickup,dropoff,model)
        
    else
        throw(error("routing mode $(model.routing) unknown."))
    end
end


"""
cartesian_coords(pos::Tuple{Int,Int,Float64},model::ABM)::Array{Float64,1}
takes a position and the model, and returns the Cartesian coordinates of the position in form of an array.
"""
function cartesian_coords(pos::Tuple{Int,Int,Float64},model::ABM;flip=false)::Array{Float64,1}
    #OSM graph ids of nodes
    nid1=model.space.m.n[pos[1]]
    nid2=model.space.m.n[pos[2]]
    
    #ENU (east-north) coords
    cenu1=model.space.m.nodes[nid1]
    cenu2=model.space.m.nodes[nid2]
    
    #x-y array
    p1=[cenu1.east,cenu1.north]
    p2=[cenu2.east,cenu2.north]
    
    #length of edge
    L=model.space.m.w[pos[1:2]]
    
    #percentage along edge
    percentage= L!=0 ? pos[3]/L : 0
    
    #interpolation between p1 and p2
    coords=p1+percentage*(p2-p1)

    return flip ? coords[end:-1:1] : coords
end
                
                
function cartesian_coords(id::Int64,model::ABM;flip=false)
    cartesian_coords((id,id,0.0),model;flip=flip)
end


function cartesian_coords(pos::ENU,model::ABM;flip=false)
    return flip ? [pos.north,pos.east] : [pos.east,pos.north]
end


function cartesian_coords(pos::LLA,model::ABM;flip=false)
    enu=ENU(pos, model.space.m.bounds)
    return flip ? [enu.north,enu.east] : [enu.east,enu.north]
end


function cartesian_coords(pos::Union{Tuple{Float64,Float64},Array{Float64,1}},model::ABM;flip=false)
    lla=LLA(pos[2],pos[1]) #yes, this must be [2] first, then [1]
    enu=ENU(lla, model.space.m.bounds)
    return flip ? [enu.north,enu.east] : [enu.east,enu.north]
end


function route_from_lookup(pickup::Tuple{Int,Int,Float64},dropoff::Tuple{Int,Int,Float64},model::ABM)::Array{Int,1}
    route=Int[]
    position=pickup[2]

    while position!=dropoff[1]
        position=model.route_matrix[position,dropoff[1]]
        push!(route,position)
    end
    
    if !isempty(route)
        pop!(route)
    end
    
    return route
end
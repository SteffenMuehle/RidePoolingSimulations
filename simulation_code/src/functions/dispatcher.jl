"""
dispatch_greedy(req,model) returns the insertion (bus,req,p1,p2) which has the minimal cost function value determined by model.cost (see '?cost').
All insertions are checked, that's why it's called 'greedy'.
If specified, the function does use a heuristic for discarding insertions (see '?feasible').
"""
function dispatch_greedy(req::Request,model::ABM)::Tuple{Bus,Request,Int,Int}
    best=(model[1],req,0,0)  # '0' means rejected => if we're not going to find anything feasible, request gets rejected.
    best_extra_cost=-1       # such that first feasible option gets accepted

    #loop over buses
    for key in model.scheduler(model)
        bus=model[key]
        todolength=size(bus.todo)[1]

        #remember value of bus' cost function prior to new insertion
        prev_cost=cost(bus,model)

        #loop over pickup+dropff positions on todo list
        for p1 in 1:todolength+1, p2 in p1+1:todolength+2
            ins=(bus,req,p1,p2)

            #calculate bus' new cost function value IF this insertion was chosen
            cost=what_if_cost(ins,model)

            #check if this insertion is the best one we found so far
            if cost ≥ 0 && (best_extra_cost == -1 || cost-prev_cost < best_extra_cost)  #Per convention, negative cost means rejected.
                                                                                        #best_extra_cost == -1 makes sure the first feasible option overwrites dummy.
                                                                                        #Finally, cost-prev_cost is this insertions extra cost.
                #HURRAY, we found a new best insertion!
                best=ins
                best_extra_cost=cost-prev_cost
            end
        end
    end
    
    return best
end


"""
best_insertion(req,model) is the interface between core functions and dispatcher functions.
It takes a request and returns an insertion (bus,request,p1,p2) where p1 and p2 are the positions in the bus' todo list where pickup and dropoff are to be inserted.

'best_insertion' behaves differently, depending on the model's dispatcher mode (currently either ':myopic' (which is the default) or ':random').
':myopic' minimizes a cost function on the space of (bus,p1,p2), while leaving the other buses and the other requests in that bus untouched.
':random' also leaves that untouched, but chooses (bus,p1,p2) randomly.
"""
function best_insertion(req::Request,model::ABM)::Tuple{Bus,Request,Int,Int}
    
    #greedy dispatcher tries all possible insertions
    return dispatch_greedy(req,model)
end


"""
'what_if_cost(ins,model)' returns the cost function's value of the bus in 'ins', imagining that that insertion was applied to it.
Since, we're only checking what the cost WOULD be, we don't actually overwrite stuff in the model.
Instead, a virtual bus is created, the insertion is applied to it, and its cost function is returned.

ins=(bus,request,p1,p2)
"""
function what_if_cost(ins::Tuple{Bus,Request,Int,Int},model::ABM)::Float64
    #ins=(bus,req,p1,p2)
    
    #make copy of bus
    fakeagent=deepcopy(ins[1])
    
    #apply insertion to virtual bus
    request_onto_todo!(fakeagent,ins[2],ins[3],ins[4],model)
    
    if rejection(fakeagent,model)
        return -1  #negative cost means rejected, see 'best_insertion' and 'dispatch_greedy' functions
    end
        
    #return cost function of virtual bus
    return cost(fakeagent,model)
end


"""
'cost(bus,model)' returns the value of a bus' cost function based on the model property 'model.cost'.
Currently implemented functions are

- 'squared_delays'
"""
function cost(bus::Bus,model::ABM)::Float64
    if model.cost==:squared_delays
        return squared_delays(bus,model)
    elseif model.cost==:delays
        return delays(bus,model)
    elseif model.cost==:trajectory_length
        return trajectory_length(bus,model)
    elseif model.cost==:trajectory_time
        return trajectory_time(bus,model)
    elseif model.cost==:custom_cost
        return custom_cost(bus,model)
    elseif model.cost==:random
        return rand()
    end
end


"""
'scheduled_passengers(bus) returns a list of request ids which appear on bus' todo list (both already-on-board and to-be-picked-up!).
"""
function scheduled_passengers(bus::Bus)::Array{Int,1}
    res=Int[]
    #loop over jobs on todo list
    for j in bus.todo
        #everyone scheduled for this bus has their dropoff (\Delta=-1) job on the todo-list once and only once.
        if j.Δ == -1
            push!(res,j.req_id)
        end
    end
    
    return res    
end


"""
rejection(bus::Bus,model::ABM)::Bool dispatches to rejection criteria, depending on model property model.rejection_criterion and returns 'true' or 'false'.
All specified criteria are checked. You need to put them into a tuple such as ((:max_relative_delay,1.5),(:any_max_delay,))
"""
function rejection(bus::Bus,model::ABM)::Bool
    reject=false
    
    
    for criterion in model.rejection_criterion
    #delays
        if criterion[1]==:delay      #maximum delay time, forecast at moment of submission
            reject = reject || rejection_delay(bus,model,criterion[2])

        elseif criterion[1]==:relative_delay      #maximum delay time, forecast at moment of submission
            reject = reject || rejection_relative_delay(bus,model,criterion[2])

        elseif criterion[1]==:any_delay    #maximum waiting time, forecast at moment of submission
            reject = reject || rejection_any_delay(bus,model,criterion[2])

        elseif criterion[1]==:any_relative_delay    #maximum waiting time, forecast at moment of submission
            reject = reject || rejection_any_relative_delay(bus,model,criterion[2])

    #detours
        elseif criterion[1]==:detour    #maximum waiting time, forecast at moment of submission
            reject = reject || rejection_detour(bus,model,criterion[2])

        elseif criterion[1]==:relative_detour    #maximum waiting time, forecast at moment of submission
            reject = reject || rejection_relative_detour(bus,model,criterion[2])
            
        elseif criterion[1]==:any_detour    #maximum waiting time, forecast at moment of submission
            reject = reject || rejection_any_detour(bus,model,criterion[2])

        elseif criterion[1]==:any_relative_detour    #maximum waiting time, forecast at moment of submission
            reject = reject || rejection_any_relative_detour(bus,model,criterion[2])
            
    #waiting times
        elseif criterion[1]==:waiting_time    #maximum waiting time, forecast at moment of submission
            reject = reject || rejection_waiting_time(bus,model,criterion[2])

        elseif criterion[1]==:relative_waiting_time    #maximum waiting time, forecast at moment of submission
            reject = reject || rejection_relative_waiting_time(bus,model,criterion[2])
            
        elseif criterion[1]==:any_waiting_time    #maximum waiting time, forecast at moment of submission
            reject = reject || rejection_any_waiting_time(bus,model,criterion[2])

        elseif criterion[1]==:any_relative_waiting_time    #maximum waiting time, forecast at moment of submission
            reject = reject || rejection_any_relative_waiting_time(bus,model,criterion[2])
            
            
    #custom

        elseif criterion[1]==:any_relative_detour_plus_offset    #maximum waiting time, forecast at moment of submission
            reject = reject || rejection_any_relative_detour_plus_offset(bus,model,criterion[2])

    #unknown
        else
            throw(error("unknown rejection criterion $(model.rejection_criterion)"))
        end
    end
    
    return reject
end
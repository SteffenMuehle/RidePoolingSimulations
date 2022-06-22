"""
dispatch_random(req,model) returns a random insertion (bus,req,p1,p2) where p1<todo-length+2 and p2<p1.
"""
function dispatch_random(req::Request,model::ABM)::Tuple{Bus,Request,Int,Int}
    #random bus
    bus=model[rand(model.rng,keys(model.agents))]
    #random positions of pickup+dropoff on its todo list
    todolength=size(bus.todo)[1]
    p1=rand(model.rng,1:todolength+1)
    p2=rand(model.rng,p1+1:todolength+2)
    return (bus,req,p1,p2)
end
        
        


"""
dispatch_candidates(req,model) returns an insertion (bus,req,p1,p2) which (amongst the 'candidates') has the minimal cost function value determined by model.cost (see '?cost'). Only a set of candidate insertions are actually checked with the full cost function. The candidates are found by checking all insertions with a lazy version of the cost function, using a precalculated grid (to be done!).
"""
function dispatch_candidates(req::Request,model::ABM)::Tuple{Bus,Request,Int,Int}
    
    ## FIND CANDIDATES
    candidates=Tuple{Bus,Request,Int,Int,Float64}[]
    for key in model.scheduler(model)
        bus=model[key]
        todolength=size(bus.todo)[1]
        
        #heuristic constraint:
        #if bus' todo list is too long, this bus rejects request. Per convention, max_todo=0 means there is no limit.
        if model.max_todo!=0 && todolength> model.max_todo
            continue
        end
        
        #loop over pickup+dropff positions on todo list
        for p1 in 1:todolength+1, p2 in p1+1:todolength+2
            candi=(bus,req,p1,p2,quick_cost(req,bus,p1,p2,model))
            if length(candidates)<model.num_candidates
                push!(candidates,candi)
            elseif candi[end]<candidates[end][end] #this is the worst cost of all candidates so far
                pop!(sort!(push!(candidates,candi),by=x->x[end]))
            end
        end
    end
    
    ## FIND BEST INSERTION AMONG CANDIDATES
    best=(model[1],req,0,0)  # '0' means rejected => if we're not going to find anything feasible, request gets rejected.
    best_extra_cost=-1       # such that first feasible option gets accepted
    
    #loop over candidates
    for ins in candidates  #ins=(bus,req,p1,p2)
        ins=ins[1:end-1]
        
        #remember value of bus' cost function prior to new insertion
        prev_cost=cost(ins[1],model)
        
        #calculate bus' new cost function value IF this insertion was chosen
        costvalue=what_if_cost(ins,model)

        #check if this insertion is the best one we found so far
        if costvalue ≥ 0 && (best_extra_cost == -1 || costvalue-prev_cost < best_extra_cost)  #Per convention, negative cost means rejected.
                                                                                    #best_extra_cost == -1 makes sure the first feasible option overwrites dummy.
                                                                                    #Finally, cost-prev_cost is this insertions extra cost.
            #HURRAY, we found a new best insertion!
            best=ins
            best_extra_cost=costvalue-prev_cost
        end
    end 
    
    return best
end

                                    
function best_insertion(req::Request,model::ABM)::Tuple{Bus,Request,Int,Int}
    
    #random insertion
    if model.dispatcher == :random
        return dispatch_random(req,model)
    
    #myopic insertion using cost function
    #'greedy' means we brute-force check every possible insertion
    elseif model.dispatcher == :greedy
        return dispatch_greedy(req,model)
    
    #myopic insertion using cost function
    #'candidates' means we first find a number of candidate insertions using a heuristic cost function,
    #then evaluate the actual cost function only for the candidates
    elseif model.dispatcher == :candidates
        return dispatch_candidates(req,model)
        
    #dispatcher unknown :-(
    else
        println("unknown dispatcher $(model.dispatcher)")
    end
end

                                            
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

        #heuristic constraint:
        #if bus' todo list is too long, this bus rejects request. Per convention, max_todo=0 means there is no limit.
        if model.max_todo!=0 && todolength> model.max_todo
            continue
        end

        #remember value of bus' cost function prior to new insertion
        prev_cost=cost(bus,model)

        #loop over pickup+dropff positions on todo list
        for p1 in 1:todolength+1, p2 in p1+1:todolength+2
            ins=(bus,req,p1,p2)

            #if insertion isn't feasible, no need to check cost function: skip!
            !(feasible(ins,model)) ? continue :

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
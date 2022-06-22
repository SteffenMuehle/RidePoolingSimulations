#script written for versions
#Julia 1.6.2

####################################
## PICK THESE PARAMETERS MANUALLY ##
####################################

target=0.8 # <--- target served percentage
N=5 # <--- number of buses
cost=:trajectory_length  # <--- cost function, other possibilities are :delays and :random
map="htree4" #<--- map. other options are "stargrid_64_16", "stargrid_128_8", "htree4", "broitzem" and "goettingen"

#alright, the rest is automatic, enjoy.
####################################



using Pkg, DelimitedFiles
rpfolder="../"
evaluationfolder="../results/"
Pkg.activate(rpfolder)

# load source code
include(rpfolder*"src/RidePooling.jl")
RP=RidePooling

# top-level parameters for accuracy of results (described in SI)
INIT_DROPPED_PER_BUS=5      #in paper: 10
INIT_DROPPED_MIN=200        #in paper: 1000
INIT_TIME=5.0               #in paper: 10.0
FINAL_REQUESTED_PER_BUS=100 #in paper: 200
FINAL_REQUESTED_MIN=5000    #in paper: 20000
POINTS=10                   #in paper: 10

#set save locations for output files
stringlength=length("$(N)")
percentage=Integer(round(target*100))
fourdigitN=stringlength>3 ? "$(N)" : ("0"^(4-stringlength))*"$(N)"
filepath= evaluationfolder*"$(map)_x$(percentage)_"*fourdigitN*".txt"
guesspath=evaluationfolder*"$(map)_x$(percentage)_"*fourdigitN*"_guess.txt"
savepath= evaluationfolder*"$(map)_x$(percentage)_"*fourdigitN*"_savetuples.txt"

# load map
include("../maps/$(map)/map.jl")  # <---- fetch map

#dispatcher
max_waiting_time=t0
max_relative_detour=1.0
dispatcher=(;
        cost=cost,
        rejection_criterion=((:any_waiting_time,max_waiting_time),
                             (:any_relative_detour,max_relative_detour))
        )

#named tuple for model initiation. these are essentially the simulation settings
specs=(;
        map=map,
        route_matrix=RM,
        subspaces=:all_edges,
        routing=:lookup,
        speed_dict=speed_dict,
        seed=1
        )
specs=merge(specs,dispatcher)


#error function (to be minimized)
function f!(x,N,target,t0,specs,savetuple)
    if x < 0
        return 1.0
    end

    model=RP.get_model(;N_bus=N,ν=x/t0,specs...);

    #now comes the initial phase that will be skipped for the statistics
    RP.run!(model,dropped=max(INIT_DROPPED_PER_BUS*N,INIT_DROPPED_MIN),time=INIT_TIME*t0) #on average, every bus has dropped off x users + simulation time 2*y times bigger than avrg. direct distance.
    startindex=length(model.requests)

    #run actual simulation
    RP.run!(model,requested=startindex+max(FINAL_REQUESTED_PER_BUS*N,FINAL_REQUESTED_MIN))

    #evaluate
    sp=RP.served_percentage(model,startindex=startindex)
    (0.0<sp<1.0) ? push!(savetuple,(x,sp)) : nothing   # <---- save this function value,
    writedlm(savepath,savetuple)                       #       but only if it's neither 0 or 1

    return sp-target
end

function prnt(x)
    println(x)
    flush(stdout)   # <---- when run on cluster, you get live information from Julia, NOT only when job is done
end

TEST=false              # <---- checks if algorithm terminates on its own = finds root and confirms it

# initial guess is based on known power law. Can be improved depending on map. Keeping it simple here.
init=mapfactor*1.6*N^1.14

# previous initial guess was based on 80% target. correct this if target =/= 0.8
init=init*(0.8/target)^1.14

savetuple=Tuple[]   # <---- array of tuples that saves evaluated function values

while TEST==false && length(savetuple)<POINTS  # <---- run algorithm until it successfully terminates, or we have collected 'POINTS' function values
    A=init*(0.95+0.1*rand())
    prnt("################")
    prnt("N = $(N)")
    prnt("initial guess A = $(round(A;digits=4))")
    prnt("################\n")

	#find initial point pair (A,B) with function values (fA,fB)
    fA=f!(A,N,target,t0,specs,savetuple)
    prnt("error_A=$(round(fA;digits=4))")

    if fA>0
        prnt("A=$(round(A;digits=4)) too small, B must be larger.")
        best_positive=A
        best_negative=false
        B=A
        while best_negative==false
            B*=1.1
            prnt("Trying B=$(B)")
            fB=f!(B,N,target,t0,specs,savetuple)
            prnt("error_B=$(fB)")
            best_negative= fB<0 ? B : false
            fB>0 ? ((A,fA)=(B,fB)) : nothing
        end

    else
        prnt("A too large, B must be smaller.")
        B,fB=(A,fA)
        prnt("Setting B=$(round(A;digits=4)) to maintain the convention that A<B")
        best_negative=B
        best_positive=false
        while best_positive==false
            A/=1.1
            prnt("Trying A=$(round(A;digits=4))")
            fA=f!(A,N,target,t0,specs,savetuple)
            prnt("error_A=$(round(fA;digits=4))")
            best_positive= fA>0 ? A : false
            fA<0 ? ((B,fB)=(A,fA)) : nothing
            if A<1e-3
                prnt("This many buses don't seem to be able to serve $(percentage) percent of any demand. Exiting.")
                exit()
            end
        end
    end

    iteration=0
    while true  && length(savetuple)<POINTS-2         # <---- start iterative root-finding algorithm

        if (fA<0.02 && fB>-0.02) # <---- this is the termination criterion
            prnt("")
            prnt("breaking free after $(iteration) iterations with")
            prnt("A=$(round(A;digits=4)), error_A=$(round(fA;digits=4))")
            prnt("B=$(round(B;digits=4)), error_B=$(round(fB;digits=4))")
            break
        end

        iteration+=1

		# construct C for next function evaluation fC=f(C)
        C_mean=(A+B)/2
        C_secante=B-fB*(B-A)/(fB-fA)
	    writedlm(guesspath,C_secante);prnt("\n  ..writing $(round(C_secante;digits=4)) (current secante root) to guess_path.")
        if fA<0.01
            C=(2*C_secante+B)/3
        elseif fB>0.01
            C=(2*C_secante+A)/3
        else
            C=(2*C_secante+C_mean)/3
        end


        fC=f!(C,N,target,t0,specs,savetuple)

                prnt("iteration $(iteration)")
                prnt("A=$(round(A;digits=4)), error_A=$(round(fA;digits=4))")
                prnt("B=$(round(B;digits=4)), error_B=$(round(fB;digits=4))")
                prnt("C=$(round(C;digits=4)), error_C=$(round(fC;digits=4))")

        if fC>0           # <---- replace A or B with C such that one function value is positive, the other negative
            A,fA=(C,fC)
        else
            B,fB=(C,fC)
        end
    end

    C=B-fB*(B-A)/(fB-fA)    # <---- final secante-based guess after algorithm has terminated
	writedlm(guesspath,C);prnt("  ..writing $(round(C;digits=4)) (final secante root) to guess_path.")

    #find root of parabola
    fC=f!(C,N,target,t0,specs,savetuple)
    mat=[A^2 A 1;B^2 B 1;C^2 C 1]
    a,b,c=inv(mat)*[fA,fB,fC]
    p,q=(b/a,c/a)
    x1=-p/2-sqrt((p/2)^2-q)
    x2=-p/2+sqrt((p/2)^2-q)
    C= abs(x1-C)<abs(x2-C) ? x1 : x2
    writedlm(guesspath,C);prnt("  ..writing $(round(C;digits=4)) (root of parabola) to guess_path.")
                prnt("\nFINAL: $(round(C;digits=4))")

    #test served percentage
    fFINAL=f!(C,N,target,t0,specs,savetuple)

    global TEST=abs(fFINAL)<0.02
                prnt("TEST: served percentage = $(round(100*(fFINAL+target);digits=2))%\n\n\n")
    if TEST
      prnt("test worked.")
      writedlm(filepath,C)
    else
      global init=C
      prnt("test failed.")
    end
 end

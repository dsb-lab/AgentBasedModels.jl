"""
    struct Pseudopode <: Special

Struct containing the conditions for pseudopode like forces.
"""
struct Pseudopode <: Special
    neighbourCondition::Expr
    force::Expr
    updateChange::Expr
end

"""
    function addPseudopode!(agentModel::Model, f::Symbol, condition::String, force::String; randVar = Tuple{Symbol,String}[])

Add a pseudopode force.

**Examples**
```
m = Model()
addLocal!([:x,:y])

neighbourCondition = 
"
sqrt((x₁-x₂)^2+(y₁-y₂)^2) < 2.
"
force = 
"
f = sqrt((x₁-x₂)^2+(y₁-y₂)^2)*exp(-sqrt((x₁-x₂)^2+(y₁-y₂)^2))
"
updateChange = 
"
t + σPseudo
"
addPseudopode!(m,:f,condition,force,updateChange,randVar = [(:σPseudo,"uniform",1.,2.)])
```
"""
function addPseudopode!(agentModel::Model, var::Symbol, neighbourCondition::String, force::String, updateChange::String; randVar = Tuple{Symbol,String}[])
    
    #Checks
    neighbourCondition = Meta.parse(neighbourCondition)
    force = Meta.parse(force)
    updateChange = Meta.parse(updateChange)
    #Check if a Pseudopode force already exists
    if Pseudopode in [typeof(i) for i in agentModel.special]
        error("A pseudopode force is already present in the model. Only one pseudopode force can exist in the model.")
    end
    #Check var
    checkDeclared(agentModel, var)
    #Check random variables
    checkRandDeclared(agentModel, randVar)
    #Add necessary variables

    addIfNot!(agentModel.declaredIds, [:id_,:pseudoId_])
    addIfNot!(agentModel.inter,
    :(if pseudoId_₁ == id_₂; 
            $force
            $(Meta.parse(string(var,"₂"))) += -$(Meta.parse(string(var,"₁")))
        end)
    )
    push!(agentModel.declaredSymb["inter"],var)
    push!(agentModel.declaredSymb["local"],:pseudoT_)

    push!(agentModel.special, Pseudopode(neighbourCondition,changePseudoCondition,force,updateChange))

    return
end

"""
    function pseudopodeCompile(pseudopode::Pseudopode,agentModel::Model; platform::String)
"""
function pseudopodeCompile(pseudopode::Pseudopode,agentModel::Model; platform::String)

    comArgs = commonArguments(agentModel)
    cond = division.condition
    update = division.update
    
    #Initialize
    varDeclare = Expr[]
    fDeclare = Expr[]
    execute = Expr[]

    #Add variables
    push!(varDeclare, :(pseudoChoice_ = zeros(nMax_)))
    
    #Add function to declare
    ## Count number of neighbours loop
    algorithm = 
    string(:(
    if $(pseudopode.neighbourCondition)
        :nNPseudo_ += 1
    end
    ))
    inLoop1, arg = makeInLoop(agentModel,platform,algorithm)
    ## Assign a random neighbour loop
    algorithm = 
    string(:(
    if $(pseudopode.neighbourCondition)
        count -= 1             
        if count < 0
            pseudoId_ = nnic2_
            pseudoT_[ic1_] = $pseudopode.updateChange
            break
        end
    end
    ))
    inLoop2, arg = makeInLoop(agentModel,platform,algorithm)
    ## Create the function
    pushAdapt!(fDeclare, agentModel, platform,
    :(function pseudoCount($(comArgs...),$(arg...))
            @INFUNCTION_ for ic1_ in index_:stride_:N_
                if t > pseudoT_[ic1_]
                    nNPseudo = 0
                    $inLoop1
                    count = pseudoChoice_[ic1_]*nNPseudo
                    $inLoop2
                end
            end
        return
    end)
    )
    
    #Add execute functions
    pushAdapt!(execute, agentModel, platform, 
    :(rand!(pseudoChoice_))
    )
    pushAdapt!(execute, agentModel, platform, 
    :(@OUTFUNCTION pseudoCount($(comArgs...),$(arg...)))
    )

    return varDeclare,fDeclare,execute
end
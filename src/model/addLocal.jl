"""
    addLocal!(agentModel::Model, addvar::Symbol; updates="", randVar = Tuple{Symbol,String}[])

Add a local variable to the model with optional update rules.

# Examples
```
m = Model();

addLocal!(m,:x);
```
```
m = Model();
update = "
x= r #r is a random variable with μ=0. and σ=1.
"

addLocal!(m,:x,updates=update,randVar=[(:r,Normal,0.,1.)]);
```
"""
function addLocal!(agentModel::Model, addvar::Symbol; updates="", randVar = Tuple{Symbol,String}[])

    agentModel.evolve = needCompilation
    
    if updates != ""
        newUpdates = splitUpdating(updates)
        #Check repeated declarations
        varsUpdate = Meta.parse(newUpdates[1]).args[1]
        if length(newUpdates)>1
            error("Parameter ", addvar, " declared with more than one update rule.")
        end
        #Check updates belong to declared variables
        if varsUpdate != addvar
            error("Local parameter ", varsUpdate, " has been assigned an update rule but ", addvar, " it has been declared.")  
        end
    end

    if length(randVar) > 0
        randSymb = [i[1] for i in randVar]
        for i in randSymb #Check double declarations
            if length(findall(randSymb.==i))>1
                error("Random variable ", i, " declared more then once.")
            end
            #Check if already declared
            checkDeclared(agentModel,i)
        end

        #Check if distribution exists
        for i in randVar
            if findfirst(RESERVEDCALLS.==i[2])==nothing
                error("Probabily distribution assigned to random variable ", i[1], " ", i[2], " does not exist.")
            end
        end
    end
    
    globUpdates = copy(agentModel.loc)
    
    #Check vars except RESERVEDVARS
    checkDeclared(agentModel,addvar)
    
    if updates != ""
        append!(globUpdates,[Meta.parse(i) for i in newUpdates])
    end
        
    agentModel.loc = globUpdates
    push!(agentModel.declaredSymb["loc"],addvar)
    append!(agentModel.declaredRandSymb["locRand"],randVar)
    
    return
end

"""
    addLocal!(agentModel::Model, addvar::Array{Symbol}; updates="", randVar = Tuple{Symbol,String}[])

Add a local variable to the model with optional update rules.

# Examples
```
m = Model();

addGlobal!(m,[:x,:y]);
```

```
m = Model();
update = " #We update x but not y
x= r
"

addGlobal!(m,[:x,:y],updates=update,randVar=[(:r,Normal,0,1)]);
```
"""
function addLocal!(agentModel::Model, addvar::Array{Symbol}; updates="", randVar = Tuple{Symbol,String}[])

    agentModel.evolve = needCompilation
    
    #Check repeated declarations in addvar
    for i in addvar
        if length(findall(addvar.==i))>1
            error("Parameter ", i, " declared with more than once.")
        end
    end

    if updates != ""
        newUpdates = splitUpdating(updates)
        #Check repeated declarations
        varsUpdate = []
        for i in newUpdates
            push!(varsUpdate,Meta.parse(i).args[1])
        end
        for i in varsUpdate
            if length(findall(varsUpdate.==i))>1
                error("Parameter ", i, " declared with more than one update rule.")
            end
        end
        #Check updates belong to declared variables
        for i in varsUpdate
            if !(i in addvar)
                error("Local parameter ", i, " has been assigned an update rule but it has not been declared.")  
            end
        end
    end

    if length(randVar) > 0
        randSymb = [i[1] for i in randVar]
        for i in randSymb #Check double declarations
            if length(findall(randSymb.==i))>1
                error("Random variable ", i, " declared more then once.")
            end
            #Check if already declared
            checkDeclared(agentModel,i)
        end

        #Check if distribution exists
        for i in randVar
            if findfirst(RESERVEDCALLS.==i[2])==nothing
                error("Probabily distribution assigned to random variable ", i[1], " ", i[2], " does not exist.")
            end
        end
    end
    
    #Check vars except RESERVEDVARS
    for i in addvar
        checkDeclared(agentModel,i)
    end
    
    globUpdates = copy(agentModel.loc)    
    
    if updates != ""
        append!(globUpdates,[Meta.parse(i) for i in newUpdates])
    end
    
    agentModel.loc = globUpdates
    append!(agentModel.declaredSymb["loc"],addvar)
    append!(agentModel.declaredRandSymb["locRand"],randVar)
    
    return
end
# --------------------------------------------------------------------------------------------------
# Resolution

# by order of preference
algorithmes = ()

# descent methods
algorithmes = add(algorithmes, (:direct, :shooting, :descent, :bfgs, :bissection))
algorithmes = add(algorithmes, (:direct, :shooting, :descent, :bfgs, :backtracking))
algorithmes = add(algorithmes, (:direct, :shooting, :descent, :bfgs, :fixedstep))
algorithmes = add(algorithmes, (:direct, :shooting, :descent, :gradient, :bissection))
algorithmes = add(algorithmes, (:direct, :shooting, :descent, :gradient, :backtracking))
algorithmes = add(algorithmes, (:direct, :shooting, :descent, :gradient, :fixedstep))

function solve(prob::AbstractOptimalControlProblem, description...; kwargs...)
    method = getFullDescription(makeDescription(description...), algorithmes)
    # if no error before, then the method is correct: no need of else
    if :direct ∈ method
        if :shooting ∈ method
            return solve_by_udss(prob, method; kwargs...)
        end
    end
end

function clean_description(d::Description)
    return d\(:direct, :shooting)
end
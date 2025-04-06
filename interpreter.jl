using SQLite

"""
    Environment represents the runtime context for program execution.
    It holds variables, functions, and the current operation scope.
"""
mutable struct Environment
    variables::Dict{String, Any}
    parent::Union{Environment, Nothing}
    
    # Constructor for a new environment
    function Environment(parent::Union{Environment, Nothing}=nothing)
        new(Dict{String, Any}(), parent)
    end
end

"""
    lookup_variable(env, name) - Look up a variable in the environment chain
"""
function lookup_variable(env::Environment, name::String)
    if haskey(env.variables, name)
        return env.variables[name]
    elseif env.parent !== nothing
        return lookup_variable(env.parent, name)
    else
        error("Variable not found: $name")
    end
end

"""
    set_variable!(env, name, value) - Set a variable in the current environment
"""
function set_variable!(env::Environment, name::String, value::Any)
    env.variables[name] = value
end

"""
    get_operation_data(db, op_id) - Get all data associated with an operation
"""
function get_operation_data(db::SQLite.DB, op_id::Int)
    query = "SELECT key, value FROM data WHERE operation_id = ?"
    stmt = SQLite.prepare(db, query)
    result = SQLite.execute(stmt, [op_id])
    return Dict(row[:key] => row[:value] for row in result)
end

"""
    evaluate_value(env, value) - Evaluate a value which might be a variable reference
"""
function evaluate_value(env::Environment, value::String)
    # If value starts with $, it's a variable reference
    if startswith(value, "\$")
        var_name = value[2:end]
        return lookup_variable(env, var_name)
    else
        # Try to parse as a number or boolean, otherwise treat as string
        try
            # Try integer
            return parse(Int, value)
        catch
            try
                # Try float
                return parse(Float64, value)
            catch
                # Check for boolean
                if value == "true"
                    return true
                elseif value == "false"
                    return false
                else
                    # Return as string
                    return value
                end
            end
        end
    end
end

"""
    get_child_operations(db, parent_id) - Get all child operations of a parent operation
"""
function get_child_operations(db::SQLite.DB, parent_id::Union{Int, Nothing})
    if parent_id === nothing
        query = "SELECT id, opcode FROM operations WHERE parent_id IS NULL ORDER BY sequence"
    else
        query = "SELECT id, opcode FROM operations WHERE parent_id = ? ORDER BY sequence"
        stmt = SQLite.prepare(db, query)
        return SQLite.execute(stmt, [parent_id])
    end
    stmt = SQLite.prepare(db, query)
    return SQLite.execute(stmt)
end

"""
    execute_operation(db, env, op_id, opcode) - Execute a single operation
"""
function execute_operation(db::SQLite.DB, env::Environment, op_id::Int, opcode::String)
    data = get_operation_data(db, op_id)
    
    if opcode == "assign"
        var_name = data["var_name"]
        value = evaluate_value(env, data["value"])
        set_variable!(env, var_name, value)
        
    elseif opcode == "print"
        value = evaluate_value(env, data["value"])
        println(value)
        
    elseif opcode == "add"
        left = evaluate_value(env, data["left"])
        right = evaluate_value(env, data["right"])
        result = left + right
        if haskey(data, "result")
            set_variable!(env, data["result"], result)
        end
        return result
        
    elseif opcode == "sub"
        left = evaluate_value(env, data["left"])
        right = evaluate_value(env, data["right"])
        result = left - right
        if haskey(data, "result")
            set_variable!(env, data["result"], result)
        end
        return result
        
    elseif opcode == "mul"
        left = evaluate_value(env, data["left"])
        right = evaluate_value(env, data["right"])
        result = left * right
        if haskey(data, "result")
            set_variable!(env, data["result"], result)
        end
        return result
        
    elseif opcode == "div"
        left = evaluate_value(env, data["left"])
        right = evaluate_value(env, data["right"])
        result = left / right
        if haskey(data, "result")
            set_variable!(env, data["result"], result)
        end
        return result
        
    elseif opcode == "eq"
        left = evaluate_value(env, data["left"])
        right = evaluate_value(env, data["right"])
        result = left == right
        if haskey(data, "result")
            set_variable!(env, data["result"], result)
        end
        return result
        
    elseif opcode == "lt"
        left = evaluate_value(env, data["left"])
        right = evaluate_value(env, data["right"])
        result = left < right
        if haskey(data, "result")
            set_variable!(env, data["result"], result)
        end
        return result
        
    elseif opcode == "gt"
        left = evaluate_value(env, data["left"])
        right = evaluate_value(env, data["right"])
        result = left > right
        if haskey(data, "result")
            set_variable!(env, data["result"], result)
        end
        return result
        
    elseif opcode == "if"
        condition = evaluate_value(env, data["condition"])
        if condition
            # Execute the body of the if statement
            child_env = Environment(env)
            execute_block(db, child_env, op_id)
        else
            # Look for an else block
            query = "SELECT id FROM operations WHERE parent_id = ? AND opcode = 'else' ORDER BY sequence LIMIT 1"
            stmt = SQLite.prepare(db, query)
            result = SQLite.execute(stmt, [op_id])
            for row in result
                child_env = Environment(env)
                execute_block(db, child_env, row[:id])
                break
            end
        end
        
    elseif opcode == "else"
        # This is handled by the if statement
        
    elseif opcode == "while"
        condition = evaluate_value(env, data["condition"])
        while condition
            # Execute the body of the while loop
            child_env = Environment(env)
            execute_block(db, child_env, op_id)
            
            # Re-evaluate the condition
            condition = evaluate_value(env, data["condition"])
        end
        
    elseif opcode == "for"
        iterator = data["iterator"]
        collection = evaluate_value(env, data["collection"])
        
        for item in collection
            # Create a new environment for each iteration
            child_env = Environment(env)
            set_variable!(child_env, iterator, item)
            
            # Execute the body of the for loop
            execute_block(db, child_env, op_id)
        end
        
    elseif opcode == "function"
        # Store the function definition in the environment
        name = data["name"]
        params = data["params"]
        env.variables[name] = Dict(
            "params" => split(params, ","),
            "body_id" => op_id
        )
        
    elseif opcode == "call"
        name = data["name"]
        args_str = data["args"]
        args = [evaluate_value(env, arg) for arg in split(args_str, ",")]
        
        # Look up the function
        func = lookup_variable(env, name)
        
        # Create a new environment for the function call
        func_env = Environment(env)
        
        # Bind arguments to parameters
        for (param, arg) in zip(func["params"], args)
            set_variable!(func_env, param, arg)
        end
        
        # Execute the function body
        result = execute_block(db, func_env, func["body_id"])
        return result
        
    elseif opcode == "return"
        value = evaluate_value(env, data["value"])
        return value
    end
    
    return nothing
end

"""
    execute_block(db, env, parent_id) - Execute a block of operations
"""
function execute_block(db::SQLite.DB, env::Environment, parent_id::Int)
    operations = get_child_operations(db, parent_id)
    result = nothing
    
    for op in operations
        op_id = op[:id]
        opcode = op[:opcode]
        
        # Skip the 'else' opcode as it's handled by the if statement
        if opcode == "else"
            continue
        end
        
        result = execute_operation(db, env, op_id, opcode)
        
        # If we got a return value, bubble it up
        if opcode == "return"
            return result
        end
    end
    
    return result
end

"""
    run_program(db_path) - Run a program from a database file
"""
function run_program(db_path::String)
    db = SQLite.DB(db_path)
    env = Environment()
    
    # Get all top-level operations (those with no parent)
    operations = get_child_operations(db, nothing)
    
    for op in operations
        op_id = op[:id]
        opcode = op[:opcode]
        execute_operation(db, env, op_id, opcode)
    end
end

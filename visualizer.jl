using SQLite

"""
    visualize_program(db_path, output_file=nothing) - Create a visualization of a program
"""
function visualize_program(db_path::String, output_file::Union{String, Nothing}=nothing)
    db = SQLite.DB(db_path)
    
    # Helper function to get operation details
    function get_operation_details(op_id)
        # Get opcode
        query = "SELECT opcode FROM operations WHERE id = ?"
        stmt = SQLite.prepare(db, query)
        result = SQLite.execute(stmt, [op_id])
        opcode = nothing
        for row in result
            opcode = row[:opcode]
        end
        
        # Get data
        query = "SELECT key, value FROM data WHERE operation_id = ?"
        stmt = SQLite.prepare(db, query)
        result = SQLite.execute(stmt, [op_id])
        data = Dict{String, String}()
        for row in result
            data[row[:key]] = row[:value]
        end
        
        return opcode, data
    end
    
    # Generate a formatted string representation of an operation and its data
    function format_operation(op_id, level=0)
        opcode, data = get_operation_details(op_id)
        indent = "  " ^ level
        
        # Format the operation
        op_str = "$indent$opcode"
        
        # Add data
        if !isempty(data)
            data_str = join(["$k: $v" for (k, v) in data], ", ")
            op_str *= " [$data_str]"
        end
        
        # Get child operations
        query = "SELECT id, sequence FROM operations WHERE parent_id = ? ORDER BY sequence"
        stmt = SQLite.prepare(db, query)
        result = SQLite.execute(stmt, [op_id])
        
        children = []
        for row in result
            push!(children, row[:id])
        end
        
        # Format children
        if !isempty(children)
            op_str *= " {"
            if length(children) > 1
                op_str *= "\n"
            end
            
            for (i, child) in enumerate(children)
                child_str = format_operation(child, level + 1)
                op_str *= child_str
                if i < length(children)
                    op_str *= "\n"
                end
            end
            
            if length(children) > 1
                op_str *= "\n$indent"
            end
            op_str *= "}"
        end
        
        return op_str
    end
    
    # Get all top-level operations
    query = "SELECT id, sequence FROM operations WHERE parent_id IS NULL ORDER BY sequence"
    stmt = SQLite.prepare(db, query)
    result = SQLite.execute(stmt)
    
    operations = []
    for row in result
        push!(operations, row[:id])
    end
    
    # Generate the visualization
    visualization = "Program Visualization\n====================\n\n"
    for (i, op) in enumerate(operations)
        visualization *= format_operation(op)
        if i < length(operations)
            visualization *= "\n\n"
        end
    end
    
    # Output the visualization
    if output_file !== nothing
        open(output_file, "w") do f
            write(f, visualization)
        end
        println("Visualization saved to $output_file")
    else
        println(visualization)
    end
end

# Run the visualizer if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) > 0
        if length(ARGS) > 1
            visualize_program(ARGS[1], ARGS[2])
        else
            visualize_program(ARGS[1])
        end
    else
        println("Usage: julia visualizer.jl db_path [output_file]")
    end
end

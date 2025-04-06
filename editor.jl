using SQLite
using REPL
using REPL.TerminalMenus

"""
    EditorState holds the current state of the editor.
"""
mutable struct EditorState
    db::SQLite.DB
    current_parent_id::Union{Int, Nothing}
    current_operation::Union{Int, Nothing}
    modified::Bool
    
    function EditorState(db_path::String)
        db = SQLite.DB(db_path)
        new(db, nothing, nothing, false)
    end
end

"""
    create_new_operation(state, opcode) - Create a new operation in the database
"""
function create_new_operation(state::EditorState, opcode::String)
    # Get the next sequence number
    sequence = 1
    if state.current_parent_id !== nothing
        query = "SELECT MAX(sequence) as max_seq FROM operations WHERE parent_id = ?"
        stmt = SQLite.prepare(state.db, query)
        result = SQLite.execute(stmt, [state.current_parent_id])
        for row in result
            if row[:max_seq] !== nothing
                sequence = row[:max_seq] + 1
            end
        end
    end
    
    # Insert the new operation
    query = "INSERT INTO operations (opcode, parent_id, sequence) VALUES (?, ?, ?)"
    stmt = SQLite.prepare(state.db, query)
    SQLite.execute(stmt, [opcode, state.current_parent_id, sequence])
    
    # Get the id of the new operation
    query = "SELECT last_insert_rowid() as id"
    stmt = SQLite.prepare(state.db, query)
    result = SQLite.execute(stmt)
    op_id = nothing
    for row in result
        op_id = row[:id]
    end
    
    state.current_operation = op_id
    state.modified = true
    
    return op_id
end

"""
    add_operation_data(state, op_id, key, value) - Add data to an operation
"""
function add_operation_data(state::EditorState, op_id::Int, key::String, value::String)
    query = "INSERT INTO data (operation_id, key, value) VALUES (?, ?, ?)"
    stmt = SQLite.prepare(state.db, query)
    SQLite.execute(stmt, [op_id, key, value])
    state.modified = true
end

"""
    get_operation_data(state, op_id) - Get data for an operation
"""
function get_operation_data(state::EditorState, op_id::Int)
    query = "SELECT key, value FROM data WHERE operation_id = ?"
    stmt = SQLite.prepare(state.db, query)
    result = SQLite.execute(stmt, [op_id])
    return Dict(row[:key] => row[:value] for row in result)
end

"""
    get_operation_details(state, op_id) - Get operation code and data
"""
function get_operation_details(state::EditorState, op_id::Int)
    query = "SELECT opcode FROM operations WHERE id = ?"
    stmt = SQLite.prepare(state.db, query)
    result = SQLite.execute(stmt, [op_id])
    opcode = nothing
    for row in result
        opcode = row[:opcode]
    end
    
    data = get_operation_data(state, op_id)
    
    return opcode, data
end

"""
    list_operations(state) - List all operations at the current level
"""
function list_operations(state::EditorState)
    if state.current_parent_id === nothing
        query = "SELECT id, opcode, sequence FROM operations WHERE parent_id IS NULL ORDER BY sequence"
        stmt = SQLite.prepare(state.db, query)
        result = SQLite.execute(stmt)
    else
        query = "SELECT id, opcode, sequence FROM operations WHERE parent_id = ? ORDER BY sequence"
        stmt = SQLite.prepare(state.db, query)
        result = SQLite.execute(stmt, [state.current_parent_id])
    end
    
    operations = []
    for row in result
        push!(operations, (id=row[:id], opcode=row[:opcode], sequence=row[:sequence]))
    end
    
    return operations
end

"""
    move_operation(state, op_id, new_sequence) - Change the sequence of an operation
"""
function move_operation(state::EditorState, op_id::Int, new_sequence::Int)
    # Get the current sequence
    query = "SELECT sequence FROM operations WHERE id = ?"
    stmt = SQLite.prepare(state.db, query)
    result = SQLite.execute(stmt, [op_id])
    old_sequence = nothing
    for row in result
        old_sequence = row[:sequence]
    end
    
    if old_sequence === nothing
        return
    end
    
    # Update the sequence
    query = "UPDATE operations SET sequence = ? WHERE id = ?"
    stmt = SQLite.prepare(state.db, query)
    SQLite.execute(stmt, [new_sequence, op_id])
    
    # Reorder operations to avoid sequence conflicts
    if state.current_parent_id === nothing
        query = "SELECT id, sequence FROM operations WHERE parent_id IS NULL ORDER BY sequence"
        stmt = SQLite.prepare(state.db, query)
        result = SQLite.execute(stmt)
    else
        query = "SELECT id, sequence FROM operations WHERE parent_id = ? ORDER BY sequence"
        stmt = SQLite.prepare(state.db, query)
        result = SQLite.execute(stmt, [state.current_parent_id])
    end
    
    operations = []
    for row in result
        push!(operations, (id=row[:id], sequence=row[:sequence]))
    end
    
    # Reassign sequences to avoid gaps and duplicates
    for (i, op) in enumerate(operations)
        query = "UPDATE operations SET sequence = ? WHERE id = ?"
        stmt = SQLite.prepare(state.db, query)
        SQLite.execute(stmt, [i, op.id])
    end
    
    state.modified = true
end

"""
    delete_operation(state, op_id) - Delete an operation and its children
"""
function delete_operation(state::EditorState, op_id::Int)
    # First, recursively delete all children
    query = "SELECT id FROM operations WHERE parent_id = ?"
    stmt = SQLite.prepare(state.db, query)
    result = SQLite.execute(stmt, [op_id])
    
    for row in result
        delete_operation(state, row[:id])
    end
    
    # Delete associated data
    query = "DELETE FROM data WHERE operation_id = ?"
    stmt = SQLite.prepare(state.db, query)
    SQLite.execute(stmt, [op_id])
    
    # Delete the operation itself
    query = "DELETE FROM operations WHERE id = ?"
    stmt = SQLite.prepare(state.db, query)
    SQLite.execute(stmt, [op_id])
    
    if state.current_operation == op_id
        state.current_operation = nothing
    end
    
    state.modified = true
end

"""
    navigate_to_parent(state) - Navigate to the parent of the current level
"""
function navigate_to_parent(state::EditorState)
    if state.current_parent_id === nothing
        println("Already at the root level")
        return
    end
    
    # Get the parent's parent
    query = "SELECT parent_id FROM operations WHERE id = ?"
    stmt = SQLite.prepare(state.db, query)
    result = SQLite.execute(stmt, [state.current_parent_id])
    
    new_parent = nothing
    for row in result
        new_parent = row[:parent_id]
    end
    
    state.current_parent_id = new_parent
    state.current_operation = state.current_parent_id
end

"""
    navigate_to_children(state, op_id) - Navigate to the children of an operation
"""
function navigate_to_children(state::EditorState, op_id::Int)
    state.current_parent_id = op_id
    state.current_operation = nothing
end

"""
    save_program(state, file_path) - Save the program to a file
"""
function save_program(state::EditorState, file_path::String)
    if state.modified
        SQLite.execute(state.db, "VACUUM")
        state.modified = false
    end
    
    # If the database is in memory, save it to disk
    if file_path != ":memory:"
        # Create a backup
        dest_db = SQLite.DB(file_path)
        SQLite.backup(dest_db, state.db)
        SQLite.close(dest_db)
    end
end

"""
    edit_operation_menu(state, op_id) - Edit an operation's data
"""
function edit_operation_menu(state::EditorState, op_id::Int)
    opcode, data = get_operation_details(state, op_id)
    
    while true
        println("\nEditing operation: $opcode (ID: $op_id)")
        println("Current data:")
        for (key, value) in data
            println("  $key: $value")
        end
        
        println("\nOptions:")
        println("  1. Add/Edit data field")
        println("  2. Remove data field")
        println("  3. Back to main menu")
        
        print("Enter your choice: ")
        choice = readline()
        
        if choice == "1"
            print("Enter key: ")
            key = readline()
            print("Enter value: ")
            value = readline()
            
            # Delete existing value if it exists
            query = "DELETE FROM data WHERE operation_id = ? AND key = ?"
            stmt = SQLite.prepare(state.db, query)
            SQLite.execute(stmt, [op_id, key])
            
            # Add the new value
            add_operation_data(state, op_id, key, value)
            
            # Update the local data
            data[key] = value
            
        elseif choice == "2"
            if isempty(data)
                println("No data to remove")
                continue
            end
            
            keys = collect(keys(data))
            menu = RadioMenu(keys)
            choice = request("Select field to remove:", menu)
            
            if choice != -1
                key = keys[choice]
                query = "DELETE FROM data WHERE operation_id = ? AND key = ?"
                stmt = SQLite.prepare(state.db, query)
                SQLite.execute(stmt, [op_id, key])
                
                # Update the local data
                delete!(data, key)
                state.modified = true
            end
            
        elseif choice == "3"
            break
        end
    end
end

"""
    add_operation_menu(state) - Menu for adding a new operation
"""
function add_operation_menu(state::EditorState)
    opcodes = [
        "assign", "print", "add", "sub", "mul", "div", "eq", "lt", "gt",
        "if", "else", "while", "for", "break", "continue", "return",
        "function", "call"
    ]
    
    menu = RadioMenu(opcodes)
    choice = request("Select operation type:", menu)
    
    if choice != -1
        opcode = opcodes[choice]
        op_id = create_new_operation(state, opcode)
        
        # Add data fields based on the opcode
        if opcode == "assign"
            print("Enter variable name: ")
            var_name = readline()
            print("Enter value: ")
            value = readline()
            
            add_operation_data(state, op_id, "var_name", var_name)
            add_operation_data(state, op_id, "value", value)
            
        elseif opcode == "print"
            print("Enter value to print: ")
            value = readline()
            add_operation_data(state, op_id, "value", value)
            
        elseif opcode in ["add", "sub", "mul", "div", "eq", "lt", "gt"]
            print("Enter left operand: ")
            left = readline()
            print("Enter right operand: ")
            right = readline()
            print("Enter result variable (optional): ")
            result = readline()
            
            add_operation_data(state, op_id, "left", left)
            add_operation_data(state, op_id, "right", right)
            if !isempty(result)
                add_operation_data(state, op_id, "result", result)
            end
            
        elseif opcode in ["if", "while"]
            print("Enter condition: ")
            condition = readline()
            add_operation_data(state, op_id, "condition", condition)
            
        elseif opcode == "for"
            print("Enter iterator variable: ")
            iterator = readline()
            print("Enter collection: ")
            collection = readline()
            
            add_operation_data(state, op_id, "iterator", iterator)
            add_operation_data(state, op_id, "collection", collection)
            
        elseif opcode == "function"
            print("Enter function name: ")
            name = readline()
            print("Enter parameters (comma-separated): ")
            params = readline()
            
            add_operation_data(state, op_id, "name", name)
            add_operation_data(state, op_id, "params", params)
            
        elseif opcode == "call"
            print("Enter function name: ")
            name = readline()
            print("Enter arguments (comma-separated): ")
            args = readline()
            
            add_operation_data(state, op_id, "name", name)
            add_operation_data(state, op_id, "args", args)
            
        elseif opcode == "return"
            print("Enter return value: ")
            value = readline()
            add_operation_data(state, op_id, "value", value)
        end
        
        # If this is a block operation, prompt to edit its children
        if opcode in ["if", "else", "while", "for", "function"]
            println("Operation added. You can now add nested operations.")
            print("Do you want to enter the block now? (y/n): ")
            if lowercase(readline()) == "y"
                navigate_to_children(state, op_id)
            end
        end
    end
end

"""
    main_menu(state) - Main editor menu
"""
function main_menu(state::EditorState)
    while true
        # Display current location
        if state.current_parent_id === nothing
            println("\n--- Root Level ---")
        else
            opcode, _ = get_operation_details(state, state.current_parent_id)
            println("\n--- Inside $opcode (ID: $(state.current_parent_id)) ---")
        end
        
        # List operations at the current level
        operations = list_operations(state)
        if !isempty(operations)
            println("Operations:")
            for op in operations
                println("  $(op.sequence). $(op.opcode) (ID: $(op.id))")
            end
        else
            println("No operations at this level.")
        end
        
        println("\nOptions:")
        println("  1. Add operation")
        println("  2. Edit operation")
        println("  3. Move operation")
        println("  4. Delete operation")
        println("  5. View operation details")
        println("  6. Enter block")
        println("  7. Go up one level")
        println("  8. Save program")
        println("  9. Run program")
        println("  0. Quit")
        
        print("Enter your choice: ")
        choice = readline()
        
        if choice == "1"
            add_operation_menu(state)
            
        elseif choice == "2"
            if isempty(operations)
                println("No operations to edit.")
                continue
            end
            
            op_items = ["$(op.sequence). $(op.opcode) (ID: $(op.id))" for op in operations]
            menu = RadioMenu(op_items)
            choice = request("Select operation to edit:", menu)
            
            if choice != -1
                edit_operation_menu(state, operations[choice].id)
            end
            
        elseif choice == "3"
            if isempty(operations)
                println("No operations to move.")
                continue
            end
            
            op_items = ["$(op.sequence). $(op.opcode) (ID: $(op.id))" for op in operations]
            menu = RadioMenu(op_items)
            choice = request("Select operation to move:", menu)
            
            if choice != -1
                print("Enter new position (1-$(length(operations))): ")
                new_pos = tryparse(Int, readline())
                
                if new_pos !== nothing && new_pos >= 1 && new_pos <= length(operations)
                    move_operation(state, operations[choice].id, new_pos)
                else
                    println("Invalid position.")
                end
            end
            
        elseif choice == "4"
            if isempty(operations)
                println("No operations to delete.")
                continue
            end
            
            op_items = ["$(op.sequence). $(op.opcode) (ID: $(op.id))" for op in operations]
            menu = RadioMenu(op_items)
            choice = request("Select operation to delete:", menu)
            
            if choice != -1
                print("Are you sure you want to delete this operation? (y/n): ")
                if lowercase(readline()) == "y"
                    delete_operation(state, operations[choice].id)
                end
            end
            
        elseif choice == "5"
            if isempty(operations)
                println("No operations to view.")
                continue
            end
            
            op_items = ["$(op.sequence). $(op.opcode) (ID: $(op.id))" for op in operations]
            menu = RadioMenu(op_items)
            choice = request("Select operation to view:", menu)
            
            if choice != -1
                op_id = operations[choice].id
                opcode, data = get_operation_details(state, op_id)
                
                println("\nOperation Details:")
                println("  ID: $op_id")
                println("  Opcode: $opcode")
                println("  Data:")
                for (key, value) in data
                    println("    $key: $value")
                end
                
                print("\nPress Enter to continue...")
                readline()
            end
            
        elseif choice == "6"
            if isempty(operations)
                println("No operations to enter.")
                continue
            end
            
            op_items = ["$(op.sequence). $(op.opcode) (ID: $(op.id))" for op in operations]
            menu = RadioMenu(op_items)
            choice = request("Select operation to enter:", menu)
            
            if choice != -1
                op_id = operations[choice].id
                opcode, _ = get_operation_details(state, op_id)
                
                if opcode in ["if", "else", "while", "for", "function"]
                    navigate_to_children(state, op_id)
                else
                    println("This operation does not have a body to enter.")
                end
            end
            
        elseif choice == "7"
            navigate_to_parent(state)
            
        elseif choice == "8"
            print("Enter file path to save (press Enter for default): ")
            file_path = readline()
            
            if isempty(file_path)
                file_path = "program.db"
            end
            
            save_program(state, file_path)
            println("Program saved to $file_path")
            
        elseif choice == "9"
            # Run the program
            if state.modified
                print("Program has been modified. Save first? (y/n): ")
                if lowercase(readline()) == "y"
                    print("Enter file path to save (press Enter for default): ")
                    file_path = readline()
                    
                    if isempty(file_path)
                        file_path = "program.db"
                    end
                    
                    save_program(state, file_path)
                    println("Program saved to $file_path")
                    
                    # Run the saved program
                    println("\nRunning program...")
                    include("interpreter.jl")
                    run_program(file_path)
                end
            else
                # Run the program directly
                println("\nRunning program...")
                include("interpreter.jl")
                run_program(state.db.file)
            end
            
        elseif choice == "0"
            if state.modified
                print("Program has been modified. Save before quitting? (y/n): ")
                if lowercase(readline()) == "y"
                    print("Enter file path to save (press Enter for default): ")
                    file_path = readline()
                    
                    if isempty(file_path)
                        file_path = "program.db"
                    end
                    
                    save_program(state, file_path)
                    println("Program saved to $file_path")
                end
            end
            
            break
        end
    end
end

"""
    editor_main() - Main entry point for the editor
"""
function editor_main()
    println("JuliaSQLite Program Editor")
    println("==========================")
    
    print("Enter file path to open (or press Enter for new program): ")
    file_path = readline()
    
    if isempty(file_path)
        # Create a new program in memory
        state = EditorState(":memory:")
        
        # Initialize the database schema
        include("schema.jl")
        initialize_schema(state.db)
    else
        # Open an existing program
        if isfile(file_path)
            state = EditorState(file_path)
        else
            println("File not found. Creating a new program.")
            state = EditorState(":memory:")
            include("schema.jl")
            initialize_schema(state.db)
        end
    end
    
    main_menu(state)
end

# Run the editor if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    editor_main()
end
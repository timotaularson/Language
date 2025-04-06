using SQLite

"""
    create_factorial_program(db_path) - Create a sample factorial program
"""
function create_factorial_program(db_path::String)
    # Create a new database
    db = SQLite.DB(db_path)
    
    # Initialize the schema
    include("schema.jl")
    initialize_schema(db)
    
    # Helper function to insert an operation
    function insert_operation(opcode, parent_id, sequence)
        query = "INSERT INTO operations (opcode, parent_id, sequence) VALUES (?, ?, ?)"
        stmt = SQLite.prepare(db, query)
        SQLite.execute(stmt, [opcode, parent_id, sequence])
        
        # Get the inserted id
        query = "SELECT last_insert_rowid() as id"
        stmt = SQLite.prepare(db, query)
        result = SQLite.execute(stmt)
        id = nothing
        for row in result
            id = row[:id]
        end
        
        return id
    end
    
    # Helper function to insert operation data
    function insert_data(operation_id, key, value)
        query = "INSERT INTO data (operation_id, key, value) VALUES (?, ?, ?)"
        stmt = SQLite.prepare(db, query)
        SQLite.execute(stmt, [operation_id, key, value])
    end
    
    # Create the main program structure
    
    # 1. Print welcome message
    op1 = insert_operation("print", nothing, 1)
    insert_data(op1, "value", "\"Welcome to Factorial Calculator!\"")
    
    # 2. Define the factorial function
    op2 = insert_operation("function", nothing, 2)
    insert_data(op2, "name", "factorial")
    insert_data(op2, "params", "n")
    
    # 3. Inside factorial function: if n <= 1 return 1
    op3 = insert_operation("if", op2, 1)
    insert_data(op3, "condition", "\$n <= 1")
    
    op4 = insert_operation("return", op3, 1)
    insert_data(op4, "value", "1")
    
    # 4. Inside factorial function: else return n * factorial(n-1)
    op5 = insert_operation("else", op3, 2)
    
    # 5. Inside else: calculate n-1
    op6 = insert_operation("sub", op5, 1)
    insert_data(op6, "left", "\$n")
    insert_data(op6, "right", "1")
    insert_data(op6, "result", "n_minus_1")
    
    # 6. Inside else: call factorial(n-1)
    op7 = insert_operation("call", op5, 2)
    insert_data(op7, "name", "factorial")
    insert_data(op7, "args", "\$n_minus_1")
    insert_data(op7, "result", "fact_n_minus_1")
    
    # 7. Inside else: calculate n * factorial(n-1)
    op8 = insert_operation("mul", op5, 3)
    insert_data(op8, "left", "\$n")
    insert_data(op8, "right", "\$fact_n_minus_1")
    insert_data(op8, "result", "result")
    
    # 8. Inside else: return the result
    op9 = insert_operation("return", op5, 4)
    insert_data(op9, "value", "\$result")
    
    # 9. Assign a test value to calculate
    op10 = insert_operation("assign", nothing, 3)
    insert_data(op10, "var_name", "test_value")
    insert_data(op10, "value", "5")
    
    # 10. Call the factorial function
    op11 = insert_operation("call", nothing, 4)
    insert_data(op11, "name", "factorial")
    insert_data(op11, "args", "\$test_value")
    insert_data(op11, "result", "factorial_result")
    
    # 11. Print the result
    op12 = insert_operation("print", nothing, 5)
    insert_data(op12, "value", "\"Factorial of 5 is: \"")
    
    op13 = insert_operation("print", nothing, 6)
    insert_data(op13, "value", "\$factorial_result")
    
    println("Factorial program created at $db_path")
end

# Create the sample program if run directly
if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) > 0
        create_factorial_program(ARGS[1])
    else
        create_factorial_program("factorial.db")
    end
end

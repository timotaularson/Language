#!/usr/bin/env julia

# Main application for JuliaSQLite Language System

function show_banner()
    println("""
    ╔════════════════════════════════════════════════╗
    ║                                                ║
    ║            JuliaSQLite Language                ║
    ║                                                ║
    ╚════════════════════════════════════════════════╝
    """)
end

function show_help()
    println("""
    Usage:
        julia main.jl [command] [options]
        
    Commands:
        new     Create a new program
        edit    Edit an existing program
        run     Run a program
        help    Show this help message
        
    Options:
        -f, --file FILE    Specify the program file
    """)
end

function parse_args()
    args = Dict{String, Any}()
    
    if length(ARGS) == 0
        args["command"] = "help"
        return args
    end
    
    args["command"] = ARGS[1]
    args["file"] = nothing
    
    i = 2
    while i <= length(ARGS)
        if ARGS[i] in ["-f", "--file"] && i < length(ARGS)
            args["file"] = ARGS[i+1]
            i += 2
        else
            i += 1
        end
    end
    
    return args
end

function main()
    show_banner()
    
    args = parse_args()
    
    if args["command"] == "help"
        show_help()
        return
    end
    
    if args["command"] == "new"
        # Create a new program
        if args["file"] === nothing
            println("Error: File path not specified.")
            println("Use -f or --file to specify the output file.")
            return
        end
        
        # Initialize a new program
        include("schema.jl")
        db = SQLite.DB(args["file"])
        initialize_schema(db)
        
        println("New program created at $(args["file"])")
        
        # Ask if the user wants to edit the program
        print("Do you want to edit the program now? (y/n): ")
        if lowercase(readline()) == "y"
            include("editor.jl")
            state = EditorState(args["file"])
            main_menu(state)
        end
        
    elseif args["command"] == "edit"
        # Edit an existing program
        if args["file"] === nothing
            println("Error: File path not specified.")
            println("Use -f or --file to specify the program file.")
            return
        end
        
        # Check if the file exists
        if !isfile(args["file"])
            println("Error: File not found.")
            return
        end
        
        # Open the editor
        include("editor.jl")
        state = EditorState(args["file"])
        main_menu(state)
        
    elseif args["command"] == "run"
        # Run a program
        if args["file"] === nothing
            println("Error: File path not specified.")
            println("Use -f or --file to specify the program file.")
            return
        end
        
        # Check if the file exists
        if !isfile(args["file"])
            println("Error: File not found.")
            return
        end
        
        # Run the program
        include("interpreter.jl")
        println("Running program...")
        run_program(args["file"])
        
    else
        println("Unknown command: $(args["command"])")
        show_help()
    end
end

# Run the main function
main()

# JuliaSQLite Programming System

A programming language, environment, and editor created using Julia and SQLite.jl. Programs written in this language are saved as opcodes and data in separate rows in a SQLite database. A parent and sequence column allow for nesting and sequencing of operations.

## Features

- Simple stack-based language with support for variables, conditionals, loops, and functions
- Programs stored in a SQLite database for persistence and easy manipulation
- Interactive editor for creating and modifying programs
- Visualizer for representing programs in a human-readable format
- Interpreter for executing programs

## Requirements

- Julia 1.6 or higher
- SQLite.jl package
- REPL.jl package (included with Julia)

## Installation

1. Clone this repository:
   ```
   git clone https://github.com/yourusername/juliasqlite-lang.git
   cd juliasqlite-lang
   ```

2. Install required packages:
   ```julia
   using Pkg
   Pkg.add("SQLite")
   ```

## Usage

### Main Application

The `main.jl` script provides a command-line interface to create, edit, and run programs:

```bash
# Create a new program
julia main.jl new -f my_program.db

# Edit an existing program
julia main.jl edit -f my_program.db

# Run a program
julia main.jl run -f my_program.db

# Show help
julia main.jl help
```

### Sample Program

The `sample-program.jl` script creates a sample factorial program:

```bash
# Create a factorial program
julia sample-program.jl factorial.db
```

### Program Visualizer

The `visualizer.jl` script creates a human-readable representation of a program:

```bash
# Visualize a program (output to console)
julia visualizer.jl my_program.db

# Visualize a program (output to file)
julia visualizer.jl my_program.db visualization.txt
```

## Language Specification

The language is based on operations (opcodes) and their associated data. Each operation can have child operations, which are executed in sequence. The language supports:

- Variables and basic arithmetic operations
- Conditionals (if/else)
- Loops (while/for)
- Functions with parameters and return values

See the `language-spec.md` file for a complete specification.

## Database Schema

Programs are stored in a SQLite database with two main tables:

1. `operations` - Stores the opcodes, parent relationships, and sequence
2. `data` - Stores parameters for each operation

See the `database-schema.sql` file for the complete schema.

## Example

Here's an example of a factorial function in the language:

```
function [name: factorial, params: n] {
  if [condition: $n <= 1] {
    return [value: 1]
  }
  else {
    sub [left: $n, right: 1, result: n_minus_1]
    call [name: factorial, args: $n_minus_1, result: fact_n_minus_1]
    mul [left: $n, right: $fact_n_minus_1, result: result]
    return [value: $result]
  }
}

assign [var_name: test_value, value: 5]
call [name: factorial, args: $test_value, result: factorial_result]
print [value: "Factorial of 5 is: "]
print [value: $factorial_result]
```

Running this program will output:
```
Welcome to Factorial Calculator!
Factorial of 5 is: 
120
```

## Editor

The editor provides an interactive interface to create and modify programs:

- Add, edit, move, and delete operations
- Navigate the operation hierarchy
- Edit operation data
- Save and run programs

## Implementation Details

The system consists of four main components:

1. **Database Schema** - Defines the structure for storing programs
2. **Language Specification** - Defines the operations and their behavior
3. **Interpreter** - Executes programs by traversing the operation tree
4. **Editor** - Provides a user interface for creating and modifying programs

The interpreter evaluates operations and their associated data, maintaining a variable environment for each scope. Nested operations are executed recursively, with control flow operations (if, while, for) determining which branches to execute.

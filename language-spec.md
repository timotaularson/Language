# JuliaSQLite Programming Language Specification

## Overview

JuliaSQLite is a programming language that stores its programs as opcodes and data in a SQLite database. The language uses a parent-child relationship and sequence numbers to represent nested and sequential operations.

## Data Types

- **Integer**: Whole numbers
- **Float**: Decimal numbers
- **String**: Text values
- **Boolean**: True/false values
- **Array**: Ordered collection of values
- **Dict**: Key-value pairs

## Basic Operations

| Opcode | Description | Parameters |
|--------|-------------|------------|
| `assign` | Assign a value to a variable | `var_name`, `value` |
| `print` | Output a value | `value` |
| `add` | Addition | `left`, `right`, `result` |
| `sub` | Subtraction | `left`, `right`, `result` |
| `mul` | Multiplication | `left`, `right`, `result` |
| `div` | Division | `left`, `right`, `result` |
| `eq` | Equality comparison | `left`, `right`, `result` |
| `lt` | Less than comparison | `left`, `right`, `result` |
| `gt` | Greater than comparison | `left`, `right`, `result` |

## Control Flow

| Opcode | Description | Parameters |
|--------|-------------|------------|
| `if` | Conditional execution | `condition` |
| `else` | Alternative execution path | None |
| `while` | Loop while condition is true | `condition` |
| `for` | Iterate over a collection | `iterator`, `collection` |
| `break` | Exit from a loop | None |
| `continue` | Skip to next iteration | None |
| `return` | Return a value | `value` |

## Functions

| Opcode | Description | Parameters |
|--------|-------------|------------|
| `function` | Define a function | `name`, `params` |
| `call` | Call a function | `name`, `args` |

## Storage

Programs are stored in a SQLite database with two main tables:
- `operations`: Stores the opcodes, parent relationships, and sequence
- `data`: Stores parameters for each operation

## Nesting and Sequencing

Operations can be nested within other operations using the `parent_id` column. The `sequence` column determines the order of execution within a given scope.

## Example

A simple program to calculate the factorial of a number might be represented as follows:

1. `assign` operation for n = 5
2. `assign` operation for result = 1
3. `while` operation with condition n > 0
   - `mul` operation for result = result * n
   - `sub` operation for n = n - 1
4. `print` operation for result

-- Create the operations table to store opcodes
CREATE TABLE operations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    opcode TEXT NOT NULL,         -- Operation code (e.g., "add", "print", "if")
    parent_id INTEGER,            -- Reference to parent operation for nesting
    sequence INTEGER NOT NULL,    -- Order within parent scope
    FOREIGN KEY (parent_id) REFERENCES operations(id)
);

-- Create the data table to store operation parameters and values
CREATE TABLE data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operation_id INTEGER NOT NULL, -- Reference to the associated operation
    key TEXT NOT NULL,            -- Parameter name or identifier
    value TEXT,                   -- Value as text (can be parsed to appropriate type)
    FOREIGN KEY (operation_id) REFERENCES operations(id)
);

-- Create an index to optimize querying operations by parent and sequence
CREATE INDEX idx_operations_parent_sequence ON operations(parent_id, sequence);

-- Create an index to optimize querying data by operation
CREATE INDEX idx_data_operation ON data(operation_id);

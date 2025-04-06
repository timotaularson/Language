using SQLite

"""
    initialize_schema(db) - Initialize the database schema for a new program
"""
function initialize_schema(db::SQLite.DB)
    # Create the operations table
    SQLite.execute(db, """
    CREATE TABLE IF NOT EXISTS operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        opcode TEXT NOT NULL,
        parent_id INTEGER,
        sequence INTEGER NOT NULL,
        FOREIGN KEY (parent_id) REFERENCES operations(id)
    )
    """)
    
    # Create the data table
    SQLite.execute(db, """
    CREATE TABLE IF NOT EXISTS data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_id INTEGER NOT NULL,
        key TEXT NOT NULL,
        value TEXT,
        FOREIGN KEY (operation_id) REFERENCES operations(id)
    )
    """)
    
    # Create indexes for better performance
    SQLite.execute(db, """
    CREATE INDEX IF NOT EXISTS idx_operations_parent_sequence 
    ON operations(parent_id, sequence)
    """)
    
    SQLite.execute(db, """
    CREATE INDEX IF NOT EXISTS idx_data_operation 
    ON data(operation_id)
    """)
end

class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    puts "Creating transactions table..."
    create_table :transactions do |t|
      # Transaction identification
      t.string :transaction_hash, null: false, index: { unique: true }
      t.string :method, null: false
      t.integer :sequential_id, null: true, index: { unique: true }
      t.references :function_signature, null: false, foreign_key: true
      
      # Addresses
      t.string :from_address, null: false
      t.string :to_address, null: false
      
      # Transaction details
      t.text :value  # in wei
      t.text :fee    # in wei
      t.string :gas_used
      t.string :gas_price
      t.string :status
      t.integer :confirmations
      t.integer :block_number
      t.datetime :timestamp, null: false
      
      # Transaction type specific data
      t.text :raw_input
      t.text :decoded_input
      
      t.timestamps
    end

    # Indexes for performance
    puts "Adding indexes to transactions table..."
    add_index :transactions, :method
    add_index :transactions, :from_address
    add_index :transactions, :to_address
    add_index :transactions, :timestamp
    add_index :transactions, :block_number
    add_index :transactions, [:method, :timestamp]
    puts "Transactions table created successfully!"
  end
end
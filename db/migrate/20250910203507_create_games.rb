class CreateGames < ActiveRecord::Migration[8.0]
  def change
    create_table :games do |t|
      # Primary key from blockchain
      t.integer :game_id, null: false
      
      # Game state (enum: 0=Pending, 1=Committed, 2=Revealed, 3=Completed)
      t.integer :game_state, null: false
      
      # Player information
      t.string :player_address, null: false
      t.string :player_commit, null: false
      t.datetime :commit_timestamp, null: false
      t.text :bet_amount
      
      # House information
      t.string :house_randomness
      t.datetime :house_randomness_timestamp
      
      # Game results
      t.string :player_secret
      t.text :player_card
      t.text :house_card
      t.datetime :reveal_timestamp
      
      # Calculated fields
      t.integer :result, default: 0  # enum: 0=error, 1=player_won, 2=house_won, 3=tie
      t.integer :total_time  # seconds between commit and reveal
      
      t.timestamps
    end

    # Indexes
    add_index :games, :game_id, unique: true
    add_index :games, :player_address
    add_index :games, :player_commit
    add_index :games, :commit_timestamp
    add_index :games, :bet_amount
    add_index :games, :result
    add_index :games, :total_time
  end
end

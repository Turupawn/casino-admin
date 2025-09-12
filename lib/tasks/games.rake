namespace :games do
  desc "Smart sync games from blockchain with state-based optimization"
  task sync: :environment do
    puts "Starting smart games sync at #{Time.current}"
    
    begin
      # Initialize blockchain client and contract using configuration
      client = Eth::Client.create(BlockchainConfig.rpc_url)
      abi = ContractAbiService.load_abi(BlockchainConfig.contract_abi_name)
      contract_address = BlockchainConfig.contract_address
      
      contract = Eth::Contract.from_abi(
        name: "TwoPartyWarGame",
        address: contract_address,
        abi: abi
      )
      
      # Get the next game ID to know the range
      next_game_id = client.call(contract, "nextGameId")
      puts "Next game ID: #{next_game_id}"

      # Calculate how many games actually exist (game IDs start from 1)
      total_available_games = next_game_id - 1
      
      if total_available_games <= 0
        puts "No games available on blockchain"
        return
      end
      
      # Smart sync strategy based on current state distribution
      sync_strategy = determine_sync_strategy(total_available_games)
      puts "Sync strategy: #{sync_strategy[:type]} - #{sync_strategy[:description]}"
      
      # Execute the determined sync strategy
      case sync_strategy[:type]
      when :new_games
        sync_new_games(client, contract, sync_strategy[:starting_offset], total_available_games)
      when :pending_house_response
        sync_pending_house_games(client, contract, sync_strategy[:game_ids])
      when :pending_player_reveal
        sync_pending_player_games(client, contract, sync_strategy[:game_ids])
      when :full_sync
        sync_new_games(client, contract, 0, total_available_games)
      end
      
    rescue => e
      puts "Error in smart games sync: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      Rails.logger.error "Smart games sync failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end


  desc "Run a single sync manually"
  task manual_sync: :environment do
    puts "Running manual sync..."
    Rake::Task['games:sync'].invoke
    puts "Manual sync completed!"
  end
  
  private
  
  def sanitize_game_hash(game_hash)
    # Create a new hash with sanitized string values
    sanitized = {}
    game_hash.each do |key, value|
      
      if value.is_a?(String)
        # Convert binary strings to hex representation for safe storage
        if value.encoding == Encoding::ASCII_8BIT || value.bytes.any? { |b| b > 127 }
          hex_value = "0x" + value.unpack('H*').first
          
          # Handle address fields - convert 32-byte addresses to 20-byte addresses
          if key == "playerAddress" || key == "winner"
            # Remove leading zeros to get the actual 20-byte address
            # 32 bytes = 64 hex chars, 20 bytes = 40 hex chars
            # Remove the '0x' prefix, take last 40 chars, then add '0x' back
            clean_hex = hex_value[2..-1]  # Remove '0x'
            clean_hex = clean_hex.rjust(64, '0')  # Ensure it's 64 chars (32 bytes)
            address_hex = clean_hex[-40..-1]  # Take last 40 chars (20 bytes)
            sanitized[key] = "0x" + address_hex
          else
            sanitized[key] = hex_value
          end
        else
          # Force encoding to UTF-8 and replace invalid characters
          sanitized[key] = value.force_encoding('UTF-8').scrub('?')
        end
      else
        sanitized[key] = value
      end
    end
    sanitized
  end
  
  def determine_sync_strategy(total_available_games)
    # Get current state distribution
    state_counts = Game.group(:game_state).count
    latest_game_id = Game.maximum(:game_id) || 0

    puts "Current state distribution: #{state_counts}"
    puts "Latest game ID in DB: #{latest_game_id}, Total available: #{total_available_games}"

    # Strategy 1: Check for new games first (most common case)
    if latest_game_id < total_available_games
      new_games_count = total_available_games - latest_game_id
      return {
        type: :new_games,
        description: "Found #{new_games_count} new games to sync",
        starting_offset: latest_game_id
      }
    end

    # Strategy 2: Check for games waiting for house response (player_committed)
    pending_house_games = Game.where(game_state: :player_committed)
                              .order(:commit_timestamp)
                              .limit(BlockchainConfig.max_games_to_process)

    if pending_house_games.any?
      return {
        type: :pending_house_response,
        description: "Found #{pending_house_games.count} games waiting for house response",
        game_ids: pending_house_games.pluck(:game_id)
      }
    end

    # Strategy 3: Check for games waiting for player reveal (hash_posted)
    pending_player_games = Game.where(game_state: :hash_posted)
                               .order(:house_randomness_timestamp)
                               .limit(BlockchainConfig.max_games_to_process)

    if pending_player_games.any?
      return {
        type: :pending_player_reveal,
        description: "Found #{pending_player_games.count} games waiting for player reveal",
        game_ids: pending_player_games.pluck(:game_id)
      }
    end

    # Strategy 4: Full sync if no specific priorities (rare case)
    {
      type: :full_sync,
      description: "No specific priorities, doing full sync",
      starting_offset: 0
    }
  end

  def sync_new_games(client, contract, starting_offset, total_available_games)
    puts "Syncing new games from offset #{starting_offset}"

    batch_size = BlockchainConfig.max_games_to_process
    remaining_games = total_available_games - starting_offset
    amount = [batch_size, remaining_games].min

    puts "Fetching batch: offset=#{starting_offset}, amount=#{amount}"

    # Call getGames with ascending order (ascendant=true)
    games_batch = client.call(contract, "getGames", starting_offset, amount, true)

    if games_batch.nil? || !games_batch.is_a?(Array) || games_batch.empty?
      puts "No games returned from batch"
      return
    end

    process_games_batch(games_batch, starting_offset)
  end

  def sync_pending_house_games(client, contract, game_ids)
    puts "Syncing #{game_ids.length} games waiting for house response"

    # Fetch specific games by ID (more efficient than range)
    game_ids.each_slice(BlockchainConfig.max_games_to_process) do |batch_ids|
      begin
        # Get individual games by ID
        batch_ids.each do |game_id|
          game_data = client.call(contract, "getGame", game_id - 1) # Convert to 0-based index
          if game_data && game_data.is_a?(Array) && game_data.length >= 11
            game_hash = {
              "gameState" => game_data[0],
              "playerAddress" => game_data[1],
              "playerCommit" => game_data[2],
              "commitTimestamp" => game_data[3],
              "betAmount" => game_data[4],
              "houseRandomness" => game_data[5],
              "houseRandomnessTimestamp" => game_data[6],
              "playerSecret" => game_data[7],
              "playerCard" => game_data[8],
              "houseCard" => game_data[9],
              "revealTimestamp" => game_data[10]
            }

            update_existing_game(game_id, game_hash)
          end
        end

        # Small delay between batches to respect RPC limits
        sleep(0.1) if batch_ids.length > 1
      rescue => e
        puts "Error syncing house games batch: #{e.message}"
      end
    end
  end

  def sync_pending_player_games(client, contract, game_ids)
    puts "Syncing #{game_ids.length} games waiting for player reveal"

    # Similar to house games but with different batching strategy
    game_ids.each_slice(BlockchainConfig.max_games_to_process) do |batch_ids|
      begin
        batch_ids.each do |game_id|
          game_data = client.call(contract, "getGame", game_id - 1)
          if game_data && game_data.is_a?(Array) && game_data.length >= 11
            game_hash = {
              "gameState" => game_data[0],
              "playerAddress" => game_data[1],
              "playerCommit" => game_data[2],
              "commitTimestamp" => game_data[3],
              "betAmount" => game_data[4],
              "houseRandomness" => game_data[5],
              "houseRandomnessTimestamp" => game_data[6],
              "playerSecret" => game_data[7],
              "playerCard" => game_data[8],
              "houseCard" => game_data[9],
              "revealTimestamp" => game_data[10]
            }

            update_existing_game(game_id, game_hash)
          end
        end

        # Small delay between batches
        sleep(0.1) if batch_ids.length > 1
      rescue => e
        puts "Error syncing player games batch: #{e.message}"
      end
    end
  end

  def process_games_batch(games_batch, starting_offset)
    puts "Processing batch of #{games_batch.length} games"

    new_games_count = 0
    updated_games_count = 0

    games_batch.each_with_index do |game_data, index|
      begin
        # Calculate the actual game ID (offset + index + 1, since game IDs start from 1)
        game_id = starting_offset + index + 1

        # Convert array to hash format if needed
        game_hash = if game_data.is_a?(Hash)
          game_data
        elsif game_data.is_a?(Array) && game_data.length >= 11
          {
            "gameState" => game_data[0],
            "playerAddress" => game_data[1],
            "playerCommit" => game_data[2],
            "commitTimestamp" => game_data[3],
            "betAmount" => game_data[4],
            "houseRandomness" => game_data[5],
            "houseRandomnessTimestamp" => game_data[6],
            "playerSecret" => game_data[7],
            "playerCard" => game_data[8],
            "houseCard" => game_data[9],
            "revealTimestamp" => game_data[10]
          }
        else
          puts "Skipping invalid game data at index #{index}"
          next
        end

        # Check if game already exists by game_id
        existing_game = Game.find_by(game_id: game_id)

        if existing_game
          update_existing_game(game_id, game_hash)
          updated_games_count += 1
        else
          # Create new game
          game = create_new_game(game_hash, game_id)
          if game&.persisted?
            new_games_count += 1
          end
        end
      rescue => e
        puts "Error processing game #{index + 1}: #{e.message}"
        Rails.logger.error "Error processing game #{index + 1}: #{e.message}"
      end
    end

    puts "Batch processing completed: #{new_games_count} new, #{updated_games_count} updated"
  end

  def update_existing_game(game_id, game_hash)
    existing_game = Game.find_by(game_id: game_id)
    return unless existing_game

    # Sanitize the data to handle encoding issues
    sanitized_hash = sanitize_game_hash(game_hash)

    # Update existing game with latest data
    existing_game.update!(
      game_state: sanitized_hash["gameState"],
      player_address: sanitized_hash["playerAddress"],
      player_commit: sanitized_hash["playerCommit"],
      commit_timestamp: Time.at(sanitized_hash["commitTimestamp"].to_i),
      bet_amount: sanitized_hash["betAmount"].to_s,
      house_randomness: sanitized_hash["houseRandomness"],
      house_randomness_timestamp: sanitized_hash["houseRandomnessTimestamp"] ? Time.at(sanitized_hash["houseRandomnessTimestamp"].to_i) : nil,
      player_secret: sanitized_hash["playerSecret"],
      player_card: sanitized_hash["playerCard"].to_s,
      house_card: sanitized_hash["houseCard"].to_s,
      reveal_timestamp: sanitized_hash["revealTimestamp"] ? Time.at(sanitized_hash["revealTimestamp"].to_i) : nil
    )

    # Recalculate winner logic and total time for updated game
    existing_game.calculate_winner
    existing_game.calculate_total_time
    existing_game.save!

    puts "Updated game ID #{game_id} (state: #{existing_game.game_state})"
  end

  def create_new_game(game_hash, game_id)
    # Sanitize the data to handle encoding issues
    sanitized_hash = sanitize_game_hash(game_hash)

    # Create new game
    game = Game.from_contract_hash_with_id(sanitized_hash, game_id)
    if game.save
      puts "Created new game ID #{game_id} (state: #{game.game_state})"
      game
    else
      puts "Failed to save game ID #{game_id}: #{game.errors.full_messages.join(', ')}"
      nil
    end
  end
end

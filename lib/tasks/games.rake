namespace :games do
  desc "Fetch new games from blockchain and store them in database"
  task fetch_new: :environment do
    puts "Starting to fetch new games from blockchain..."
    
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
      
      # Get the latest games with their IDs (default to 50 games)
      latest_games_with_ids = fetch_latest_games_with_ids(client, contract, 50)
      
      if latest_games_with_ids.empty?
        puts "No games found from blockchain"
        return
      end
      
      puts "Found #{latest_games_with_ids.length} games from blockchain"
      puts "First game data: #{latest_games_with_ids.first.inspect}" if latest_games_with_ids.any?
      
      new_games_count = 0
      updated_games_count = 0
      
      latest_games_with_ids.each_with_index do |game_data, index|
        begin
          game_id = game_data[:game_id]
          game_hash = game_data[:game_data]
          
          # Sanitize the data to handle encoding issues
          sanitized_hash = sanitize_game_hash(game_hash)
          
          # Check if game already exists by game_id (more reliable than player_commit)
          existing_game = Game.find_by(game_id: game_id)
          
          if existing_game
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
            updated_games_count += 1
            puts "Updated game ID #{game_id} with commit: #{sanitized_hash["playerCommit"]}"
          else
            # Create new game
            game = Game.from_contract_hash_with_id(sanitized_hash, game_id)
            if game.save
              new_games_count += 1
              puts "Created new game ID #{game_id} with commit: #{sanitized_hash["playerCommit"]}"
            else
              puts "Failed to save game #{index + 1}: #{game.errors.full_messages.join(', ')}"
            end
          end
        rescue => e
          puts "Error processing game #{index + 1}: #{e.message}"
          Rails.logger.error "Error processing game #{index + 1}: #{e.message}"
        end
      end
      
      puts "Fetch completed successfully!"
      puts "New games created: #{new_games_count}"
      puts "Existing games updated: #{updated_games_count}"
      puts "Total games in database: #{Game.count}"
      
    rescue => e
      puts "Error fetching games: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      Rails.logger.error "Games fetch task failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  desc "Show statistics about games in database"
  task stats: :environment do
    total_games = Game.count
    
    puts "=== Games Database Statistics ==="
    puts "Total games: #{total_games}"
    
    if total_games > 0
      latest_game = Game.recent.first
      oldest_game = Game.order(:commit_timestamp).first
      
      puts "\nLatest game:"
      puts "  Game ID: #{latest_game.game_id}"
      puts "  Commit: #{latest_game.player_commit}"
      puts "  Timestamp: #{latest_game.commit_timestamp}"
      
      puts "\nOldest game:"
      puts "  Game ID: #{oldest_game.game_id}"
      puts "  Commit: #{oldest_game.player_commit}"
      puts "  Timestamp: #{oldest_game.commit_timestamp}"
    end
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
  
  def fetch_latest_games_with_ids(client, contract, count = 50)
    begin
      # First, get the next game ID to know the range
      next_game_id = client.call(contract, "nextGameId")
      puts "Next game ID: #{next_game_id}"
      
      # Calculate how many games actually exist (game IDs start from 1)
      total_available_games = next_game_id - 1
      
      if total_available_games <= 0
        puts "No games available on blockchain"
        return []
      end
      
      # Don't try to fetch more games than actually exist
      games_to_fetch = [count, total_available_games].min
      puts "Total available games: #{total_available_games}, fetching: #{games_to_fetch}"
      
      # Calculate how many batches we need using configured batch size
      batch_size = BlockchainConfig.game_fetch_batch_size
      total_batches = (games_to_fetch.to_f / batch_size).ceil
      
      games_with_ids = []
      
      # Fetch games in batches using getGames function
      total_batches.times do |batch_index|
        offset = batch_index * batch_size
        
        # Skip this batch if offset is beyond available games
        if offset >= total_available_games
          puts "Skipping batch #{batch_index + 1}: offset #{offset} >= available games #{total_available_games}"
          break
        end
        
        # Calculate how many games to fetch in this batch
        remaining_games = games_to_fetch - games_with_ids.length
        amount = [batch_size, remaining_games, total_available_games - offset].min
        
        puts "Fetching batch #{batch_index + 1}/#{total_batches}: offset=#{offset}, amount=#{amount}"
        
        begin
          # Call getGames with ascending order (ascendant=true)
          games_batch = client.call(contract, "getGames", offset, amount, true)
          
          if games_batch && games_batch.is_a?(Array)
            games_batch.each_with_index do |game_data, index|
              if game_data && game_data.is_a?(Hash)
                # Calculate the actual game ID (offset + index + 1, since game IDs start from 1)
                game_id = offset + index + 1
                
                # The data is already in hash format from getGames function
                game_hash = game_data
                games_with_ids << { game_id: game_id, game_data: game_hash }
              elsif game_data && game_data.is_a?(Array) && game_data.length >= 11
                # Calculate the actual game ID (offset + index + 1, since game IDs start from 1)
                game_id = offset + index + 1
                
                # Convert array to hash format (fallback for array format)
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
                games_with_ids << { game_id: game_id, game_data: game_hash }
              end
            end
            puts "  Fetched #{games_batch.length} games from batch"
          else
            puts "  No games returned from batch"
          end
        rescue => e
          puts "  Error fetching batch #{batch_index + 1}: #{e.message}"
          Rails.logger.error "Error fetching batch #{batch_index + 1}: #{e.message}"
        end
        
        # Add delay between batches to respect RPC rate limits (except for the last batch)
        if batch_index < total_batches - 1
          delay_seconds = BlockchainConfig.rpc_call_delay_ms / 1000.0
          puts "  Waiting #{BlockchainConfig.rpc_call_delay_ms}ms before next batch..."
          sleep(delay_seconds)
        end
      end
      
      puts "Total games fetched: #{games_with_ids.length}"
      games_with_ids
    rescue => e
      Rails.logger.error "Failed to fetch latest games with IDs: #{e.message}"
      []
    end
  end
end

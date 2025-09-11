class GamesController < ApplicationController
  def index
    @games = Game.recent.page(params[:page]).per(20)
    @total_games = Game.count
  end

  def home
    client = Eth::Client.create("https://carrot.megaeth.com/rpc")

    abi = ContractAbiService.load_abi("two_party_war_game")

    contract_address = "0x94c5F28b47145B1b38B200fEa1832248ad7dE825"
    @contract = Eth::Contract.from_abi(
      name: "TwoPartyWarGame",
      address: contract_address,
      abi: abi
    )

    # Get the latest 10 games
    # offset: 0 (start from the beginning)
    # amount: 10 (get 10 games)
    # ascendant: false (get in descending order, so latest first)
    @latest_games = get_latest_games(client, 10)
    
    # Keep the original single game call for reference
    @game = client.call(@contract, "games", 1)
  end

  private

  def get_latest_games(client, count = 10)
    begin
      result2 = client.call(@contract, "getGames", 0, count, false)

      # The eth gem is working correctly! It returns an array of hashes
      if result2.is_a?(Array)
        # Convert each hash to array format for consistency with the view
        result2.map do |game_hash|
          [
            game_hash["gameState"],
            game_hash["playerAddress"],
            game_hash["playerCommit"],
            game_hash["commitTimestamp"],
            game_hash["houseRandomness"],
            game_hash["houseRandomnessTimestamp"],
            game_hash["playerSecret"],
            game_hash["playerCard"],
            game_hash["houseCard"],
            game_hash["winner"],
            game_hash["revealTimestamp"]
          ]
        end
      elsif result2.is_a?(Hash)
        # Fallback for single game
        game_array = [
          result2["gameState"],
          result2["playerAddress"],
          result2["playerCommit"],
          result2["commitTimestamp"],
          result2["houseRandomness"],
          result2["houseRandomnessTimestamp"],
          result2["playerSecret"],
          result2["playerCard"],
          result2["houseCard"],
          result2["winner"],
          result2["revealTimestamp"]
        ]
        [game_array]
      else
        []
      end
    rescue => e
      Rails.logger.error "Failed to fetch latest games: #{e.message}"
      []
    end
  end
end

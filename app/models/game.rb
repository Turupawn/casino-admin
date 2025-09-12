class Game < ApplicationRecord
  validates :player_commit, presence: true
  validates :player_address, presence: true
  validates :game_state, presence: true
  validates :game_id, presence: true, uniqueness: true

  attribute :result, :integer
  enum :result, { error: 0, player_won: 1, house_won: 2, tie: 3 }
  
  attribute :game_state, :integer
  enum :game_state, { not_started: 0, player_committed: 1, hash_posted: 2, revealed: 3, forfeited: 4 }

  scope :recent, -> { order(commit_timestamp: :desc) }

  def self.from_contract_hash(game_hash)
    game = new(
      game_state: game_hash["gameState"],
      player_address: game_hash["playerAddress"],
      player_commit: game_hash["playerCommit"],
      commit_timestamp: Time.at(game_hash["commitTimestamp"].to_i),
      bet_amount: game_hash["betAmount"].to_s,
      house_randomness: game_hash["houseRandomness"],
      house_randomness_timestamp: game_hash["houseRandomnessTimestamp"] ? Time.at(game_hash["houseRandomnessTimestamp"].to_i) : nil,
      player_secret: game_hash["playerSecret"],
      player_card: game_hash["playerCard"].to_s,
      house_card: game_hash["houseCard"].to_s,
      reveal_timestamp: game_hash["revealTimestamp"] ? Time.at(game_hash["revealTimestamp"].to_i) : nil,
    )
    
    game.calculate_winner
    game.calculate_total_time
    game
  end

  def self.from_contract_hash_with_id(game_hash, game_id)
    game = new(
      game_id: game_id,
      game_state: game_hash["gameState"],
      player_address: game_hash["playerAddress"],
      player_commit: game_hash["playerCommit"],
      commit_timestamp: Time.at(game_hash["commitTimestamp"].to_i),
      bet_amount: game_hash["betAmount"].to_s,
      house_randomness: game_hash["houseRandomness"],
      house_randomness_timestamp: game_hash["houseRandomnessTimestamp"] ? Time.at(game_hash["houseRandomnessTimestamp"].to_i) : nil,
      player_secret: game_hash["playerSecret"],
      player_card: game_hash["playerCard"].to_s,
      house_card: game_hash["houseCard"].to_s,
      reveal_timestamp: game_hash["revealTimestamp"] ? Time.at(game_hash["revealTimestamp"].to_i) : nil,
    )
    
    game.calculate_winner
    game.calculate_total_time
    game
  end

  def self.from_contract_data(game_data)
    game = new(
      game_state: game_data[0],
      player_address: game_data[1],
      player_commit: game_data[2],
      commit_timestamp: Time.at(game_data[3].to_i),
      bet_amount: game_data[4].to_s,
      house_randomness: game_data[5],
      house_randomness_timestamp: game_data[6] ? Time.at(game_data[6].to_i) : nil,
      player_secret: game_data[7],
      player_card: game_data[8].to_s,
      house_card: game_data[9].to_s,
      reveal_timestamp: game_data[10] ? Time.at(game_data[10].to_i) : nil,
    )
    
    game.calculate_winner
    game.calculate_total_time
    game
  end

  def calculate_winner
    return unless player_card.present? && house_card.present?
    
    player_card_value = player_card.to_i
    house_card_value = house_card.to_i
    
    if player_card_value > house_card_value
      self.result = :player_won
    elsif player_card_value < house_card_value
      self.result = :house_won
    else
      self.result = :tie
    end
  end

  def calculate_total_time
    return unless commit_timestamp.present? && reveal_timestamp.present?
    
    self.total_time = (reveal_timestamp - commit_timestamp).to_i
  end

end

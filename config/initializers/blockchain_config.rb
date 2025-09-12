# Load blockchain configuration from YAML file
blockchain_config = Rails.application.config_for(:blockchain)

# Override with environment variables if they exist
blockchain_config['rpc_url'] = ENV['BLOCKCHAIN_RPC_URL'] if ENV['BLOCKCHAIN_RPC_URL']
blockchain_config['contract_address'] = ENV['BLOCKCHAIN_CONTRACT_ADDRESS'] if ENV['BLOCKCHAIN_CONTRACT_ADDRESS']
blockchain_config['contract_abi_name'] = ENV['BLOCKCHAIN_CONTRACT_ABI'] if ENV['BLOCKCHAIN_CONTRACT_ABI']
blockchain_config['sync_schedule_ms'] = ENV['BLOCKCHAIN_SYNC_SCHEDULE_MS'].to_i if ENV['BLOCKCHAIN_SYNC_SCHEDULE_MS']
blockchain_config['max_games_to_process'] = ENV['BLOCKCHAIN_MAX_GAMES_TO_PROCESS'].to_i if ENV['BLOCKCHAIN_MAX_GAMES_TO_PROCESS']

# Make configuration available throughout the application
Rails.application.config.blockchain = blockchain_config

# Create a convenient accessor method
module BlockchainConfig
  def self.rpc_url
    Rails.application.config.blockchain['rpc_url']
  end

  def self.contract_address
    Rails.application.config.blockchain['contract_address']
  end

  def self.contract_abi_name
    Rails.application.config.blockchain['contract_abi_name']
  end

  def self.sync_schedule_ms
    Rails.application.config.blockchain['sync_schedule_ms']
  end

  def self.max_games_to_process
    Rails.application.config.blockchain['max_games_to_process']
  end

  def self.new_games_batch_size
    max_games_to_process
  end

  def self.pending_house_batch_size
    max_games_to_process
  end

  def self.pending_player_batch_size
    max_games_to_process
  end

  def self.max_pending_house_games
    max_games_to_process
  end

  def self.max_pending_player_games
    max_games_to_process
  end
end

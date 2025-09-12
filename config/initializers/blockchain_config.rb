# Load blockchain configuration from YAML file
blockchain_config = Rails.application.config_for(:blockchain)

# Override with environment variables if they exist
blockchain_config['rpc_url'] = ENV['BLOCKCHAIN_RPC_URL'] if ENV['BLOCKCHAIN_RPC_URL']
blockchain_config['contract_address'] = ENV['BLOCKCHAIN_CONTRACT_ADDRESS'] if ENV['BLOCKCHAIN_CONTRACT_ADDRESS']
blockchain_config['contract_abi_name'] = ENV['BLOCKCHAIN_CONTRACT_ABI'] if ENV['BLOCKCHAIN_CONTRACT_ABI']
blockchain_config['game_fetch_batch_size'] = ENV['BLOCKCHAIN_GAME_FETCH_BATCH_SIZE'].to_i if ENV['BLOCKCHAIN_GAME_FETCH_BATCH_SIZE']
blockchain_config['rpc_call_delay_ms'] = ENV['BLOCKCHAIN_RPC_CALL_DELAY_MS'].to_i if ENV['BLOCKCHAIN_RPC_CALL_DELAY_MS']

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

  def self.game_fetch_batch_size
    Rails.application.config.blockchain['game_fetch_batch_size']
  end

  def self.rpc_call_delay_ms
    Rails.application.config.blockchain['rpc_call_delay_ms']
  end
end

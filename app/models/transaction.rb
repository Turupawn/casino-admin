class Transaction < ApplicationRecord
  # Associations
  belongs_to :function_signature, optional: true

  # Validations
  validates :transaction_hash, presence: true, uniqueness: true
  validates :sequential_id, presence: true, uniqueness: true
  validates :method, presence: true
  validates :from_address, presence: true
  validates :to_address, presence: true
  validates :timestamp, presence: true

  # Scopes
  scope :recent, -> { order(timestamp: :desc) }
  scope :by_method, ->(method) { where(method: method) }
  scope :commits, -> { where(method: 'commit') }
  scope :reveals, -> { where(method: 'reveal') }
  scope :multi_post_randomness, -> { where(method: 'multiPostRandomness') }

  # Class methods for calculations
  def self.house_average_cost
    multi_post_randomness.average(:fee)
  end

  def self.player_average_cost
    player_transactions = where(method: ['commit', 'reveal'])
    player_transactions.average(:fee)
  end

  def self.total_house_cost
    multi_post_randomness.sum(:fee)
  end

  def self.total_player_cost
    where(method: ['commit', 'reveal']).sum(:fee)
  end

  # Instance methods
  def eth_value
    return "0 ETH" if value.nil? || value == "0"
    eth_value = value.to_f / 10**18
    formatted = sprintf("%.18f", eth_value).gsub(/\.?0+$/, '')
    "#{formatted} ETH"
  end

  def eth_fee
    return "0 ETH" if fee.nil? || fee == "0"
    eth_fee = fee.to_f / 10**18
    formatted = sprintf("%.18f", eth_fee).gsub(/\.?0+$/, '')
    "#{formatted} ETH"
  end

  def transaction_type
    case method
    when 'commit'
      'commit'
    when 'multiPostRandomness'
      'multiPostRandomness'
    when 'reveal'
      'reveal'
    else
      method || 'unknown'
    end
  end

  def explorer_url
    "https://megaeth-testnet.blockscout.com/tx/#{transaction_hash}"
  end

  def from_explorer_url
    "https://megaeth-testnet.blockscout.com/address/#{from_address}"
  end

  def function_name
    function_signature&.name || transaction_type
  end
end

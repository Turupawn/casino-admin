class FunctionSignature < ApplicationRecord
  # Associations
  has_many :transactions, dependent: :nullify

  validates :name, presence: true
  validates :signature_hex, presence: true, uniqueness: { scope: :contract_name }
  validates :signature_str, presence: true
  validates :contract_name, presence: true

  scope :for_contract, ->(contract_name) { where(contract_name: contract_name) }
  scope :by_signature_hex, ->(signature_hex) { where(signature_hex: signature_hex) }

  def self.find_by_method_signature(method_signature)
    find_by(signature_hex: method_signature)
  end

  def self.find_by_method_signature_with_contract(method_signature, contract_name = nil)
    if contract_name
      find_by(signature_hex: method_signature, contract_name: contract_name)
    else
      find_by(signature_hex: method_signature)
    end
  end
end

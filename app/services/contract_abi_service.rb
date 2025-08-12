class ContractAbiService
  class << self
    def load_abi(contract_name)
      Rails.cache.fetch("contract_abi_#{contract_name}", expires_in: 1.hour) do
        load_abi_from_file(contract_name)
      end
    end
    
    def load_abi_as_string(contract_name)
      load_abi(contract_name).to_json
    end
    
    private
    
    def load_abi_from_file(contract_name)
      file_path = Rails.root.join('config', 'contracts', "#{contract_name}.json")
      
      unless File.exist?(file_path)
        raise ArgumentError, "ABI file not found for contract: #{contract_name}"
      end
      
      JSON.parse(File.read(file_path))
    rescue JSON::ParserError => e
      raise ArgumentError, "Invalid JSON in ABI file for contract #{contract_name}: #{e.message}"
    end
  end
end 
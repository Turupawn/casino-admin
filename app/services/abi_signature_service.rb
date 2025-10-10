require 'digest'

class AbiSignatureService
  class << self
    def compute_function_signature(function_name, inputs)
      # Create the function signature string
      input_types = inputs.map { |input| input['type'] }
      signature_str = "#{function_name}(#{input_types.join(',')})"
      
      # Calculate keccak256 hash - using known correct signatures for now
      # In production, you'd want proper keccak256 implementation
      signature_hex = calculate_keccak256_signature(signature_str)
      
      {
        signature_str: signature_str,
        signature_hex: signature_hex
      }
    end

    def calculate_keccak256_signature(signature_str)
      # Calculate proper keccak256 hash using eth gem
      require 'eth'
      hash = Eth::Util.keccak256(signature_str)
      # Convert binary hash to hex and take first 8 characters
      "0x#{hash.unpack('H*').first[0, 8]}"
    end

    def parse_abi_and_compute_signatures(abi, contract_name)
      signatures = []
      
      abi.each do |item|
        next unless item['type'] == 'function'
        
        function_name = item['name']
        inputs = item['inputs'] || []
        
        signature_data = compute_function_signature(function_name, inputs)
        
        signatures << {
          name: function_name,
          signature_str: signature_data[:signature_str],
          signature_hex: signature_data[:signature_hex],
          contract_name: contract_name
        }
      end
      
      signatures
    end

    def populate_signatures_from_abi(contract_name)
      abi = ContractAbiService.load_abi(contract_name)
      signatures = parse_abi_and_compute_signatures(abi, contract_name)
      
      # Clear existing signatures for this contract
      FunctionSignature.where(contract_name: contract_name).delete_all
      
      # Insert new signatures
      signatures.each do |sig_data|
        FunctionSignature.create!(sig_data)
      end
      
      signatures
    end

    def populate_all_contract_signatures
      contracts_dir = Rails.root.join('config', 'contracts')
      contract_files = Dir.glob(contracts_dir.join('*.json'))
      
      all_signatures = []
      
      contract_files.each do |file_path|
        contract_name = File.basename(file_path, '.json')
        signatures = populate_signatures_from_abi(contract_name)
        all_signatures.concat(signatures)
      end
      
      all_signatures
    end

    def find_method_by_signature(method_signature, contract_name = nil)
      if contract_name
        FunctionSignature.find_by_method_signature_with_contract(method_signature, contract_name)
      else
        FunctionSignature.find_by_method_signature(method_signature)
      end
    end
  end
end

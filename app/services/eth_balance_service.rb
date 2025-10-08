class EthBalanceService
  class << self
    def get_house_balance
      begin
        client = Eth::Client.create(BlockchainConfig.rpc_url)
        abi = ContractAbiService.load_abi(BlockchainConfig.contract_abi_name)
        contract_address = BlockchainConfig.contract_address
        
        contract = Eth::Contract.from_abi(
          name: "TwoPartyWarGame",
          address: contract_address,
          abi: abi
        )
        
        house_address = client.call(contract, "HOUSE")
        
        balance_wei = client.get_balance(house_address)
        
        balance_eth = balance_wei.to_f / (10**18)
        
        {
          house_address: house_address,
          balance_wei: balance_wei,
          balance_eth: balance_eth,
          success: true
        }
      rescue => e
        Rails.logger.error "Failed to fetch house ETH balance: #{e.message}"
        {
          house_address: nil,
          balance_wei: 0,
          balance_eth: 0,
          success: false,
          error: e.message
        }
      end
    end
  end
end

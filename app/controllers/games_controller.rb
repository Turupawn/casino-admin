class GamesController < ApplicationController
  def home
    client = Eth::Client.create("https://carrot.megaeth.com/rpc")

    abi = '[{"inputs":[{"internalType":"uint256","name":"","type":"uint256"}],"name":"games","outputs":[{"internalType":"uint8","name":"gameState","type":"uint8"},{"internalType":"address","name":"playerAddress","type":"address"},{"internalType":"bytes32","name":"playerCommit","type":"bytes32"},{"internalType":"uint256","name":"commitTimestamp","type":"uint256"},{"internalType":"bytes32","name":"houseHash","type":"bytes32"},{"internalType":"uint256","name":"houseHashTimestamp","type":"uint256"},{"internalType":"bytes32","name":"playerSecret","type":"bytes32"},{"internalType":"uint256","name":"playerCard","type":"uint256"},{"internalType":"uint256","name":"houseCard","type":"uint256"},{"internalType":"address","name":"winner","type":"address"},{"internalType":"uint256","name":"revealTimestamp","type":"uint256"}],"stateMutability":"view","type":"function"}]'

    contract_address = "0xff8269e2a10e39422E18Cf7Bc54f12260451e306"
    @contract = Eth::Contract.from_abi(
      name: "TwoPartyWarGame",
      address: contract_address,
      abi: abi
    )

    @game = client.call(@contract, "games", 1)
  end
end

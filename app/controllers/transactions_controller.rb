class TransactionsController < ApplicationController
  def index
    @transactions = Transaction.recent.page(params[:page]).per(20)
    @total_transactions = Transaction.count
    @contract_address = BlockchainConfig.contract_address
    
    # Calculate average costs from database
    @house_average_cost = Transaction.house_average_cost || 0
    @player_average_cost = Transaction.player_average_cost || 0
  end

  def show
    @transaction = Transaction.find(params[:id])
  end
end

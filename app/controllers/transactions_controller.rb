class TransactionsController < ApplicationController
  def index
    @transactions = Transaction.recent.page(params[:page]).per(20)
    @total_transactions = Transaction.count
    @commit_count = Transaction.commits.count
    @reveal_count = Transaction.reveals.count
    @multi_post_randomness_count = Transaction.multi_post_randomness.count
    
    # Calculate average costs from database
    @house_average_cost = Transaction.house_average_cost || 0
    @player_average_cost = Transaction.player_average_cost || 0
  end

  def show
    @transaction = Transaction.find(params[:id])
  end
end

class TransactionsSyncJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting scheduled transactions sync at #{Time.current}"
    
    begin
      # Re-enable the task so it can be invoked again
      Rake::Task['transactions:sync'].reenable
      Rake::Task['transactions:sync'].invoke
      Rails.logger.info "Rake task completed successfully"
      
    rescue => e
      Rails.logger.error "Error in TransactionsSyncJob: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end
    
    Rails.logger.info "Completed scheduled transactions sync at #{Time.current}"
  end
end

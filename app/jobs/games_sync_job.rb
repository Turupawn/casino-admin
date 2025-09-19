class GamesSyncJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting scheduled games sync at #{Time.current}"
    
    begin
      # Re-enable the task so it can be invoked again
      Rake::Task['games:sync'].reenable
      Rake::Task['games:sync'].invoke
      Rails.logger.info "Rake task completed successfully"
      
    rescue => e
      Rails.logger.error "Error in GamesSyncJob: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end
    
    Rails.logger.info "Completed scheduled games sync at #{Time.current}"
  end
end

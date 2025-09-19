class GamesSyncJob < ApplicationJob
  queue_as :default

  def perform
    # Run the rake task
    Rails.logger.info "Starting scheduled games sync at #{Time.current}"
    Rake::Task['games:sync'].invoke
    Rails.logger.info "Completed scheduled games sync at #{Time.current}"
  end
end

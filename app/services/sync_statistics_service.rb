class SyncStatisticsService
  # Track sync statistics for aggregation
  def self.record_sync_stats(new_games_count, updated_games_count)
    stats = {
      timestamp: Time.current,
      new_games: new_games_count,
      updated_games: updated_games_count
    }
    
    # Store in Redis or database for aggregation
    # For now, using Rails cache with a key that includes the current hour
    cache_key = "sync_stats_#{Time.current.strftime('%Y%m%d%H')}"
    existing_stats = Rails.cache.read(cache_key) || []
    existing_stats << stats
    
    # Keep only the last 24 hours of stats
    cutoff_time = 24.hours.ago
    existing_stats = existing_stats.select { |stat| stat[:timestamp] > cutoff_time }
    
    Rails.cache.write(cache_key, existing_stats, expires_in: 25.hours)
    
    stats
  end

  # Get aggregated statistics since last telegram message
  def self.get_aggregated_stats(since_time = nil)
    since_time ||= get_last_telegram_time
    
    # Get all stats since the last telegram message
    all_stats = []
    current_time = Time.current
    
    # Check the last 24 hours of cache keys
    (0..23).each do |hour_offset|
      check_time = current_time - hour_offset.hours
      cache_key = "sync_stats_#{check_time.strftime('%Y%m%d%H')}"
      hour_stats = Rails.cache.read(cache_key) || []
      
      # Filter stats since the last telegram message
      filtered_stats = hour_stats.select { |stat| stat[:timestamp] > since_time }
      all_stats.concat(filtered_stats)
    end
    
    # Aggregate the statistics
    aggregate_stats(all_stats)
  end

  # Record when a telegram message was sent
  def self.record_telegram_sent
    Rails.cache.write('last_telegram_sent', Time.current, expires_in: 7.days)
  end

  # Get the last time a telegram message was sent
  def self.get_last_telegram_time
    Rails.cache.read('last_telegram_sent') || 1.hour.ago
  end

  # Check if enough time has passed since last telegram message
  def self.should_send_telegram?
    last_telegram = get_last_telegram_time
    interval = BlockchainConfig.telegram_message_interval.seconds
    Time.current - last_telegram >= interval
  end

  private

  def self.aggregate_stats(stats)
    return {
      total_new_games: 0,
      total_updated_games: 0,
      sync_count: 0,
      time_range: "No data"
    } if stats.empty?

    total_new_games = stats.sum { |stat| stat[:new_games] }
    total_updated_games = stats.sum { |stat| stat[:updated_games] }
    sync_count = stats.length
    
    time_range = if stats.length == 1
      "Last sync: #{stats.first[:timestamp].strftime('%H:%M:%S')}"
    else
      first_time = stats.min_by { |stat| stat[:timestamp] }[:timestamp]
      last_time = stats.max_by { |stat| stat[:timestamp] }[:timestamp]
      "#{first_time.strftime('%H:%M')} - #{last_time.strftime('%H:%M')}"
    end

    {
      total_new_games: total_new_games,
      total_updated_games: total_updated_games,
      sync_count: sync_count,
      time_range: time_range
    }
  end
end

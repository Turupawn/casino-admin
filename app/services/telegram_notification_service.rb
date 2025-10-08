class TelegramNotificationService
  class << self
    def send_message(message)
      return unless TelegramConfig.enabled?
      return if TelegramConfig.bot_token.blank? || TelegramConfig.chat_id.blank?

      begin
        Telegram.bot.send_message(
          chat_id: TelegramConfig.chat_id,
          text: message,
          parse_mode: 'HTML'
        )
        Rails.logger.info "Telegram notification sent successfully"
      rescue => e
        Rails.logger.error "Error sending Telegram notification: #{e.message}"
      end
    end

    def send_sync_start_notification
      return unless TelegramConfig.send_start_notification?
      
      message = "🎮 <b>Games Sync Started</b>\n" \
                "⏰ Time: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}\n" \
                "🔄 Starting blockchain sync process..."
      
      send_message(message)
    end

    def send_sync_completion_notification(new_games_count, updated_games_count, duration)
      return unless TelegramConfig.send_completion_notification?
      
      # Record the sync statistics for aggregation
      SyncStatisticsService.record_sync_stats(new_games_count, updated_games_count, duration)
      
      # Check if we should send an aggregated message
      if SyncStatisticsService.should_send_telegram?
        send_aggregated_notification
      else
        # Send individual notification if aggregation is disabled or not enough time has passed
        send_individual_sync_notification(new_games_count, updated_games_count, duration)
      end
    end

    def send_aggregated_notification
      stats = SyncStatisticsService.get_aggregated_stats
      
      message = "📊 <b>Games Sync Summary</b>\n" \
                "⏰ Time: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}\n" \
                "📈 Period: #{stats[:time_range]}\n" \
                "🔄 Syncs: #{stats[:sync_count]}\n" \
                "🆕 New games: #{stats[:total_new_games]}\n" \
                "🔄 Updated games: #{stats[:total_updated_games]}\n" \
                "⏱️ Total duration: #{stats[:total_duration].round(2)}s"
      
      send_message(message)
      
      # Record that we sent a telegram message
      SyncStatisticsService.record_telegram_sent
    end

    def send_individual_sync_notification(new_games_count, updated_games_count, duration)
      message = "✅ <b>Games Sync Completed</b>\n" \
                "⏰ Time: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}\n" \
                "🆕 New games: #{new_games_count}\n" \
                "🔄 Updated games: #{updated_games_count}\n" \
                "⏱️ Duration: #{duration.round(2)}s"
      
      send_message(message)
    end

    def send_sync_error_notification(error_message)
      return unless TelegramConfig.send_error_notification?
      
      message = "❌ <b>Games Sync Failed</b>\n" \
                "⏰ Time: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}\n" \
                "🚨 Error: #{error_message}"
      
      send_message(message)
    end
  end
end

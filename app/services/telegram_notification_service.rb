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

    def record_sync_and_notify_if_needed(new_games_count, updated_games_count)
      return unless TelegramConfig.send_completion_notification?
      
      # Record the sync statistics for aggregation
      SyncStatisticsService.record_sync_stats(new_games_count, updated_games_count)
      
      # Only send aggregated messages at the configured interval
      if SyncStatisticsService.should_send_telegram?
        stats = SyncStatisticsService.get_aggregated_stats

        if stats[:total_new_games] == 0 && stats[:total_updated_games] == 0
          message = "No games\n" \
                    "Period: #{stats[:time_range]}\n" \
                    "#{stats[:sync_count]} syncs"
        else
          message = "#{stats[:total_new_games]} new games\n" \
                    "#{stats[:total_updated_games]} games updated\n" \
                    "#{stats[:sync_count]} syncs"
          
          # Add cost calculations if there are games
          if stats[:total_new_games] > 0 || stats[:total_updated_games] > 0
            cost_data = self.calculate_average_costs(stats[:total_new_games])
            if cost_data[:player_cost] && cost_data[:house_cost]
              message += "\n\n#{cost_data[:player_cost]} avg player costs\n" \
                        "#{cost_data[:house_cost]} avg house costs"
            end
          end
        end

        send_message(message)

        # Record that we sent a telegram message
        SyncStatisticsService.record_telegram_sent
      end
    end

    def send_sync_error_notification(error_message)
      return unless TelegramConfig.send_error_notification?
      
      message = "❌ <b>Games Sync Failed</b>\n" \
                "⏰ Time: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}\n" \
                "🚨 Error: #{error_message}"
      
      send_message(message)
    end

    private

    def self.calculate_average_costs(new_games_count)
      # Get the last X games based on new games count, or default to 10
      limit = [new_games_count, 10].max
      
      # Calculate average costs from recent transactions
      house_cost = Transaction.house_average_cost
      player_cost = Transaction.player_average_cost
      
      if house_cost && player_cost
        {
          house_cost: format_cost(house_cost),
          player_cost: format_cost(player_cost)
        }
      else
        { house_cost: nil, player_cost: nil }
      end
    end

    def self.format_cost(cost_in_wei)
      return "0.0000" if cost_in_wei.nil? || cost_in_wei == 0
      
      # Convert from wei to ETH and format to 4 decimal places
      eth_cost = cost_in_wei.to_f / 10**18
      sprintf("%.4f", eth_cost)
    end
  end
end

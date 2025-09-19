# Configure telegram-bot gem
require 'telegram/bot'

# Load Telegram configuration from YAML file
telegram_config = Rails.application.config_for(:telegram)

# Get bot token and chat ID from environment variables (required)
bot_token = ENV['TELEGRAM_BOT_TOKEN']
chat_id = ENV['TELEGRAM_CHAT_ID']

# Override configuration with environment variables
telegram_config['bot'] = bot_token if bot_token.present?
telegram_config['chat_id'] = chat_id if chat_id.present?
telegram_config['enabled'] = ENV['TELEGRAM_ENABLED'] == 'true' if ENV['TELEGRAM_ENABLED']
telegram_config['send_start_notification'] = ENV['TELEGRAM_SEND_START'] == 'true' if ENV['TELEGRAM_SEND_START']
telegram_config['send_completion_notification'] = ENV['TELEGRAM_SEND_COMPLETION'] == 'true' if ENV['TELEGRAM_SEND_COMPLETION']
telegram_config['send_error_notification'] = ENV['TELEGRAM_SEND_ERROR'] == 'true' if ENV['TELEGRAM_SEND_ERROR']

# Configure telegram-bot gem only if bot token is available
if bot_token.present?
  Telegram.bots_config = {
    default: bot_token
  }
else
  Rails.logger.warn "TELEGRAM_BOT_TOKEN environment variable not set. Telegram notifications will be disabled."
end

# Make configuration available throughout the application
Rails.application.config.telegram = telegram_config

# Create a convenient accessor method
module TelegramConfig
  def self.bot_token
    Rails.application.config.telegram['bot']
  end

  def self.chat_id
    Rails.application.config.telegram['chat_id']
  end

  def self.enabled?
    Rails.application.config.telegram['enabled'] && bot_token.present? && chat_id.present?
  end

  def self.send_start_notification?
    Rails.application.config.telegram['send_start_notification']
  end

  def self.send_completion_notification?
    Rails.application.config.telegram['send_completion_notification']
  end

  def self.send_error_notification?
    Rails.application.config.telegram['send_error_notification']
  end
end

# frozen_string_literal: true

# Load CLOUD_CONVERSION config
CLOUD_CONVERSION = Rails.application.config_for(:cloud_conversion).deep_symbolize_keys

# Save app version in APP_VERSION constant
APP_VERSION = File.read(Rails.root.join('VERSION')).strip

Rails.application.config.active_job.queue_adapter = :inline if CLOUD_CONVERSION['run_queued_jobs_inline']

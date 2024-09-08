# frozen_string_literal: true

class ConversionJob < ApplicationJob
  queue_as CloudConversion::Queues::CONVERSION

  def perform(src_bucket_name, src_object_key, dst_bucket_name, dst_object_key, size)
    CloudConversion::Aws::Conversion.image_to_image(
      src_bucket_name,
      src_object_key,
      dst_bucket_name,
      dst_object_key,
      size
    )
  end
end

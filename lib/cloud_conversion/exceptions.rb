# frozen_string_literal: true

module CloudConversion::Exceptions
  class CloudConversionError < StandardError; end

  class BucketNotFoundError < CloudConversionError; end
  class ObjectNotFoundError < CloudConversionError; end
  class UnexpectedUploadError < CloudConversionError; end
  class ObjectAlreadyExistsError < CloudConversionError; end
end

# frozen_string_literal: true

module CloudConversion::Aws::Conversion
  def self.with_source_tempfile(src_bucket_name, src_object_key)
    src_extname = File.extname(src_object_key)

    Tempfile.create(['infile', src_extname]) do |tempfile|
      begin
        S3_CLIENT.get_object({
          response_target: tempfile.path,
          bucket: src_bucket_name,
          key: src_object_key
        })
      rescue Aws::S3::Errors::NoSuchBucket
        raise CloudConversion::Exceptions::BucketNotFoundError, "Could not find bucket: #{src_bucket_name}"
      rescue Aws::S3::Errors::NoSuchKey
        raise CloudConversion::Exceptions::ObjectNotFoundError, "Could not find object: #{src_object_key}"
      end
      yield tempfile
    end
  end

  def self.object_exists?(dst_bucket_name, dst_object_key)
    S3_CLIENT.head_object({ bucket: dst_bucket_name, key: dst_object_key })
    true
  rescue Aws::S3::Errors::NotFound
    false
  end

  # Reads the object at src_bucket_name/src_object_key and write an image derivative at dst_bucket_name/dst_object_key.
  # The derivative image will have a long side size equal to the given size parameter.
  # Note: This method will overwrite any existing object at dst_bucket_name/dst_object_key.
  def self.image_to_image(src_bucket_name, src_object_key, dst_bucket_name, dst_object_key, size)
    # First, verify that no object already exists at the destination location. This is for safety, to reduce the risk
    # of someone accidentally inputting their src object as a dst object and overwriting it.
    if object_exists?(dst_bucket_name, dst_object_key)
      raise CloudConversion::Exceptions::ObjectAlreadyExistsError,
            "An object already exists at the destination location: #{dst_bucket_name}/#{dst_object_key}"
    end

    dst_extname = File.extname(dst_object_key)

    self.with_source_tempfile(src_bucket_name, src_object_key) do |src_tempfile|
      Tempfile.create(['outfile', dst_extname]) do |temp_outfile|
        Imogen.with_image(src_tempfile.path) do |img|
          Imogen::Scaled.convert(img, temp_outfile.path, size)
        end

        begin
          resp = S3_CLIENT.put_object({
            body: temp_outfile,
            bucket: dst_bucket_name,
            key: dst_object_key,
            content_type: BestType.mime_type.for_file_name(temp_outfile.path)
          })

          # If resp.etag is present, then the file was uploaded successfully.
          self.raise_error_if_missing_etag(resp.etag, dst_bucket_name, dst_object_key)
        rescue Aws::S3::Errors::NoSuchBucket
          raise CloudConversion::Exceptions::BucketNotFoundError, "Could not find bucket: #{dst_bucket_name}"
        end
      end
    end

    true
  end

  def self.raise_error_if_missing_etag(etag, bucket_name, object_key)
    return if etag.present?

    raise CloudConversion::Exceptions::UnexpectedUploadError,
          'An unexpected error occurred while attempting to upload a file to '\
          "#{bucket_name}:#{object_key} (no etag received after upload). "\
          'Check manually to see if the file was uploaded successfully.'
  end
end

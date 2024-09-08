namespace :cloud_conversion do
  namespace :queue do
    desc  'Queue a job that converts the src_bucket_name/src_object_key object to a derivative version at '\
          'dst_bucket_name/dst_object_key (scaled to the given size)'
    task convert: :environment do
      missing_params = [
        'src_bucket_name', 'src_object_key', 'dst_bucket_name', 'dst_object_key', 'size'
      ].select { |param| ENV[param].blank? }

      if missing_params.present?
        puts "Missing required params: #{missing_params.join(', ')}"
        next
      end

      ConversionJob.perform_later(
        ENV['src_bucket_name'],
        ENV['src_object_key'],
        ENV['dst_bucket_name'],
        ENV['dst_object_key'],
        ENV['size'].to_i
      )
    end
  end

  namespace :queue_from_csv do
    desc  'Queue a job that converts the src_bucket_name/src_object_key object to a derivative version at '\
          'dst_bucket_name/dst_object_key (scaled to the given size)'
    task convert: :environment do
      missing_params = [
        'csv_path'
      ].select { |param| ENV[param].blank? }

      if missing_params.present?
        puts "Missing required params: #{missing_params.join(', ')}"
        next
      end

      # First pass: make sure that required values are present for all rows
      found_invalid_row = false
      CSV.foreach(ENV['csv_path'], headers: true).with_index do |row, i|
        if row['src_bucket_name'].blank? || row['src_object_key'].blank? || row['dst_bucket_name'].blank? || row['dst_object_key'].blank? || row['size'].blank?
          found_invalid_row = true
          # Add 2 to i to account for zero-based indexing AND the header row
          puts "CSV row number #{i + 2} is missing required values."
          break
        end
      end

      if found_invalid_row
        puts "Exiting because an invalid row was found during the validation.  Nothing has been queued for processing."
        next
      end

      # Second pass: queue jobs
      CSV.foreach(ENV['csv_path'], headers: true).with_index do |row, i|
        ConversionJob.perform_later(
            row['src_bucket_name'],
            row['src_object_key'],
            row['dst_bucket_name'],
            row['dst_object_key'],
            row['size'].to_i
        )
        # Add 1 to i to account for zero-based indexing
        puts "Queued #{i + 1}"
      end
    end
  end
end

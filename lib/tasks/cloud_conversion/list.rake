require 'csv'

namespace :cloud_conversion do
  namespace :list do
    desc  'List files under the given bucket path'
    task files: :environment do
      missing_params = [
        'bucket_name', 'prefix', 'output_csv_path'
      ].select { |param| ENV[param].blank? }

      if missing_params.present?
        puts "Missing required params: #{missing_params.join(', ')}"
        next
      end

      number_of_objects = 0
      next_continuation_token = nil
      CSV.open(ENV['output_csv_path'], 'wb') do |out_csv|
        out_csv << ['bucket', 'key', 'extension', 'size']
        loop do
          resp = S3_CLIENT.list_objects_v2({
            # 1000 is the max supported by the AWS API, but I'm explicitly entering it here
            # anyway to be clear about this limit.
            max_keys: 1000,
            bucket: ENV['bucket_name'],
            prefix: ENV['prefix'],
            continuation_token: next_continuation_token
          })

          contents = resp.contents
          next_continuation_token = resp.next_continuation_token
          number_of_objects += contents.length

          resp.contents.each do |obj|
            out_csv << [
              ENV['bucket_name'],
              obj.key,
              File.extname(obj.key)[1..],
              obj.size
            ]
          end

          puts "Processed: #{number_of_objects}"
          break if next_continuation_token.nil?
        end
      end
    end
  end
end

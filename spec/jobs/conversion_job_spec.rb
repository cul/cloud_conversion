# frozen_string_literal: true

require 'rails_helper'

describe ConversionJob do
  subject(:conversion_job) { described_class.new }

  let(:src_bucket_name) { 'source-bucket' }
  let(:src_object_key) { 'source-object-key.jpg' }
  let(:dst_bucket_name) { 'destination-bucket' }
  let(:dst_object_key) { 'destination-object-key.jpg' }
  let(:size) { 1200 }

  describe '#perform' do
    it 'works as expected' do
      expect(CloudConversion::Aws::Conversion).to receive(:image_to_image).with(
        src_bucket_name, src_object_key,
        dst_bucket_name, dst_object_key,
        size
      )
      conversion_job.perform(
        src_bucket_name, src_object_key,
        dst_bucket_name, dst_object_key,
        size
      )
    end
  end
end

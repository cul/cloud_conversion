# frozen_string_literal: true

# rubocop:disable RSpec/MultipleExpectations

require 'rails_helper'

describe CloudConversion::Aws::Conversion do
  before do
    allow(S3_CLIENT).to receive(:get_object) do |params|
      # We'll fake the client download by copying a fixture file to the given params[:response_target] location
      FileUtils.cp(
        Rails.root.join('spec/fixtures/files/sample.jpg'),
        params[:response_target]
      )
    end
  end

  describe '.with_source_tempfile' do
    let(:bucket_name) { 'example-bucket' }
    let(:object_key) { 'example-object-key' }

    it 'yields a file' do
      expect { |block|
        described_class.with_source_tempfile(bucket_name, object_key, &block)
      }.to yield_with_args(File)
    end

    it 'cleans up the file after the block completes' do
      tempfile_path = nil
      described_class.with_source_tempfile(bucket_name, object_key) do |tempfile|
        tempfile_path = tempfile.path
        expect(File.exist?(tempfile_path)).to eq(true)
      end
      expect(tempfile_path.length).to be_positive
      expect(File.exist?(tempfile_path)).to eq(false)
    end
  end

  describe '.object_exists?' do
    let(:bucket_name) { 'example-bucket' }
    let(:object_key) { 'example-object-key' }

    context 'when an object exists in s3 at the given location' do
      before do
        allow(S3_CLIENT).to receive(:head_object).with({ bucket: bucket_name, key: object_key })
      end

      it 'returns true' do
        expect(described_class.object_exists?(bucket_name, object_key)).to eq(true)
      end
    end

    context 'when an object does not exist in s3 at the given location' do
      before do
        allow(S3_CLIENT).to receive(:head_object).and_raise(Aws::S3::Errors::NotFound.new(nil, nil))
      end

      it 'returns true' do
        expect(described_class.object_exists?(bucket_name, object_key)).to eq(false)
      end
    end
  end

  describe '.image_to_image' do
    let(:src_bucket_name) { 'source-bucket' }
    let(:src_object_key) { 'source-object-key.jpg' }
    let(:dst_bucket_name) { 'destination-bucket' }
    let(:dst_object_key) { 'destination-object-key.jpg' }
    let(:size) { 1200 }
    let(:etag) { 'etagvalue' }
    let(:successful_s3_put_response) do
      resp = Aws::S3::Types::PutObjectOutput.new
      resp.etag = etag
      resp
    end

    context 'when an object does not exist at the target location' do
      before do
        allow(described_class).to receive(:object_exists?).with(dst_bucket_name, dst_object_key).and_return(false)
      end

      it 'reads the source image, converts it to the desired format, and writes it to the correct destination' do
        expect(S3_CLIENT).to receive(:put_object) { |params|
          expect(params[:body]).to be_a(File)
        }.and_return(successful_s3_put_response)
        expect(described_class).to receive(:raise_error_if_missing_etag).with(
          etag, dst_bucket_name, dst_object_key
        )
        expect(
          described_class.image_to_image(src_bucket_name, src_object_key, dst_bucket_name, dst_object_key, size)
        ).to eq(true)
      end
    end

    context 'when an object already exists at the target location' do
      before do
        allow(described_class).to receive(:object_exists?).with(dst_bucket_name, dst_object_key).and_return(true)
      end

      it 'raises an error' do
        expect {
          described_class.image_to_image(src_bucket_name, src_object_key, dst_bucket_name, dst_object_key, size)
        }.to raise_error(CloudConversion::Exceptions::ObjectAlreadyExistsError)
      end
    end

    context 'when the destination bucket is not found' do
      before do
        allow(described_class).to receive(:object_exists?).with(dst_bucket_name, dst_object_key).and_return(false)
        allow(S3_CLIENT).to receive(:put_object).and_raise(Aws::S3::Errors::NoSuchBucket.new(nil, nil))
      end

      it 'raises an error' do
        expect {
          described_class.image_to_image(src_bucket_name, src_object_key, dst_bucket_name, dst_object_key, size)
        }.to raise_error(CloudConversion::Exceptions::BucketNotFoundError)
      end
    end
  end

  describe '.raise_error_if_missing_etag' do
    let(:bucket_name) { 'example-bucket' }
    let(:object_key) { 'example-object-key' }

    it 'does not raise an error when a positive-length etag string is provided' do
      expect {
        described_class.raise_error_if_missing_etag('etagvalue', bucket_name, object_key)
      }.not_to raise_error
    end

    it 'raises an error when an empty string etag value is provided' do
      expect {
        described_class.raise_error_if_missing_etag('', bucket_name, object_key)
      }.to raise_error(CloudConversion::Exceptions::UnexpectedUploadError)
    end

    it 'raises an error when a nil etag value is provided' do
      expect {
        described_class.raise_error_if_missing_etag(nil, bucket_name, object_key)
      }.to raise_error(CloudConversion::Exceptions::UnexpectedUploadError)
    end
  end
end

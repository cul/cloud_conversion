# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    email { 'example@example.com' }
    password { 'greatpassword' }
  end
end

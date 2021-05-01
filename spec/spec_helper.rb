# frozen_string_literal: true

require 'json'
require 'open-uri'
require_relative '../lib/settings'

# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end

# Load data.json
DATA = JSON.parse(URI.parse('https://raw.githubusercontent.com/MeditationDuck/covid19/development/data/data.json').open.read)

def find_data(id)
  DATA['patients']['data'].find { |d| d['id'] == id }
end

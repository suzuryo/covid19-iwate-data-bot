#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'typhoeus'
require 'slack-notifier'

urls = %w[
  https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/052/938/shinryokensalist_040901-1.pdf
]

def check_urls(urls)
  hydra = Typhoeus::Hydra.new(max_concurrency: 10)

  requests = urls.uniq.map do |url|
    request = Typhoeus::Request.new(
      url,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/104.0.0.0 Safari/537.36'
      },
      method: :get,
      followlocation: true,
      timeout: 3
    )
    hydra.queue(request)
    request
  end

  hydra.run

  slack_msg = ''
  requests.map do |request|
    hexdigest = Digest::SHA256.hexdigest(request.response.body)
    response_code = request.response.response_code
    slack_msg += "#{Time.now}\n#{hexdigest}\n" if hexdigest != 'be4b7d1662617a12f62eefd99230d65c88898df6a9db99189a92477edacf5ee6'
    slack_msg += "#{Time.now}\n#{response_code} #{request.base_url}\n" if response_code != 200
  end

  return if slack_msg.size.zero?

  p slack_msg

  # When slack_msg is not blank
  notifier = Slack::Notifier.new ENV.fetch('SLACK_WEBHOOK', nil) do
    defaults channel: '#check_link',
             username: 'check_link'
  end
  notifier.ping slack_msg
  raise 'slack_msg is not blank' unless slack_msg.size.zero?
end

check_urls(urls)

#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'typhoeus'
require 'slack-notifier'

urls = [
  {
    url: 'https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/052/938/shinryokensalist_040930-1.pdf',
    hexdigest: '537410aa269f61c380fae5eede19bb78577ccea7b1e95fe679d4348f69328806'
  }
]

def check_urls(urls)
  hydra = Typhoeus::Hydra.new(max_concurrency: 10)

  requests = urls.uniq.map do |url|
    request = Typhoeus::Request.new(
      url[:url],
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
    slack_msg += "#{Time.now}\n#{hexdigest}\n" unless urls.map { |url| url[:hexdigest] }.include? hexdigest
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

#!/usr/bin/env ruby
# frozen_string_literal: true

require 'typhoeus'
require 'slack-notifier'

urls = %w[
  https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/052/938/040817_itiran.pdf
]

def check_urls(urls)
  hydra = Typhoeus::Hydra.new(max_concurrency: 10)

  requests = urls.uniq.map do |url|
    request = Typhoeus::Request.new(
      url,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/104.0.0.0 Safari/537.36'
      },
      method: :head,
      followlocation: true,
      timeout: 3
    )
    hydra.queue(request)
    request
  end

  hydra.run

  slack_msg = ''
  requests.map do |request|
    slack_msg += "#{Time.now}\n#{request.response.response_code} #{request.base_url}\n" if request.response.response_code != 200
  end

  return if slack_msg.size.zero?

  notifier = Slack::Notifier.new ENV.fetch('SLACK_WEBHOOK', nil) do
    defaults channel: '#check_link',
             username: 'check_link'
  end
  notifier.ping slack_msg
end

check_urls(urls)

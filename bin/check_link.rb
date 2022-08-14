#!/usr/bin/env ruby
# frozen_string_literal: true

require 'typhoeus'

urls = %w[
  https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/052/938/040812_itiran10.pdf
  https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/052/938/040813_obon8.pdf
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

  requests.map do |request|
    puts Time.now
    puts "#{request.response.response_code} #{request.base_url}" if request.response.response_code != 201
  end
end

check_urls(urls)

#!/usr/bin/env ruby
# frozen_string_literal: true

def urls_json(urls, now)
  json = {
    date: now.iso8601,
    items: []
  }

  urls.each do |row|
    json[:items].append(
      {
        item: row['item'].blank? ? nil : row['item'],
        url: row['url'].blank? ? nil : row['url']
      }
    )
  end

  File.write(File.join(__dir__, '../../data/', 'urls.json'), JSON.pretty_generate(json))
end

#!/usr/bin/env ruby
# frozen_string_literal: true

def news_json(news, now)
  json = {
    date: now.iso8601,
    newsItems: []
  }

  news.each do |row|
    json[:newsItems].append(
      {
        date: Time.parse(row['date']).strftime('%Y-%m-%d'),
        url: {
          ja: row['url_ja'].blank? ? nil : row['url_ja'],
          en: row['url_en'].blank? ? nil : row['url_en']
        },
        text: {
          ja: row['text_ja'].blank? ? nil : row['text_ja'],
          en: row['text_en'].blank? ? nil : row['text_en']
        }
      }
    )
  end

  File.write(File.join(__dir__, '../../data/', 'news.json'), JSON.pretty_generate(json))
end

#!/usr/bin/env ruby
# frozen_string_literal: true

def positive_status_json(hospitalized_numbers, now)
  json = {
    date: now.iso8601,
    data: []
  }

  hospitalized_numbers.each do |row|
    json[:data].append(
      {
        date: Time.parse(row['date']).strftime('%Y-%m-%d'),
        hospital: row['入院'].to_i,
        hotel: row['宿泊療養'].to_i,
        home: row['自宅療養'].to_i,
        waiting: row['調整中'].to_i
      }
    )
  end

  File.write(File.join(__dir__, '../../data/', 'positive_status.json'), JSON.pretty_generate(json))
end

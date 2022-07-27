#!/usr/bin/env ruby
# frozen_string_literal: true

def daily_positive_detail_json(positive_by_diagnosed, now)
  json = {
    date: now.iso8601,
    data: []
  }

  positive_by_diagnosed.each do |row|
    json[:data].append(
      {
        diagnosed_date: Time.parse(row['diagnosed_date']).strftime('%Y-%m-%d'),
        count: row['count'].to_i,
        missing_count: row['missing_count'].to_i,
        reported_count: row['reported_count'].to_i,
        # weekly_gain_ratio: nil, # 未使用
        # untracked_percent: nil, # 未使用
        weekly_average_count: row['weekly_average_count'].blank? ? nil : row['weekly_average_count'].to_f,
        weekly_average_untracked_count: row['weekly_average_untracked_count'].blank? ? nil : row['weekly_average_untracked_count'].to_f,
        # weekly_average_untracked_increse_percent: row['weekly_average_untracked_increse_percent'].blank? ? nil : row['weekly_average_untracked_increse_percent'].to_f 未使用
      }
    )
  end

  File.write(File.join(__dir__, '../../data/', 'daily_positive_detail.json'), JSON.pretty_generate(json))
end

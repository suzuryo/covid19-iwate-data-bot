#!/usr/bin/env ruby
# frozen_string_literal: true

def daily_positive_detail_json(positive_by_diagnosed, now)
  json = {
    date: now.iso8601,
    data: []
  }

  # diagnosed_date: 日付
  # count: 陽性の数
  # missing_count: 接触歴不明の数
  # reported_count: 接触歴判明の数
  # weekly_average_count: 陽性者数の7日間移動平均
  # weekly_average_untracked_count: 接触歴等不明者数（７日間移動平均）

  positive_by_diagnosed.each do |row|
    json[:data].append(
      {
        diagnosed_date: Time.parse(row['diagnosed_date']).strftime('%Y-%m-%d'),
        count: row['count'].to_i,
        missing_count: row['missing_count'].to_i,
        reported_count: row['reported_count'].to_i,
        weekly_average_count: row['weekly_average_count'].blank? ? nil : row['weekly_average_count'].to_f,
        weekly_average_untracked_count: row['weekly_average_untracked_count'].blank? ? nil : row['weekly_average_untracked_count'].to_f
      }
    )
  end
  File.write(File.join(__dir__, '../../data/', 'daily_positive_detail.json'), JSON.pretty_generate(json))
end

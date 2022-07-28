#!/usr/bin/env ruby
# frozen_string_literal: true

def daily_positive_detail_json(patients_summary, now)
  daily_positive_detail_until20220726 = JSON.parse(File.read(File.join(__dir__, '../../data_archived/daily_positive_detail.json')))['data']

  end_date = Date.parse(LAST_DATE)
  start_date = end_date.days_ago(6)
  date_range = start_date..end_date

  archived_positive_detail_until20220725 = daily_positive_detail_until20220726.select do |patient|
    date_range.cover? Date.parse(patient['diagnosed_date'])
  end

  patients_summary_data = patients_summary.select do |patient|
    date_range.cover? Date.parse(patient['date'])
  end

  json = {
    date: now.iso8601,
    data: []
  }

  daily_positive_detail_until20220726.each do |row|
    json[:data].append(row)
  end

  # diagnosed_date: 日付
  # count: 陽性の数
  # missing_count: 接触歴不明の数
  # reported_count: 接触歴判明の数
  # weekly_average_count: 陽性者数の7日間移動平均
  # weekly_average_untracked_count: 接触歴等不明者数（７日間移動平均）

  patients_summary.each do |row|
    json[:data].append(
      {
        diagnosed_date: row['date'],
        count: row['ありなし計'].to_i,
        missing_count: row['なし県'].to_i + row['なし盛岡市'].to_i,
        reported_count: row['あり計'].to_i,
        weekly_average_count: ((archived_positive_detail_until20220725.reduce(0) { |sum, item| sum + item['count'].to_i } + patients_summary_data.reduce(0) { |sum, item| sum + item['ありなし計'].to_i }) / 7.0).round(2),
        weekly_average_untracked_count: ((archived_positive_detail_until20220725.reduce(0) { |sum, item| sum + item['missing_count'].to_i } + patients_summary_data.reduce(0) { |sum, item| sum + item['なし県'].to_i + item['なし盛岡市'].to_i }) / 7.0).round(2)
      }
    )
  end
  File.write(File.join(__dir__, '../../data/', 'daily_positive_detail.json'), JSON.pretty_generate(json))
end

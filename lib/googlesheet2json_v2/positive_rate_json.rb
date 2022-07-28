#!/usr/bin/env ruby
# frozen_string_literal: true

def positive_rate_json(positive_rate, now)
  json = {
    date: now.iso8601,
    data: []
  }

  # diagnosed_date: 日時
  # positive_count: PCR検査件数陽性件数 + 抗原検査陽性件数
  # pcr_positive_count: 陽性者数
  # antigen_positive_count: 抗原検査陽性件数
  # pcr_negative_count: PCR陰性件数
  # antigen_negative_count: 抗原検査陰性件数
  # weekly_average_diagnosed_count: 検査件数（７日間移動平均）
  # positive_rate: 陽性率：陽性判明数（PCR・抗原）の移動平均／検査件数（＝陽性判明数（PCR・抗原）＋陰性判明数（PCR・抗原））の移動平均
  # weekly_average_positive_count: 陽性者数（7日間移動平均）

  positive_rate.each do |row|
    json[:data].append(
      {
        diagnosed_date: Time.parse(row['diagnosed_date']).strftime('%Y-%m-%d'),
        positive_count: row['positive_count'].blank? ? nil : row['positive_count'].to_i,
        pcr_positive_count: row['pcr_positive_count'].blank? ? nil : row['pcr_positive_count'].to_i,
        antigen_positive_count: row['antigen_positive_count'].blank? ? nil : row['antigen_positive_count'].to_i,
        pcr_negative_count: row['pcr_negative_count'].blank? ? nil : row['pcr_negative_count'].to_i,
        antigen_negative_count: row['antigen_negative_count'].blank? ? nil : row['antigen_negative_count'].to_i,
        weekly_average_diagnosed_count: row['weekly_average_diagnosed_count'].blank? ? nil : row['weekly_average_diagnosed_count'].to_f,
        positive_rate: row['positive_rate'].blank? ? nil : row['positive_rate'].to_f,
        weekly_average_positive_count: row['weekly_average_positive_count'].blank? ? nil : row['weekly_average_positive_count'].to_f
      }
    )
  end

  File.write(File.join(__dir__, '../../data/', 'positive_rate.json'), JSON.pretty_generate(json))
end

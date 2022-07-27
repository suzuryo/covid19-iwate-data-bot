#!/usr/bin/env ruby
# frozen_string_literal: true

def main_summary_json(patients, positive_by_diagnosed, hospitalized_numbers, now)
  json = {
    date: now.iso8601,
    陽性者数: patients.size,
    陽性者数前日差: positive_by_diagnosed[-1]['count'].to_i,
    入院: hospitalized_numbers[-1]['入院'].to_i,
    入院前日差: hospitalized_numbers[-1]['入院'].to_i - hospitalized_numbers[-2]['入院'].to_i,
    重症: hospitalized_numbers[-1]['重症'].to_i,
    重症前日差: hospitalized_numbers[-1]['重症'].to_i - hospitalized_numbers[-2]['重症'].to_i,
    宿泊療養: hospitalized_numbers[-1]['宿泊療養'].to_i,
    宿泊療養前日差: hospitalized_numbers[-1]['宿泊療養'].to_i - hospitalized_numbers[-2]['宿泊療養'].to_i,
    自宅療養: hospitalized_numbers[-1]['自宅療養'].to_i,
    自宅療養前日差: hospitalized_numbers[-1]['自宅療養'].to_i - hospitalized_numbers[-2]['自宅療養'].to_i,
    調整中: hospitalized_numbers[-1]['調整中'].to_i,
    調整中前日差: hospitalized_numbers[-1]['調整中'].to_i - hospitalized_numbers[-2]['調整中'].to_i,
    死亡: hospitalized_numbers[-1]['死亡'].to_i,
    死亡前日差: hospitalized_numbers[-1]['死亡'].to_i - hospitalized_numbers[-2]['死亡'].to_i,
    退院等: hospitalized_numbers[-1]['退院等'].to_i,
    退院等前日差: hospitalized_numbers[-1]['退院等'].to_i - hospitalized_numbers[-2]['退院等'].to_i
  }

  File.write(File.join(__dir__, '../../data/', 'main_summary.json'), JSON.pretty_generate(json))
end

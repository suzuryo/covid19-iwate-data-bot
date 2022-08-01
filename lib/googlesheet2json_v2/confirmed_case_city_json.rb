#!/usr/bin/env ruby
# frozen_string_literal: true

# 市町村別の陽性数を発表し始めたのが2022/07/26なので、データはその日付から始まる。
# それまでは保健所管内として公表されるのが多かったので、市町村別での実数が出せなかった。

def confirmed_case_city_json(patients_summary, now)
  city_json = {
    date: now.iso8601,
    data: []
  }

  city_json[:data] = patients_summary.map do |row|
    d = row.select { |key, _val| CITY_AREA.keys.include? key }.transform_values(&:to_i)

    {
      date: Date.parse(row['date']).strftime('%Y-%m-%d'),
      data: d
    }
  end

  File.write(File.join(__dir__, '../../data/', 'confirmed_case_city.json'), JSON.pretty_generate(city_json))
end

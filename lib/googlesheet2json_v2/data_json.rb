#!/usr/bin/env ruby
# frozen_string_literal: true

def data_json
  json = {
    patients: {
      date: NOW.iso8601,
      data: []
    },
    patients_summary: {
      date: NOW.iso8601,
      data: []
    },
    lastUpdate: NOW.iso8601
  }

  PATIENTS.each do |row|
    json[:patients][:data].append(
      {
        id: row['id'].to_i,
        確定日: row['確定日'].blank? ? nil : Date.parse(row['確定日']).strftime('%Y-%m-%d'),
        発症日: row['発症日'].blank? ? nil : Date.parse(row['発症日']).strftime('%Y-%m-%d'),
        無症状: row['無症状'] == '無症状',
        年代: row['年代'].blank? ? nil : row['年代'],
        居住地: row['居住地'].blank? ? nil : row['居住地'],
        滞在地: row['滞在地'].blank? ? nil : row['滞在地'],
        url: row['url'].blank? ? nil : row['url'],
        接触歴: row['接触歴'].blank? ? nil : row['接触歴']
      }
    )
  end

  # データ最終日は検査結果の最終日が基本だけど、 当日のデータ発表後は Date.today
  patients_summary_last_date = Date.parse(LAST_DATE) == YESTERDAY ? TODAY : YESTERDAY

  (FIRST_DATE..patients_summary_last_date).each do |date|
    output_patients_sum = 0
    PATIENTS.each do |row|
      output_patients_sum += 1 if row['リリース日'] == date.strftime('%Y/%m/%d')
    end

    json[:patients_summary][:data].append(
      {
        日付: date.strftime('%Y-%m-%d'),
        小計: output_patients_sum
      }
    )
  end

  File.write(File.join(__dir__, '../../data/', 'data.json'), JSON.pretty_generate(json))
end

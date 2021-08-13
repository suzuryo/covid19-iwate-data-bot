#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'time'
require 'date'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/date'
require_relative '../lib/googlesheets'

GoogleSheets = GoogleSheetsIwate.new

# ここまで Google Sheets API を使うための Quickstart テンプレ
# https://developers.google.com/sheets/api/quickstart/ruby

######################################################################
# Google Sheets から batch_get_spreadsheet_values した値をシートごとに Hash の Array にする
######################################################################

PATIENTS = GoogleSheets.data(GoogleSheetsIwate::SHEET_RANGES[:PATIENTS])
raise if PATIENTS.empty?

PATIENT_MUNICIPALITIES = GoogleSheets.data(GoogleSheetsIwate::SHEET_RANGES[:PATIENT_MUNICIPALITIES])
raise if PATIENT_MUNICIPALITIES.empty?

POSITIVE_BY_DIAGNOSED = GoogleSheets.data(GoogleSheetsIwate::SHEET_RANGES[:POSITIVE_BY_DIAGNOSED])
raise if POSITIVE_BY_DIAGNOSED.empty?

POSITIVE_RATE = GoogleSheets.data(GoogleSheetsIwate::SHEET_RANGES[:POSITIVE_RATE])
raise if POSITIVE_RATE.empty?

HOSPITALIZED_NUMBERS = GoogleSheets.data(GoogleSheetsIwate::SHEET_RANGES[:HOSPITALIZED_NUMBERS])
raise if HOSPITALIZED_NUMBERS.empty?

NEWS = GoogleSheets.data(GoogleSheetsIwate::SHEET_RANGES[:NEWS])
raise if NEWS.empty?

ALERT = GoogleSheets.data(GoogleSheetsIwate::SHEET_RANGES[:ALERT])
raise if ALERT.empty?

SELF_DISCLOSURES = GoogleSheets.data(GoogleSheetsIwate::SHEET_RANGES[:SELF_DISCLOSURES])
raise if SELF_DISCLOSURES.empty?

######################################################################
# データ生成 テンプレート
# data.json
######################################################################
# データを生成した日時
now = Time.now
# データの最初の日
first_date = Date.new(2020, 2, 15)
data_json = {
  patients: {
    date: now.iso8601,
    data: []
  },
  patients_summary: {
    date: now.iso8601,
    data: []
  },
  lastUpdate: now.iso8601
}

######################################################################
# data.json
# patients の生成
######################################################################
PATIENTS.each do |row|
  data_json[:patients][:data].append(
    {
      id: row['id'].to_i,
      # リリース日: row['リリース日'].blank? ? nil : Time.parse(row['リリース日']).iso8601, # 利用していないので出力しない
      確定日: row['確定日'].blank? ? nil : Date.parse(row['確定日']).strftime('%Y-%m-%d'),
      発症日: row['発症日'].blank? ? nil : Date.parse(row['発症日']).strftime('%Y-%m-%d'),
      無症状: row['無症状'] == '無症状',
      # 通番: row['通番'].blank? ? nil : row['通番'],
      年代: row['年代'].blank? ? nil : row['年代'],
      # 性別: row['性別'].blank? ? nil : row['性別'], # 利用していないので出力しない
      居住地: row['居住地'].blank? ? nil : row['居住地'],
      滞在地: row['滞在地'].blank? ? nil : row['滞在地'],
      url: row['url'].blank? ? nil : row['url'],
      yt: row['記者会見1'].blank? ? nil : /https:\/\/www\.youtube\.com\/watch\?v=(.+)$/.match(row['記者会見1'])[1],
      接触歴: row['接触歴'].blank? ? nil : row['接触歴']
    }
  )
end

######################################################################
# data.json
# patients_summary の生成
######################################################################

# データ最終日は検査結果の最終日が基本だけど、 当日のデータ発表後は Date.today
patients_summary_last_date = Date.parse(POSITIVE_RATE[-1]['diagnosed_date']) == Date.yesterday ? Date.today : Date.yesterday

(first_date..patients_summary_last_date).each do |date|
  output_patients_sum = 0
  PATIENTS.each do |row|
    output_patients_sum += 1 if row['リリース日'] == date.strftime('%Y/%m/%d')
  end

  data_json[:patients_summary][:data].append(
    {
      日付: date.strftime('%Y-%m-%d'),
      小計: output_patients_sum
    }
  )
end

######################################################################
# データ生成 テンプレート
# data.patient_municipalities.json
######################################################################
data_patient_municipalities_json = {
  date: now.iso8601,
  datasets: {
    date: now.iso8601,
    data: []
  }
}

######################################################################
# data.patient_municipalities.json
# datasets の生成
######################################################################
PATIENT_MUNICIPALITIES.each do |row|
  data_patient_municipalities_json[:datasets][:data].append(
    {
      code: row['code'],
      area: row['area'],
      label: row['label'],
      ruby: row['ruby'],
      count: row['count'].to_i,
      count_per_population: row['count_per_population']
    }
  )
end

######################################################################
# データ生成 テンプレート
# positive_by_diagnosed.json
######################################################################
data_positive_by_diagnosed_json = {
  date: now.iso8601,
  data: []
}

######################################################################
# positive_by_diagnosed.json
# data の生成
######################################################################
(first_date..Date.parse(POSITIVE_RATE[-1]['diagnosed_date'])).each do |date|
  positive_by_diagnosed_sum = 0
  PATIENTS.each do |row|
    positive_by_diagnosed_sum += 1 if row['確定日'] == date.strftime('%Y-%m-%d')
  end

  data_positive_by_diagnosed_json[:data].append(
    {
      diagnosed_date: date.strftime('%Y-%m-%d'),
      count: positive_by_diagnosed_sum
    }
  )
end

######################################################################
# データ生成 テンプレート
# data_daily_positive_detail.json
######################################################################
data_daily_positive_detail_json = {
  date: now.iso8601,
  data: []
}

######################################################################
# data_daily_positive_detail.json
# data の生成
######################################################################
POSITIVE_BY_DIAGNOSED.each do |row|
  data_daily_positive_detail_json[:data].append(
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

######################################################################
# データ生成 テンプレート
# positive_rate.json
######################################################################
data_positive_rate_json = {
  date: now.iso8601,
  data: []
}

######################################################################
# positive_rate.json
# data の生成
######################################################################
POSITIVE_RATE.each do |row|
  data_positive_rate_json[:data].append(
    {
      diagnosed_date: Time.parse(row['diagnosed_date']).strftime('%Y-%m-%d'),
      positive_count: row['positive_count'].blank? ? nil : row['positive_count'].to_i,
      # negative_count: row['negative_count'].blank? ? nil : row['negative_count'].to_i, # 利用していないので出力しない
      pcr_positive_count: row['pcr_positive_count'].blank? ? nil : row['pcr_positive_count'].to_i,
      antigen_positive_count: row['antigen_positive_count'].blank? ? nil : row['antigen_positive_count'].to_i,
      pcr_negative_count: row['pcr_negative_count'].blank? ? nil : row['pcr_negative_count'].to_i,
      antigen_negative_count: row['antigen_negative_count'].blank? ? nil : row['antigen_negative_count'].to_i,
      weekly_average_diagnosed_count: row['weekly_average_diagnosed_count'].blank? ? nil : row['weekly_average_diagnosed_count'].to_f,
      positive_rate: row['positive_rate'].blank? ? nil : row['positive_rate'].to_f
    }
  )
end

######################################################################
# データ生成 テンプレート
# positive_status.json
######################################################################
data_positive_status_json = {
  date: now.iso8601,
  data: []
}

######################################################################
# positive_status.json
# data の生成
######################################################################
# 岩手県が個別事例の退院日を公表してくれたら Google Sheets の
# input_検査陽性者の状況 と output_hospitalized_numbers が必要なくなり、
# 個別事例の退院日で自動計算できる。けど今はできないから Google Sheetsで管理する。
# https://github.com/MeditationDuck/covid19/issues/485
#
# (Date.new(2020, 2, 15)..Date.today).each do |date|
#   hospitalized_sum = 0
#   not_hospitalized_sum = 0
#
#   OUTPUT_PATIENTS.values.each do |row|
#     if Date.parse(row['入院日']) <= date && row['退院日'] == ""
#       # 入院日がその日より過去 かつ 退院日が空
#       # その日は入院中
#       hospitalized_sum += 1
#     elsif Date.parse(row['入院日']) <= date && Date.parse(row['退院日']) >= date
#       # 入院日がその日より過去 かつ 退院日がその日より未来
#       # その日は入院中
#       hospitalized_sum += 1
#     elsif Date.parse(row['入院日']) <= date && Date.parse(row['退院日']) < date
#       # 入院日がその日以降 かつ 退院日がその日より過去
#       # 退院した
#       not_hospitalized_sum += 1
#     end
#   end
#
#   data_positive_status_json[:data].append(
#     {
#       "date": date.iso8601,
#       "hospitalized": hospitalized_sum,
#       "severe_case": nil # SevereCaseCard.vue を使っていないので未使用
#     }
#   )
# end

HOSPITALIZED_NUMBERS.each do |row|
  data_positive_status_json[:data].append(
    {
      date: Time.parse(row['date']).strftime('%Y-%m-%d'),
      hospital: row['入院'].to_i,
      hotel: row['宿泊療養'].to_i,
      home: row['自宅療養'].to_i,
      # hospitalized: row['入院'].to_i + row['宿泊療養'].to_i, # 未使用
      waiting: row['調整中'].to_i
      # severe_case: row['重症'].to_i, # 利用していないので出力しない
    }
  )
end

######################################################################
# データ生成 テンプレート
# news.json
######################################################################
data_news_json = {
  newsItems: []
}

NEWS.each do |row|
  data_news_json[:newsItems].append(
    {
      date: Time.parse(row['date']).strftime('%Y-%m-%d'),
      icon: row['icon'],
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

######################################################################
# データ生成 テンプレート
# alert.json
######################################################################
data_alert_json = {
  alertItems: []
}

ALERT.each do |row|
  data_alert_json[:alertItems].append(
    {
      date: Time.parse(row['date']).strftime('%Y-%m-%d'),
      icon: row['icon'],
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

######################################################################
# データ生成 テンプレート
# self_disclosures.json
######################################################################
data_self_disclosures_json = {
  newsItems: []
}

SELF_DISCLOSURES.each do |row|
  data_self_disclosures_json[:newsItems].append(
    {
      date: Time.parse(row['date']).strftime('%Y-%m-%d'),
      icon: row['icon'],
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

######################################################################
# main_summary.json
# main_summary の生成
######################################################################

data_main_summary = {
  date: now.iso8601,
  陽性者数: PATIENTS.size,
  陽性者数前日差: POSITIVE_BY_DIAGNOSED[-1]['count'].to_i,
  入院: HOSPITALIZED_NUMBERS[-1]['入院'].to_i,
  入院前日差: HOSPITALIZED_NUMBERS[-1]['入院'].to_i - HOSPITALIZED_NUMBERS[-2]['入院'].to_i,
  重症: HOSPITALIZED_NUMBERS[-1]['重症'].to_i,
  重症前日差: HOSPITALIZED_NUMBERS[-1]['重症'].to_i - HOSPITALIZED_NUMBERS[-2]['重症'].to_i,
  宿泊療養: HOSPITALIZED_NUMBERS[-1]['宿泊療養'].to_i,
  宿泊療養前日差: HOSPITALIZED_NUMBERS[-1]['宿泊療養'].to_i - HOSPITALIZED_NUMBERS[-2]['宿泊療養'].to_i,
  自宅療養: HOSPITALIZED_NUMBERS[-1]['自宅療養'].to_i,
  自宅療養前日差: HOSPITALIZED_NUMBERS[-1]['自宅療養'].to_i - HOSPITALIZED_NUMBERS[-2]['自宅療養'].to_i,
  調整中: HOSPITALIZED_NUMBERS[-1]['調整中'].to_i,
  調整中前日差: HOSPITALIZED_NUMBERS[-1]['調整中'].to_i - HOSPITALIZED_NUMBERS[-2]['調整中'].to_i,
  死亡: HOSPITALIZED_NUMBERS[-1]['死亡'].to_i,
  死亡前日差: HOSPITALIZED_NUMBERS[-1]['死亡'].to_i - HOSPITALIZED_NUMBERS[-2]['死亡'].to_i,
  退院等: HOSPITALIZED_NUMBERS[-1]['退院等'].to_i,
  退院等前日差: HOSPITALIZED_NUMBERS[-1]['退院等'].to_i - HOSPITALIZED_NUMBERS[-2]['退院等'].to_i
}

######################################################################
# write json
######################################################################

File.open(File.join(__dir__, '../data/', 'data.json'), 'w') do |f|
  f.write JSON.pretty_generate(data_json)
end

File.open(File.join(__dir__, '../data/', 'patient_municipalities.json'), 'w') do |f|
  f.write JSON.pretty_generate(data_patient_municipalities_json)
end

File.open(File.join(__dir__, '../data/', 'positive_by_diagnosed.json'), 'w') do |f|
  f.write JSON.pretty_generate(data_positive_by_diagnosed_json)
end

File.open(File.join(__dir__, '../data/', 'daily_positive_detail.json'), 'w') do |f|
  f.write JSON.pretty_generate(data_daily_positive_detail_json)
end

File.open(File.join(__dir__, '../data/', 'positive_rate.json'), 'w') do |f|
  f.write JSON.pretty_generate(data_positive_rate_json)
end

File.open(File.join(__dir__, '../data/', 'positive_status.json'), 'w') do |f|
  f.write JSON.pretty_generate(data_positive_status_json)
end

File.open(File.join(__dir__, '../data/', 'news.json'), 'w') do |f|
  f.write JSON.pretty_generate(data_news_json)
end

File.open(File.join(__dir__, '../data/', 'alert.json'), 'w') do |f|
  f.write JSON.pretty_generate(data_alert_json)
end

File.open(File.join(__dir__, '../data/', 'self_disclosures.json'), 'w') do |f|
  f.write JSON.pretty_generate(data_self_disclosures_json)
end

File.open(File.join(__dir__, '../data/', 'main_summary.json'), 'w') do |f|
  f.write JSON.pretty_generate(data_main_summary)
end

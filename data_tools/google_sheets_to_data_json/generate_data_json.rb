#!/usr/bin/env ruby
# coding: utf-8
# frozen_string_literal: true

require 'google/apis/sheets_v4'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
require 'json'
require 'time'
require 'date'
require 'csv'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/date'

OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
APPLICATION_NAME = 'iwate.stopcovid19.jp DATA JSON Converter'
CREDENTIALS_PATH = File.join(__dir__, 'credentials.json')
TOKEN_PATH = File.join(__dir__, 'token.yaml')
SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS_READONLY

def authorize
  client_id = Google::Auth::ClientId.from_file CREDENTIALS_PATH
  token_store = Google::Auth::Stores::FileTokenStore.new file: TOKEN_PATH
  authorizer = Google::Auth::UserAuthorizer.new client_id, SCOPE, token_store
  user_id = 'default'
  credentials = authorizer.get_credentials user_id
  if credentials.nil?
    url = authorizer.get_authorization_url base_url: OOB_URI
    puts 'Open the following URL in the browser and enter the ' \
         "resulting code after authorization:\n" + url
    code = gets
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code, base_url: OOB_URI
    )
  end
  credentials
end

# Initialize the API
service = Google::Apis::SheetsV4::SheetsService.new
service.client_options.application_name = APPLICATION_NAME
service.authorization = authorize

# ここまで Google Sheets API を使うための Quickstart テンプレ
# https://developers.google.com/sheets/api/quickstart/ruby

######################################################################
# Google Sheets から データを取得して CSV::Table にする
######################################################################
SPREADSHEET_ID = '1VjxD8YTwEngvkfYOLD-4JG1tA5AnzTlgnzDO1lkTlNc'

PATIENTS_CSV = CSV.parse(service.get_spreadsheet_values(SPREADSHEET_ID, 'output_patients').values.map(&:to_csv).join, headers: true)
raise if PATIENTS_CSV.empty?

CONTACTS_CSV = CSV.parse(service.get_spreadsheet_values(SPREADSHEET_ID, 'input_受診・相談センター_相談件数').values.map(&:to_csv).join, headers: true)
raise if CONTACTS_CSV.empty?

QUERENTS_CSV = CSV.parse(service.get_spreadsheet_values(SPREADSHEET_ID, 'input_一般_相談件数').values.map(&:to_csv).join, headers: true)
raise if QUERENTS_CSV.empty?

PATIENT_MUNICIPALITIES = CSV.parse(service.get_spreadsheet_values(SPREADSHEET_ID, 'output_patient_municipalities').values.map(&:to_csv).join, headers: true)
raise if PATIENT_MUNICIPALITIES.empty?

POSITIVE_BY_DIAGNOSED = CSV.parse(service.get_spreadsheet_values(SPREADSHEET_ID, 'output_positive_by_diagnosed').values.map(&:to_csv).join, headers: true)
raise if POSITIVE_BY_DIAGNOSED.empty?

POSITIVE_RATE = CSV.parse(service.get_spreadsheet_values(SPREADSHEET_ID, 'output_positive_rate').values.map(&:to_csv).join, headers: true)
raise if POSITIVE_RATE.empty?

HOSPITALIZED_NUMBERS = CSV.parse(service.get_spreadsheet_values(SPREADSHEET_ID, 'output_hospitalized_numbers').values.map(&:to_csv).join, headers: true)
raise if HOSPITALIZED_NUMBERS.empty?

NEWS = CSV.parse(service.get_spreadsheet_values(SPREADSHEET_ID, 'input_news').values.map(&:to_csv).join, headers: true)
raise if NEWS.empty?

ALERT = CSV.parse(service.get_spreadsheet_values(SPREADSHEET_ID, 'input_alert').values.map(&:to_csv).join, headers: true)
raise if ALERT.empty?

SELF_DISCLOSURES = CSV.parse(service.get_spreadsheet_values(SPREADSHEET_ID, 'input_self_disclosures').values.map(&:to_csv).join, headers: true)
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
  contacts: {
    date: now.iso8601,
    data: []
  },
  querents: {
    date: now.iso8601,
    data: []
  },
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
PATIENTS_CSV.each do |row|
  data_json[:patients][:data].append(
    {
      id: row['id'].to_i,
      # リリース日: row['リリース日'].blank? ? nil : Time.parse(row['リリース日']).iso8601, # 利用していないので出力しない
      確定日: row['確定日'].blank? ? nil : Time.parse(row['確定日']).iso8601,
      発症日: row['発症日'].blank? ? nil : Time.parse(row['発症日']).iso8601,
      無症状: row['無症状'] == '無症状' ? true : false,
      # 通番: row['通番'].blank? ? nil : row['通番'],
      年代: row['年代'].blank? ? nil : row['年代'],
      # 性別: row['性別'].blank? ? nil : row['性別'], # 利用していないので出力しない
      居住地: row['居住地'].blank? ? nil : row['居住地'],
      url: row['url'].blank? ? nil : row['url'],
      会見: row['記者会見1'].blank? ? nil : row['記者会見1'],
      接触歴: row['接触歴'].blank? ? nil : row['接触歴'],
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
  PATIENTS_CSV.each do |row|
    if row['リリース日'] == date.strftime('%Y/%m/%d')
      output_patients_sum += 1
    end
  end

  data_json[:patients_summary][:data].append(
    {
      日付: Time.new(date.year, date.month, date.day, 8, 0, 0).iso8601,
      小計: output_patients_sum
    }
  )
end

######################################################################
# data.json
# contacts の生成
######################################################################
CONTACTS_CSV.each do |row|
  data_json[:contacts][:data].append(
    {
      日付: Time.parse(row['date']).iso8601,
      # コールセンター: row['コールセンター'].to_i, # 利用していないので出力しない
      # 各保健所: row['各保健所'].to_i, # 利用していないので出力しない
      # 医療政策室: row['医療政策室'].to_i, # 利用していないので出力しない
      小計: row['小計'].blank? ? nil : row['小計'].to_i,
    }
  )
end

######################################################################
# data.querents.json
# querents の生成
######################################################################
QUERENTS_CSV.each do |row|
  data_json[:querents][:data].append(
    {
      日付: Time.parse(row['date']).iso8601,
      # コールセンター: row['コールセンター'].to_i, # 利用していないので出力しない
      # 各保健所: row['各保健所'].to_i, # 利用していないので出力しない
      # 医療政策室: row['医療政策室'].to_i, # 利用していないので出力しない
      小計: row['小計'].blank? ? nil : row['小計'].to_i,
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
  PATIENTS_CSV.each do |row|
    if row['確定日'] == date.strftime('%Y/%m/%d')
      positive_by_diagnosed_sum += 1
    end
  end

  data_positive_by_diagnosed_json[:data].append(
    {
      diagnosed_date: Time.new(date.year, date.month, date.day, 0, 0, 0).iso8601,
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
      diagnosed_date: Time.parse(row['diagnosed_date']).iso8601,
      count: row['count'].to_i,
      missing_count: row['missing_count'].to_i,
      reported_count: row['reported_count'].to_i,
      weekly_gain_ratio: nil, # 未使用
      untracked_percent: nil, # 未使用
      weekly_average_count: row['weekly_average_count'].blank? ? nil : row['weekly_average_count'].to_f,
      weekly_average_untracked_count: row['weekly_average_untracked_count'].blank? ? nil : row['weekly_average_untracked_count'].to_f,
      weekly_average_untracked_increse_percent: row['weekly_average_untracked_increse_percent'].blank? ? nil : row['weekly_average_untracked_increse_percent'].to_f
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
      diagnosed_date: Time.parse(row['diagnosed_date']).iso8601,
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
      date: Time.parse(row['date']).iso8601,
      hospital: row['入院'].to_i,
      hotel: row['宿泊療養'].to_i,
      hospitalized: row['入院'].to_i + row['宿泊療養'].to_i,
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
      date: Time.parse(row['date']).iso8601,
      icon: row['icon'],
      url: {
        ja: row['url_ja'].blank? ? nil : row['url_ja'],
        en: row['url_en'].blank? ? nil : row['url_en']
      },
      text: {
        ja: row['text_ja'].blank? ? nil : row['text_ja'],
        en: row['text_en'].blank? ? nil : row['text_en'],
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
      date: Time.parse(row['date']).iso8601,
      icon: row['icon'],
      url: {
        ja: row['url_ja'].blank? ? nil : row['url_ja'],
        en: row['url_en'].blank? ? nil : row['url_en'],
      },
      text: {
        ja: row['text_ja'].blank? ? nil : row['text_ja'],
        en: row['text_en'].blank? ? nil : row['text_en'],
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
      date: Time.parse(row['date']).iso8601,
      icon: row['icon'],
      url: {
        ja: row['url_ja'].blank? ? nil : row['url_ja'],
        en: row['url_en'].blank? ? nil : row['url_en'],
      },
      text: {
        ja: row['text_ja'].blank? ? nil : row['text_ja'],
        en: row['text_en'].blank? ? nil : row['text_en'],
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
  陽性者数: PATIENTS_CSV.size,
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
  退院等前日差: HOSPITALIZED_NUMBERS[-1]['退院等'].to_i - HOSPITALIZED_NUMBERS[-2]['退院等'].to_i,
}


######################################################################
# write json
######################################################################

File.open(File.join(__dir__, '../../data/', 'data.json'), 'w') do |f|
  f.write JSON.pretty_generate(data_json)
end

File.open(File.join(__dir__, '../../data/', 'patient_municipalities.json'), 'w') do |f|
  f.write JSON.pretty_generate(data_patient_municipalities_json)
end

File.open(File.join(__dir__, '../../data/', 'positive_by_diagnosed.json'), 'w') do |f|
  f.write JSON.pretty_generate(data_positive_by_diagnosed_json)
end

File.open(File.join(__dir__, '../../data/', 'daily_positive_detail.json'), 'w') do |f|
  f.write JSON.pretty_generate(data_daily_positive_detail_json)
end

File.open(File.join(__dir__, '../../data/', 'positive_rate.json'), 'w') do |f|
  f.write JSON.pretty_generate(data_positive_rate_json)
end

File.open(File.join(__dir__, '../../data/', 'positive_status.json'), 'w') do |f|
  f.write JSON.pretty_generate(data_positive_status_json)
end

File.open(File.join(__dir__, '../../data/', 'news.json'), 'w') do |f|
  f.write JSON.pretty_generate(data_news_json)
end

File.open(File.join(__dir__, '../../data/', 'alert.json'), 'w') do |f|
  f.write JSON.pretty_generate(data_alert_json)
end

File.open(File.join(__dir__, '../../data/', 'self_disclosures.json'), 'w') do |f|
  f.write JSON.pretty_generate(data_self_disclosures_json)
end

File.open(File.join(__dir__, '../../data/', 'main_summary.json'), 'w') do |f|
  f.write JSON.pretty_generate(data_main_summary)
end

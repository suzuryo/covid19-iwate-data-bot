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

INSPECTIONS_CSV = CSV.parse(service.get_spreadsheet_values(SPREADSHEET_ID, 'input_検査件数').values.map(&:to_csv).join, headers: true)
raise if INSPECTIONS_CSV.empty?

CONTACTS_CSV = CSV.parse(service.get_spreadsheet_values(SPREADSHEET_ID, 'input_帰国者接触者_相談件数').values.map(&:to_csv).join, headers: true)
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

######################################################################
# データ生成 テンプレート
# data.json
######################################################################
now = Time.now
data_json = {
  contacts: {
    date: now.strftime('%Y/%m/%d %H:%M'),
    data: []
  },
  querents: {
    date: now.strftime('%Y/%m/%d %H:%M'),
    data: []
  },
  patients: {
    date: now.strftime('%Y/%m/%d %H:%M'),
    data: []
  },
  patients_summary: {
    date: now.strftime('%Y/%m/%d %H:%M'),
    data: []
  },
  inspections_summary: {
    date: now.strftime('%Y/%m/%d %H:%M'),
    data: {
      PCR検査: [],
      抗原検査: []
    },
    labels: []
  },
  lastUpdate: now,
  main_summary: {
    attr: '検査実施件数',
    date: now.strftime('%Y/%m/%d %H:%M'),
    value: 0,
    children: [
      {
        attr: '陽性患者数',
        value: 0,
        children: [
          {
            attr: '入院中',
            value: 0,
            children: [
              {
                attr: '軽症・中等症',
                value: 0
              },
              {
                attr: '重症', # 岩手県がまだ発表していないので未使用
                value: 0
              },
              {
                attr: '不明', # 岩手県がまだ発表していないので未使用
                value: 0
              }
            ]
          },
          {
            attr: '宿泊療養', # 岩手県がまだ発表していないので未使用
            value: 0
          },
          {
            attr: '自宅療養', # 岩手県がまだ発表していないので未使用
            value: 0
          },
          {
            attr: '入院・療養等調整中',
            value: 0
          },
          {
            attr: '死亡', # 岩手県がまだ発表していないので未使用
            value: 0
          },
          {
            attr: '退院',
            value: 0
          },
        ]
      }
    ]
  }
}

######################################################################
# data.json
# patients の生成
######################################################################
PATIENTS_CSV.each do |row|
  data_json[:patients][:data].append(
    {
      id: row['id'].to_i,
      リリース日: Time.parse(row['リリース日']).iso8601,
      通番: row['通番'],
      年代: row['年代'],
      性別: row['性別'],
      居住地: row['居住地'],
      退院: row['退院'] != '' ? row['退院'] : nil,
      date: Time.parse(row['陽性確定日']).strftime('%Y-%m-%d'),
      url: row['url'] != '' ? row['url'] : nil,
    }
  )
end

######################################################################
# data.json
# patients_summary の生成
######################################################################
(Date.new(2020, 2, 15)..Date.today).each do |date|
  output_patients_sum = 0
  PATIENTS_CSV.each do |row|
    if row['リリース日'] === date.strftime('%Y/%m/%d')
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
# inspections_summary の生成
######################################################################
INSPECTIONS_CSV.each do |row|
  data_json[:inspections_summary][:data][:PCR検査].append row['PCR検査件数'].to_i
  data_json[:inspections_summary][:data][:抗原検査].append row['抗原検査件数'].to_i
  data_json[:inspections_summary][:labels].append Time.parse(row['date']).strftime('%-m/%d')
end


######################################################################
# data.json
# main_summary の生成
######################################################################
# 検査実施件数
inspection_sum = 0
INSPECTIONS_CSV.each do |row|
  inspection_sum += row['検査件数合計'].to_i
end
data_json[:main_summary][:value] = inspection_sum

# 陽性患者数
data_json[:main_summary][:children][0][:value] = PATIENTS_CSV.size

# 岩手県が個別の症状（軽症・中症・重症）を発表していないのでカウントできない
# 岩手県が個別の退院日を公表していないので Google Sheets の output_patients から
# カウントできないので、 Google Sheets の output_hospitalized_numbers で
# 手動管理する値を採用する
# 個別の退院日が発表され、個別の症状が発表されるならコメントアウトしているコードを利用できるようになる。

# 症状ごとのカウント
patients_status = {
  軽症・中等症: 0,
  重症: 0,
  宿泊療養: 0,
  自宅療養: 0,
  入院・療養等調整中: 0,
  死亡: 0,
  退院等（療養期間経過を含む）: 0,
}

PATIENTS_CSV.each do |row|
  patients_status[row['陽性者の状況'].to_sym] += 1
end

# 入院中
data_json[:main_summary][:children][0][:children][0][:value] = HOSPITALIZED_NUMBERS[-1]['うち入院中'].to_i

# 軽症・中等症 : 未発表なのでカウントできない
# 重症 : 未発表なのでカウントできない
# 不明 : 未発表なのでカウントできない

# 宿泊療養
data_json[:main_summary][:children][0][:children][1][:value] = patients_status[:宿泊療養]

# 自宅療養
data_json[:main_summary][:children][0][:children][2][:value] = patients_status[:自宅療養]

# 入院療養等調整中
data_json[:main_summary][:children][0][:children][3][:value] = patients_status[:入院・療養等調整中]

# 死亡
data_json[:main_summary][:children][0][:children][4][:value] = HOSPITALIZED_NUMBERS[-1]['うち死亡'].to_i

# 退院
data_json[:main_summary][:children][0][:children][5][:value] = HOSPITALIZED_NUMBERS[-1]['うち退院'].to_i


######################################################################
# data.json
# contacts の生成
######################################################################
CONTACTS_CSV.each do |row|
  data_json[:contacts][:data].append(
    {
      日付: Time.parse(row['date']).iso8601,
      コールセンター: row['コールセンター'].to_i,
      各保健所: row['各保健所'].to_i,
      医療政策室: row['医療政策室'].to_i,
      小計: row['小計'].to_i,
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
      コールセンター: row['コールセンター'].to_i,
      各保健所: row['各保健所'].to_i,
      医療政策室: row['医療政策室'].to_i,
      小計: row['小計'].to_i,
    }
  )
end

######################################################################
# データ生成 テンプレート
# data.patient_municipalities.json
######################################################################
data_patient_municipalities_json = {
  date: now.strftime('%Y/%m/%d %H:%M'),
  datasets: {
    date: now.strftime('%Y/%m/%d %H:%M'),
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
      count: row['count'].to_i
    }
  )
end

######################################################################
# データ生成 テンプレート
# positive_by_diagnosed.json
######################################################################
data_positive_by_diagnosed_json = {
  date: now.strftime('%Y/%m/%d %H:%M'),
  data: []
}

######################################################################
# positive_by_diagnosed.json
# data の生成
######################################################################
(Date.new(2020, 2, 15)..Date.today).each do |date|
  positive_by_diagnosed_sum = 0
  PATIENTS_CSV.each do |row|
    if row['陽性確定日'] === date.strftime('%Y/%m/%d')
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
  date: now.strftime('%Y/%m/%d %H:%M'),
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
      weekly_average_untracked_increse_percent: row['weekly_average_untracked_increse_percent'].blank? ? nil : row['weekly_average_untracked_increse_percent'].to_i
    }
  )
end

######################################################################
# データ生成 テンプレート
# positive_rate.json
######################################################################
data_positive_rate_json = {
  date: now.strftime('%Y/%m/%d %H:%M'),
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
      negative_count: row['negative_count'].blank? ? nil : row['negative_count'].to_i,
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
  date: now.strftime('%Y/%m/%d %H:%M'),
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
#       "date": date.strftime('%Y/%m/%d'),
#       "hospitalized": hospitalized_sum,
#       "severe_case": nil # SevereCaseCard.vue を使っていないので未使用
#     }
#   )
# end

HOSPITALIZED_NUMBERS.each do |row|
  data_positive_status_json[:data].append(
    {
      date: Time.parse(row['date']).iso8601,
      hospitalized: row['うち入院中'].to_i,
      severe_case: nil # SevereCaseCard.vue を使っていないので未使用
    }
  )
end

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

#!/usr/bin/env ruby
# frozen_string_literal: true

require 'active_support/all'
require 'fileutils'
require 'json'
require_relative '../lib/googlesheets'
require_relative '../lib/googlesheet2json_v2/alert_json'
# require_relative '../lib/googlesheet2json_v2/data_json'
require_relative '../lib/googlesheet2json_v2/confirmed_case_area_age_json'
require_relative '../lib/googlesheet2json_v2/confirmed_case_city_json'
require_relative '../lib/googlesheet2json_v2/daily_positive_detail_json'
require_relative '../lib/googlesheet2json_v2/health_burden_json'
require_relative '../lib/googlesheet2json_v2/main_summary_json'
require_relative '../lib/googlesheet2json_v2/news_json'
require_relative '../lib/googlesheet2json_v2/patient_municipalities_json'
require_relative '../lib/googlesheet2json_v2/positive_rate_json'
require_relative '../lib/googlesheet2json_v2/positive_status_json'
require_relative '../lib/googlesheet2json_v2/self_disclosures_json'
require_relative '../lib/googlesheet2json_v2/urls_json'

# Time.zone = 'Asia/Tokyo'

# ここまで Google Sheets API を使うための Quickstart テンプレ
# https://developers.google.com/sheets/api/quickstart/ruby

GoogleSheets = GoogleSheetsIwate.new

# ここまで Google Sheets API を使うための Quickstart テンプレ
# https://developers.google.com/sheets/api/quickstart/ruby

######################################################################
# Google Sheets から batch_get_spreadsheet_values した値をシートごとに Hash の Array にする
######################################################################

# PATIENTS = Ractor.make_shareable GoogleSheets.data(GoogleSheetsIwate::SHEET_RANGES[:PATIENTS])
# raise if PATIENTS.empty?

PATIENTS_SUMMARY = GoogleSheets.data(GoogleSheetsIwate::SHEET_RANGES[:PATIENTS_SUMMARY])
raise if PATIENTS_SUMMARY.empty?

# PATIENT_MUNICIPALITIES = GoogleSheets.data(GoogleSheetsIwate::SHEET_RANGES[:PATIENT_MUNICIPALITIES])
# raise if PATIENT_MUNICIPALITIES.empty?

# POSITIVE_BY_DIAGNOSED = GoogleSheets.data(GoogleSheetsIwate::SHEET_RANGES[:POSITIVE_BY_DIAGNOSED])
# raise if POSITIVE_BY_DIAGNOSED.empty?

POSITIVE_RATE = GoogleSheets.data(GoogleSheetsIwate::SHEET_RANGES[:POSITIVE_RATE])
raise if POSITIVE_RATE.empty?

HOSPITALIZED_NUMBERS = GoogleSheets.data(GoogleSheetsIwate::SHEET_RANGES[:HOSPITALIZED_NUMBERS])
raise if HOSPITALIZED_NUMBERS.empty?

NEWS = GoogleSheets.data(GoogleSheetsIwate::SHEET_RANGES[:NEWS])
# raise if NEWS.empty?

ALERT = GoogleSheets.data(GoogleSheetsIwate::SHEET_RANGES[:ALERT])
# raise if ALERT.empty?

URLS = GoogleSheets.data(GoogleSheetsIwate::SHEET_RANGES[:URLS])
# raise if URLS.empty?

SELF_DISCLOSURES = GoogleSheets.data(GoogleSheetsIwate::SHEET_RANGES[:SELF_DISCLOSURES])
raise if SELF_DISCLOSURES.empty?

MASTER_CITIES = GoogleSheets.data(GoogleSheetsIwate::SHEET_RANGES[:MASTER_CITIES])
raise if MASTER_CITIES.empty?


######################################################################
# Common
######################################################################
# データを生成した日時
NOW = Ractor.make_shareable Time.now

# データの最初の日
FIRST_DATE = Ractor.make_shareable Date.new(2020, 2, 15)

# データの最後の確定日
LAST_DATE = Ractor.make_shareable POSITIVE_RATE.last['diagnosed_date']

# 今日
TODAY = Ractor.make_shareable Date.today

# 昨日
YESTERDAY = Ractor.make_shareable Date.yesterday

# City, Area
CITY_AREA = Ractor.make_shareable(MASTER_CITIES.to_h { |city| [city['label'], city['area']] }.except('県外'))

CITY_POPULATION = Ractor.make_shareable(MASTER_CITIES.to_h { |city| [city['label'], city['population'].to_i] }.except('県外'))

CITIES = Ractor.make_shareable CITY_AREA.keys

AREAS = Ractor.make_shareable CITY_AREA.values.compact.uniq

AREA_POPULATION = Ractor.make_shareable(
  AREAS.to_h do |area|
    [
      area,
      CITY_POPULATION.inject(0) do |sum, (k, v)|
        CITY_AREA[k] == area ? sum + v : sum + 0
      end
    ]
  end
)

AGES = Ractor.make_shareable %w[10歳未満 10代 20代 30代 40代 50代 60代 70代 80代 90歳以上]

def findArea(place)
  if CITIES.include? place
    CITY_AREA[place]
  elsif AREAS.include? place
    place
  else
    nil
  end
end


# news.json
r_news = Ractor.new name: 'news' do
  news, now = Ractor.receive
  news_json(news, now)
end
r_news.send [NEWS, NOW]

# alert.json
r_alert = Ractor.new name: 'alert' do
  alert, now = Ractor.receive
  alert_json(alert, now)
end
r_alert.send [ALERT, NOW]

# urls.json
r_urls = Ractor.new name: 'urls' do
  urls, now = Ractor.receive
  urls_json(urls, now)
end
r_urls.send [URLS, NOW]

# self_disclosures.json
r_self_disclosures = Ractor.new name: 'self_disclosures' do
  self_disclosures, now = Ractor.receive
  self_disclosures_json(self_disclosures, now)
end
r_self_disclosures.send [SELF_DISCLOSURES, NOW]

# patient_municipalities.json の生成
r_patient_municipalities = Ractor.new name: 'patient_municipalities' do
  patients_summary, now = Ractor.receive
  patient_municipalities_json(patients_summary, now)
end
r_patient_municipalities.send [PATIENTS_SUMMARY, NOW]

# positive_status.json
r_positive_status = Ractor.new name: 'positive_status' do
  hospitalized_numbers, now = Ractor.receive
  positive_status_json(hospitalized_numbers, now)
end
r_positive_status.send [HOSPITALIZED_NUMBERS, NOW]

# main_summary.json
r_main_summary = Ractor.new name: 'main_summary' do
  hospitalized_numbers, patients_summary, now = Ractor.receive
  main_summary_json(hospitalized_numbers, patients_summary, now)
end
r_main_summary.send [HOSPITALIZED_NUMBERS, PATIENTS_SUMMARY, NOW]

# confirmed_case_area.json
# confirmed_case_age.json
r_confirmed_case_area_age = Ractor.new name: 'confirmed_case_area_age' do
  patients_summary, hospitalized_numbers, now = Ractor.receive
  confirmed_case_area_age_json(patients_summary, hospitalized_numbers, now)
end
r_confirmed_case_area_age.send [PATIENTS_SUMMARY, HOSPITALIZED_NUMBERS, NOW]

# positive_rate.json の生成
r_positive_rate = Ractor.new name: 'positive_rate' do
  positive_rate, now = Ractor.receive
  positive_rate_json(positive_rate, now)
end
r_positive_rate.send [POSITIVE_RATE, NOW]


# health_burden.json の生成
r_health_burden = Ractor.new name: 'health_burden' do
  patients_summary, positive_rate, hospitalized_numbers, now = Ractor.receive
  health_burden_json(patients_summary, positive_rate, hospitalized_numbers, now)
end
r_health_burden.send [PATIENTS_SUMMARY, POSITIVE_RATE, HOSPITALIZED_NUMBERS, NOW]


# daily_positive_detail.json の生成
r_daily_positive_detail = Ractor.new name: 'daily_positive_detail' do
  patients_summary, now = Ractor.receive
  daily_positive_detail_json(patients_summary, now)
end
r_daily_positive_detail.send [PATIENTS_SUMMARY, NOW]

# confirmed_case_city.json の生成
r_confirmed_case_city = Ractor.new name: 'confirmed_case_city' do
  patients_summary, now = Ractor.receive
  confirmed_case_city_json(patients_summary, now)
end
r_confirmed_case_city.send [PATIENTS_SUMMARY, NOW]


################################################################################
# # 20220727 から 個別事例 が公表されなくなったため、集計不能
################################################################################
# # data.json の生成
# r_data = Ractor.new name: 'data' do
#   data_json
# end


# # データ
r_news.take
r_alert.take
r_urls.take
r_self_disclosures.take
r_patient_municipalities.take
r_positive_status.take
r_main_summary.take
r_confirmed_case_area_age.take
r_positive_rate.take
r_health_burden.take
r_daily_positive_detail.take
r_confirmed_case_city.take

################################################################################
# 集計不能
################################################################################
# r_data.take

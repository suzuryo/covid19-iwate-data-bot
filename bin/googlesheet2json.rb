#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'time'
require 'date'
require 'active_support/all'
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
# raise if NEWS.empty?

ALERT = GoogleSheets.data(GoogleSheetsIwate::SHEET_RANGES[:ALERT])
# raise if ALERT.empty?

URLS = GoogleSheets.data(GoogleSheetsIwate::SHEET_RANGES[:URLS])
# raise if URLS.empty?

SELF_DISCLOSURES = GoogleSheets.data(GoogleSheetsIwate::SHEET_RANGES[:SELF_DISCLOSURES])
raise if SELF_DISCLOSURES.empty?

######################################################################
# Common
######################################################################
# データを生成した日時
now = Time.now

# データの最初の日
first_date = Date.new(2020, 2, 15)

# データの最後の確定日
latest_date = POSITIVE_RATE.last['diagnosed_date']

# 市町村と管内の対応表
@cityArea = {
  '盛岡市' => '盛岡市保健所管内',
  '宮古市' => '宮古保健所管内',
  '大船渡市' => '大船渡保健所管内',
  '花巻市' => '中部保健所管内',
  '北上市' => '中部保健所管内',
  '久慈市' => '久慈保健所管内',
  '遠野市' => '中部保健所管内',
  '一関市' => '一関保健所管内',
  '陸前高田市' => '大船渡保健所管内',
  '釜石市' => '釜石保健所管内',
  '二戸市' => '二戸保健所管内',
  '八幡平市' => '県央保健所管内',
  '奥州市' => '奥州保健所管内',
  '滝沢市' => '県央保健所管内',
  '雫石町' => '県央保健所管内',
  '葛巻町' => '県央保健所管内',
  '岩手町' => '県央保健所管内',
  '紫波町' => '県央保健所管内',
  '矢巾町' => '県央保健所管内',
  '西和賀町' => '中部保健所管内',
  '金ケ崎町' => '奥州保健所管内',
  '平泉町' => '一関保健所管内',
  '住田町' => '大船渡保健所管内',
  '大槌町' => '釜石保健所管内',
  '山田町' => '宮古保健所管内',
  '岩泉町' => '宮古保健所管内',
  '田野畑村' => '宮古保健所管内',
  '普代村' => '久慈保健所管内',
  '軽米町' => '二戸保健所管内',
  '野田村' => '久慈保健所管内',
  '九戸村' => '二戸保健所管内',
  '洋野町' => '久慈保健所管内',
  '一戸町' => '二戸保健所管内',
}

# 市町村の配列
@cities = @cityArea.keys

# 管内の配列
@areas = @cityArea.values.uniq

# 居住地や滞在地から管内を返す
def findArea(place: '県外')
  if @cities.include? place
    @cityArea[place]
  elsif @areas.include? place
    place
  end
end

@ages = %w[10歳未満 10代 20代 30代 40代 50代 60代 70代 80代 90歳以上]

######################################################################
# データ生成 テンプレート
# data.json
######################################################################
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

# ######################################################################
# # データ生成 テンプレート
# # positive_by_diagnosed.json
# ######################################################################
# data_positive_by_diagnosed_json = {
#   date: now.iso8601,
#   data: []
# }
#
# ######################################################################
# # positive_by_diagnosed.json
# # data の生成
# ######################################################################
# (first_date..Date.parse(POSITIVE_RATE[-1]['diagnosed_date'])).each do |date|
#   positive_by_diagnosed_sum = 0
#   PATIENTS.each do |row|
#     positive_by_diagnosed_sum += 1 if row['確定日'] == date.strftime('%Y-%m-%d')
#   end
#
#   data_positive_by_diagnosed_json[:data].append(
#     {
#       diagnosed_date: date.strftime('%Y-%m-%d'),
#       count: positive_by_diagnosed_sum
#     }
#   )
# end

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
  date: now.iso8601,
  newsItems: []
}

NEWS.each do |row|
  data_news_json[:newsItems].append(
    {
      date: Time.parse(row['date']).strftime('%Y-%m-%d'),
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
  date: now.iso8601,
  alertItems: []
}

ALERT.each do |row|
  data_alert_json[:alertItems].append(
    {
      date: Time.parse(row['date']).strftime('%Y-%m-%d'),
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
# urls.json
######################################################################
data_urls_json = {
  date: now.iso8601,
  items: []
}

URLS.each do |row|
  data_urls_json[:items].append(
    {
      item: row['item'].blank? ? nil : row['item'],
      url: row['url'].blank? ? nil : row['url'],
    }
  )
end

######################################################################
# データ生成 テンプレート
# self_disclosures.json
######################################################################
data_self_disclosures_json = {
  date: now.iso8601,
  newsItems: []
}

SELF_DISCLOSURES.each do |row|
  data_self_disclosures_json[:newsItems].append(
    {
      date: Time.parse(row['date']).strftime('%Y-%m-%d'),
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
# health_burden.json
# main_summary の生成
######################################################################

# 予測ツール
# https://github.com/yukifuruse1217/COVIDhealthBurden
# 医療需要予測ツール_オミクロンとブースター考慮版v3_20220103.xlsx
# の計算をrubyで実装。

# 直近１週間の陽性者data
last7days = data_json[:patients][:data].select { |d| Date.parse(d[:確定日]) > Date.parse(data_daily_positive_detail_json[:data][-1][:diagnosed_date]).days_ago(7) }

AGES = {
  s00: '10歳未満',
  s10: '10歳台',
  s20: '20歳台',
  s30: '30歳台',
  s40: '40歳台',
  s50: '50歳台',
  s60: '60歳台',
  s70: '70歳台以上'
}.freeze

# 1日あたりの検査陽性者数
B3 = {
  s00: Rational(last7days.select { |d| ['10歳未満'].include? d[:年代] }.size.to_s) / Rational('7'),
  s10: Rational(last7days.select { |d| ['10代'].include? d[:年代] }.size.to_s) / Rational('7'),
  s20: Rational(last7days.select { |d| ['20代'].include? d[:年代] }.size.to_s) / Rational('7'),
  s30: Rational(last7days.select { |d| ['30代'].include? d[:年代] }.size.to_s) / Rational('7'),
  s40: Rational(last7days.select { |d| ['40代'].include? d[:年代] }.size.to_s) / Rational('7'),
  s50: Rational(last7days.select { |d| ['50代'].include? d[:年代] }.size.to_s) / Rational('7'),
  s60: Rational(last7days.select { |d| ['60代'].include? d[:年代] }.size.to_s) / Rational('7'),
  s70: Rational(last7days.select { |d| ['70代', '80代', '90歳以上'].include? d[:年代] }.size.to_s) / Rational('7')
}.freeze

# 接種率の資料
# https://www.kantei.go.jp/jp/headline/kansensho/vaccine.html

# ワクチン２回接種率（％） ※３回接種者を含む
B4 = {
  s00: Rational('0'),
  s10: Rational('84.22'),
  s20: Rational('85.31'),
  s30: Rational('83.90'),
  s40: Rational('87.56'),
  s50: Rational('91.54'),
  s60: (Rational('91.98') + Rational('90.53')) / Rational('2'),
  s70: (Rational('96.89') + Rational('95.42') + Rational('99.83') + Rational('102.18')) / Rational('4')
}.freeze

# ワクチン３回接種率（％）
B5 = {
  s00: Rational('0'),
  s10: Rational('0'),
  s20: Rational('0'),
  s30: Rational('0'),
  s40: Rational('41.3') * Rational('8') / Rational('4'),
  s50: Rational('41.3') * Rational('8') / Rational('4'),
  s60: Rational('41.3') * Rational('8') / Rational('4'),
  s70: Rational('41.3') * Rational('8') / Rational('4')
}.freeze

# デルタ株：（ワクチンなしで）酸素投与を要する率（％）
B7 = {
  s00: Rational('1'),
  s10: Rational('1'),
  s20: Rational('1.5'),
  s30: Rational('5'),
  s40: Rational('10'),
  s50: Rational('15'),
  s60: Rational('25'),
  s70: Rational('30')
}.freeze

# デルタ株：（ワクチンなしの）重症化率（％）
B10 = {
  s00: Rational('0.1'),
  s10: Rational('0.1'),
  s20: Rational('0.1'),
  s30: Rational('0.6'),
  s40: Rational('1.5'),
  s50: Rational('4'),
  s60: Rational('8'),
  s70: Rational('11')
}.freeze

# デルタ株と比べたときの流行株の重症化率（％）
B14 = Rational('60')

# 中等症の入院期間（日数）
B18 = {
  s00: Rational('9'),
  s10: Rational('9'),
  s20: Rational('9'),
  s30: Rational('9'),
  s40: Rational('9'),
  s50: Rational('10'),
  s60: Rational('11'),
  s70: Rational('14')
}.freeze

# 重症者の入院期間（重症病床を占有していないときも含む日数）
B21 = {
  s00: Rational('14'),
  s10: Rational('14'),
  s20: Rational('14'),
  s30: Rational('14'),
  s40: Rational('14'),
  s50: Rational('15'),
  s60: Rational('17'),
  s70: Rational('20')
}.freeze

# 検査陽性者数の今週/先週比
B24 = Rational(data_daily_positive_detail_json[:data][-7..].reduce(0) { |a, v| a + v[:count] }) / Rational(data_daily_positive_detail_json[:data][-14..-8].reduce(0) { |a, v| a + v[:count] })

# 現在の重症者数
B28 = Rational(data_main_summary[:重症].to_s)

# 現在の全療養者数
B29 = Rational(data_main_summary[:入院]) + Rational(data_main_summary[:宿泊療養]) + Rational(data_main_summary[:自宅療養]) + Rational(data_main_summary[:調整中])

# 現在の酸素投与を要する人の数（重症者を含む）
# 岩手県は酸素投与が必要な中等症1,2の数を公表していない。
# 第47回本部員会議の資料で、オミクロンの現在、中等症(1なの2なの)が1.3%という資料が出た。
# つまり、76人の入院患者に対して中等症は1人ということ。
# https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/035/134/20220123_01_3.pdf
#
# 第48回本部員会議の資料で、中等症(1なの2なの?)が 2.3% という資料が出た。
# つまり、177 人の入院患者に対して中等症は 4 人ということ。
# https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/035/134/20220201_01_3.pdf
#
# 第49回本部員会議の資料で、中等症(1なの2なの?)が
# 2022/1/15 - 2022/1/31 の 246 例について 4.1% という資料が出た。
# つまり、246 人の入院患者に対して中等症は 10 人ということ
# https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/035/134/20220218_01_3.pdf
#
# 第49回本部員会議の資料で、中等症(1なの2なの?)が
# 2022/2/1 - 2022/2/16 の 353 例について 9.7% という資料が出た。
# つまり、353 人の入院患者に対して中等症は 34 人ということ
# https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/035/134/20220218_01_3.pdf
#
# 第50回本部員会議の資料で、中等症(1なの2なの?)が
# 2022/2/10 - 2022/2/16 の 140 例について 13.5% という資料が出た。
# つまり、140 人の入院患者に対して中等症は 19 人ということ
# https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220225_01_2.pdf
#
# 第50回本部員会議の資料で、中等症(1なの2なの?)が
# 2022/2/17 - 2022/2/23 の 141 例について 9.2% という資料が出た。
# つまり、141 人の入院患者に対して中等症は 13 人ということ
# https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220225_01_2.pdf
#
# 第51回本部員会議の資料で、中等症(1なの2なの?)が
# 2022/2/24 - 2022/3/2 の 115 例について 5.2% という資料が出た。
# つまり、141 人の入院患者に対して中等症は 6 人ということ
# https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220304_01_3.pdf
#
# 第52回本部員会議の資料で、中等症(1なの2なの?)が
# 2022/3/3 - 2022/3/9 の 130 例について 9.2% という資料が出た。
# つまり、130 人の入院患者に対して中等症は 12 人ということ
# https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220318_01_3.pdf
#
# 第52回本部員会議の資料で、中等症(1なの2なの?)が
# 2022/3/10 - 2022/3/16 の 111 例について 2.7% という資料が出た。
# つまり、111 人の入院患者に対して中等症は 3 人ということ
# https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220318_01_3.pdf
#
# 第53回本部員会議の資料で、中等症(1なの2なの?)が
# 2022/3/12 - 2022/3/18 の 124 例について 7.3% という資料が出た。
# つまり、124 人の入院患者に対して中等症は 9 人ということ
# https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220329_01_3.pdf
#
# 第53回本部員会議の資料で、中等症(1なの2なの?)が
# 2022/3/19 - 2022/3/25 の 74 例について 9.5% という資料が出た。
# つまり、74 人の入院患者に対して中等症は 7 人ということ
# https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220329_01_3.pdf
#
# 第50回本部員会議の資料で、酸素投与を受けた患者が 8.5 % という数字が出ている
# ただしオミクロン前のデータ
# https://www.pref.iwate.jp/_res/projects/default_project/_page_/001/050/416/20220225_04_2.pdf
#
# NIIDの資料では、2022/01/17の時点では、中等症1が1.1%、中等症2が0.4%
# 40.6 が不明に割り振られているので分かっている分で計算すると、中等症2は (0.4) / (1.1 + 0.4 + 58.1) * 100 = 0.67 %
# https://www.mhlw.go.jp/content/10900000/000884972.pdf#page=86
#
# 先行した沖縄県のデータでは
# https://www.mhlw.go.jp/content/10900000/000877245.pdf#page=8
# 2022/01/04時点では 中等症2は3.7%となっている。(NIIDより多い)
#
# NIIDの 0.67 % を採用して、全療養者数から中等症2の数を算出しておく。
B27 = (B29 * Rational('0.67') / Rational('100')) + B28

# ２回接種：感染予防
B32 = Rational('30')

# ２回接種：入院・重症化予防
B33 = Rational('70')

# ３回接種：感染予防
B34 = Rational('60')

# ３回接種：入院・重症化予防
B35 = Rational('85')

# 血中酸素濃度低下の前に治療薬の投与を受けられる割合（％）
B39 = Rational('0')

# 酸素需要を避けられる効果（％）
B40 = Rational('70')

# シナリオ変数
C44 = Rational('5')

# exp B
B45 = Rational((B24**Rational('1', '7')).to_s)

# exp C
C45 = if C44 == Rational('5')
        B45
      elsif C44 == Rational('6')
        Rational('1')
      elsif C44 == Rational('7')
        Rational((Rational('0.85')**Rational('1', '5')).to_s)
      end

# ２回感染→入院ワクチン
B48 = Rational((Rational('1') - (B33 / Rational('100'))), (Rational('1') - (B32 / Rational('100'))))

# ３回感染→入院ワクチン
B49 = Rational((Rational('1') - (B35 / Rational('100'))), (Rational('1') - (B34 / Rational('100'))))

# ワクチン２回
B52 = AGES.keys.to_h { |k| [k, Rational((B4[k] - B5[k]) / Rational('100'))] }

# ワクチン３回
B53 = AGES.keys.to_h { |k| [k, Rational(B5[k] / Rational('100'))] }

# ワクチン０回
B51 = AGES.keys.to_h { |k| [k, Rational(Rational('1') - B52[k] - B53[k])] }

# sensitive0
B55 = B51

# sensitive2
B56 = AGES.keys.to_h { |k| [k, Rational(B52[k] * (Rational('1') - (B32 / Rational('100'))))] }

# sensitive3
B57 = AGES.keys.to_h { |k| [k, Rational(B53[k] * (Rational('1') - (B34 / Rational('100'))))] }

# sensitiveSum
B59 = AGES.keys.to_h { |k| [k, Rational(B55[k] + B56[k] + B57[k])] }

# オリジナル中等症（入院必要）率
B61 = AGES.keys.to_h { |k| [k, Rational((B7[k] / Rational('100')) * (B14 / Rational('100')))] }

# ＋ワクチン効果の入院率
B64 = AGES.keys.to_h do |k|
  [k, Rational(
    ((B55[k] / B59[k]) * B61[k]) +
      ((B56[k] / B59[k]) * B61[k] * B48) +
      ((B57[k] / B59[k]) * B61[k] * B49)
  )]
end

# ＋治療薬
B65 = AGES.keys.to_h { |k| [k, Rational(B64[k] * (Rational('1') - (B39 / Rational('100' * B40) / Rational('100'))))] }

# オリジナル重症率
B67 = AGES.keys.to_h { |k| [k, Rational(((B10[k] / Rational('100')) * B14) / Rational('100'))] }

# オリジナル重症/オリジナル入院
B68 = AGES.keys.to_h { |k| [k, B61[k] == Rational('0') ? Rational('0') : Rational(B67[k] / B61[k])] }

# modify重症
B69 = AGES.keys.to_h { |k| [k, Rational(B68[k] * B65[k])] }

# deltaCheck
B72 = {
  s00: Rational('1'),
  s10: Rational('1'),
  s20: Rational('1'),
  s30: Rational('1'),
  s40: Rational('1'),
  s50: Rational('2'),
  s60: Rational('3'),
  s70: Rational('4')
}.freeze

# delta1-div3
B74 = AGES.keys.to_h { |k| [k, Rational(B18[k] / Rational('3'))] }

#  delta2-div3
B75 = AGES.keys.to_h { |k| [k, Rational((B21[k] - B18[k]) / Rational('3'))] }

# I
m98 = [AGES.keys.to_h { |k| [k, B3[k]] }]
(0...60).each do |i|
  m98.push(
    AGES.keys.to_h { |k| [k, Rational(m98[i][k] * B45)] }
  )
end
M98 = m98

# Ha
v98 = [
  {
    s00: Rational('0'),
    s10: Rational('0'),
    s20: Rational('0'),
    s30: Rational('0'),
    s40: Rational('0'),
    s50: ((B27 - ((B28 * Rational('2')) / Rational('3'))) / Rational('9')) * Rational('4'),
    s60: Rational('0'),
    s70: Rational('0')
  }
]
(0...60).each do |i|
  v98.push(
    AGES.keys.to_h do |k|
      ha = Rational(v98[i][k] + (M98[i][k] * B65[k]) - (v98[i][k] / B74[k]))
      [k, ha < Rational('0') ? Rational('0') : ha]
    end
  )
end
V98 = v98

# Hb
ae98 = [
  {
    s00: Rational('0'),
    s10: Rational('0'),
    s20: Rational('0'),
    s30: Rational('0'),
    s40: Rational('0'),
    s50: ((B27 - ((B28 * Rational('2')) / Rational('3'))) / Rational('9')) * Rational('3'),
    s60: Rational('0'),
    s70: Rational('0')
  }
]
(0...60).each do |i|
  ae98.push(
    AGES.keys.to_h do |k|
      hb = ae98[i][k] + (V98[i][k] / B74[k]) - (ae98[i][k] / B74[k])
      [k, hb < Rational('0') ? Rational('0') : hb]
    end
  )
end
AE98 = ae98

# HcH
an160 = [
  {
    s00: Rational('0'),
    s10: Rational('0'),
    s20: Rational('0'),
    s30: Rational('0'),
    s40: Rational('0'),
    s50: (Rational('2') * (B27 - (B28 * Rational('2') / Rational('3'))) / Rational('9')) - (Rational('6') * B28 / Rational('18')),
    s60: Rational('0'),
    s70: Rational('0')
  }
]
(0...60).each do |i|
  an160.push(
    AGES.keys.to_h do |k|
      hch = an160[i][k] + ((AE98[i][k] / B74[k]) * (Rational('1') - B68[k])) - (an160[i][k] / B74[k])
      [k, hch < Rational('0') ? Rational('0') : hch]
    end
  )
end
AN160 = an160

# HcD
an222 = [
  {
    s00: Rational('0'),
    s10: Rational('0'),
    s20: Rational('0'),
    s30: Rational('0'),
    s40: Rational('0'),
    s50: (B28 / Rational('18')) * Rational('6'),
    s60: Rational('0'),
    s70: Rational('0')
  }
]
(0...60).each do |i|
  an222.push(
    AGES.keys.to_h do |k|
      hcd = an222[i][k] + ((AE98[i][k] / B74[k]) * B68[k]) - (an222[i][k] / B74[k])
      [k, hcd < Rational('0') ? Rational('0') : hcd]
    end
  )
end
AN222 = an222

# Da
aw98 = [
  {
    s00: Rational('0'),
    s10: Rational('0'),
    s20: Rational('0'),
    s30: Rational('0'),
    s40: Rational('0'),
    s50: (B28 / Rational('18')) * Rational('5'),
    s60: Rational('0'),
    s70: Rational('0')
  }
]
(0...60).each do |i|
  aw98.push(
    AGES.keys.to_h do |k|
      da = aw98[i][k] + (AN222[i][k] / B74[k]) - (aw98[i][k] / B75[k])
      [k, da < Rational('0') ? Rational('0') : da]
    end
  )
end
AW98 = aw98

# Db
bf98 = [
  {
    s00: Rational('0'),
    s10: Rational('0'),
    s20: Rational('0'),
    s30: Rational('0'),
    s40: Rational('0'),
    s50: (B28 / Rational('18')) * Rational('4'),
    s60: Rational('0'),
    s70: Rational('0')
  }
]
(0...60).each do |i|
  bf98.push(
    AGES.keys.to_h do |k|
      db = bf98[i][k] + (AW98[i][k] / B75[k]) - (bf98[i][k] / B75[k])
      [k, db < Rational('0') ? Rational('0') : db]
    end
  )
end
BF98 = bf98

# Dc
bo98 = [
  {
    s00: Rational('0'),
    s10: Rational('0'),
    s20: Rational('0'),
    s30: Rational('0'),
    s40: Rational('0'),
    s50: (B28 / Rational('18')) * Rational('3'),
    s60: Rational('0'),
    s70: Rational('0')
  }
]
(0...60).each do |i|
  bo98.push(
    AGES.keys.to_h do |k|
      dc = bo98[i][k] + (BF98[i][k] / B75[k]) - (bo98[i][k] / B75[k])
      [k, dc < Rational('0') ? Rational('0') : dc]
    end
  )
end
BO98 = bo98

# 新規陽性者数
B98 = (0...61).map do |i|
  M98[i].merge({ sum: M98[i].values.reduce(:+) })
end

# 酸素需要を要する人（重症者を含む）
B163 = (0...61).map do |i|
  a = AGES.keys.to_h do |k|
    [k, V98[i][k] + AE98[i][k] + AN160[i][k] + AW98[i][k] + BF98[i][k] + BO98[i][k] + AN222[i][k]]
  end
  a.merge({ sum: a.values.reduce(:+) })
end

# 重症病床を要する人
B228 = (0...61).map do |i|
  a = AGES.keys.to_h do |k|
    [k, AW98[i][k] + BF98[i][k] + BO98[i][k] + AN222[i][k]]
  end
  a.merge({ sum: a.values.reduce(:+) })
end

# All
M293 = M98

# RestA
v293 = [
  {
    s00: Rational('0'),
    s10: Rational('0'),
    s20: Rational('0'),
    s30: Rational('0'),
    s40: Rational('0'),
    s50: (B29 - B28 - B27) / Rational('30') * Rational('8'),
    s60: Rational('0'),
    s70: Rational('0')
  }
]
(0...60).each do |i|
  v293.push(
    AGES.keys.to_h do |k|
      a = v293[i][k] + (M293[i][k] * (Rational('1') - B65[k])) - (v293[i][k] / Rational('2'))
      [k, a < Rational('0') ? Rational('0') : a]
    end
  )
end
V293 = v293

# RestB
ae293 = [
  {
    s00: Rational('0'),
    s10: Rational('0'),
    s20: Rational('0'),
    s30: Rational('0'),
    s40: Rational('0'),
    s50: (B29 - B28 - B27) / Rational('30') * Rational('7'),
    s60: Rational('0'),
    s70: Rational('0')
  }
]
(0...60).each do |i|
  ae293.push(
    AGES.keys.to_h do |k|
      a = ae293[i][k] + (V293[i][k] / Rational('2')) - (ae293[i][k] / Rational('2'))
      [k, a < Rational('0') ? Rational('0') : a]
    end
  )
end
AE293 = ae293

# RestC
an293 = [
  {
    s00: Rational('0'),
    s10: Rational('0'),
    s20: Rational('0'),
    s30: Rational('0'),
    s40: Rational('0'),
    s50: (B29 - B28 - B27) / Rational('30') * Rational('6'),
    s60: Rational('0'),
    s70: Rational('0')
  }
]
(0...60).each do |i|
  an293.push(
    AGES.keys.to_h do |k|
      a = an293[i][k] + (AE293[i][k] / Rational('2')) - (an293[i][k] / Rational('2'))
      [k, a < Rational('0') ? Rational('0') : a]
    end
  )
end
AN293 = an293

# RestD
aw293 = [
  {
    s00: Rational('0'),
    s10: Rational('0'),
    s20: Rational('0'),
    s30: Rational('0'),
    s40: Rational('0'),
    s50: (B29 - B28 - B27) / Rational('30') * Rational('5'),
    s60: Rational('0'),
    s70: Rational('0')
  }
]
(0...60).each do |i|
  aw293.push(
    AGES.keys.to_h do |k|
      a = aw293[i][k] + (AN293[i][k] / Rational('2')) - (aw293[i][k] / Rational('2'))
      [k, a < Rational('0') ? Rational('0') : a]
    end
  )
end
AW293 = aw293

# RestE
bf293 = [
  {
    s00: Rational('0'),
    s10: Rational('0'),
    s20: Rational('0'),
    s30: Rational('0'),
    s40: Rational('0'),
    s50: (B29 - B28 - B27) / Rational('30') * Rational('4'),
    s60: Rational('0'),
    s70: Rational('0')
  }
]
(0...60).each do |i|
  bf293.push(
    AGES.keys.to_h do |k|
      a = bf293[i][k] + (AW293[i][k] / Rational('2')) - (bf293[i][k] / Rational('2'))
      [k, a < Rational('0') ? Rational('0') : a]
    end
  )
end
BF293 = bf293

# 全療養者
B293 = (0...61).map do |i|
  a = AGES.keys.to_h do |k|
    [k, V293[i][k] + AE293[i][k] + AN293[i][k] + AW293[i][k] + BF293[i][k] + B163[i][k]]
  end
  a.merge({ sum: a.values.reduce(:+) })
end

################################################################################
# シミュレーション結果
################################################################################

# 酸素投与を要する人（重症者を含む）
C79 = {
  week1: B163[4][:sum],
  week2: B163[11][:sum],
  week3: B163[18][:sum],
  week4: B163[25][:sum]
}.freeze

# 重症者（＝必要と思われる重症病床の確保数）
H79 = {
  week1: B228[4][:sum],
  week2: B228[11][:sum],
  week3: B228[18][:sum],
  week4: B228[25][:sum]
}.freeze

# 全療養者
N79 = {
  week1: B293[7][:sum],
  week2: B293[14][:sum],
  week3: B293[21][:sum],
  week4: B293[28][:sum]
}.freeze

# 自宅療養や療養施設を積極的に利用した場合、必要と思われる確保病床数（酸素需要者の2.5倍）
C85 = C79.keys.to_h do |k|
  [k, C79[k] * Rational('2.5')]
end

# ハイリスク軽症者や、ハイリスクでなくとも中等症 I は基本的に入院させる場合、必要と思われる確保病床数（酸素需要者の4倍）
C91 = C79.keys.to_h do |k|
  [k, C79[k] * Rational('4')]
end

data_health_burden_json = {
  date: now.iso8601,
  酸素需要を要する人: C79.each.to_h { |k, v| [k, v.round] },
  重症病床を要する人: H79.each.to_h { |k, v| [k, v.round] },
  全療養者: N79.each.to_h { |k, v| [k, v.round] },
  自宅療養や療養施設を積極的に利用した場合: C85.each.to_h { |k, v| [k, v.round] },
  基本的に入院させる場合: C91.each.to_h { |k, v| [k, v.round] },
  新規陽性者数データ: B98.slice(0, 19).map { |v| v[:sum].round },
  酸素需要を要する人データ: B163.slice(0, 19).map { |v| v[:sum].round },
  重症病床を要する人データ: B228.slice(0, 19).map { |v| v[:sum].round },
  自宅療養や療養施設を積極的に利用した場合データ: B163.slice(0, 19).map { |v| (v[:sum] * Rational('2.5')).round },
  基本的に入院させる場合データ: B163.slice(0, 19).map { |v| (v[:sum] * Rational('4.0')).round },
  全療養者データ: B293.slice(0, 19).map { |v| v[:sum].round },
}

######################################################################
# データ生成 テンプレート
# confirmed_case_area.json
# confirmed_case_age.json
######################################################################
data_confirmed_case_area_json = {
  date: now.iso8601,
  data: []
}

data_confirmed_case_age_json = {
  date: now.iso8601,
  data: []
}

######################################################################
# data_confirmed_case_area_json の生成
# data_confirmed_case_age_json の生成
######################################################################
POSITIVE_RATE.map { |a| a['diagnosed_date'] }.each do |diagnosed_date|
  date = Date.parse(diagnosed_date)
  date_range = date.days_ago(6)..date

  patients = PATIENTS.select do |patient|
    date_range.cover? Date.parse(patient['確定日'])
  end

  area_sum = patients.each_with_object(@areas.to_h { |a| [a, 0] }) do |patient, hash|
    area = patient['滞在地'].blank? ? findArea(place: patient['居住地']) : findArea(place: patient['滞在地'])
    hash[area] += 1 unless hash[area].nil?
  end

  data_confirmed_case_area_json[:data].append(
    {
      date: date.strftime('%Y-%m-%d'),
      data: area_sum.to_h { |key, val| [key.to_s.gsub('保健所管内', ''), (val / 7.0).round(1)] }
    }
  )

  age_sum = patients.each_with_object(@ages.to_h { |a| [a, 0] }) do |patient, hash|
    age = patient['年代']
    hash[age] += 1 unless hash[age].nil?
  end

  data_confirmed_case_age_json[:data].append(
    {
      date: date.strftime('%Y-%m-%d'),
      data: age_sum.to_h { |key, val| [key, (val / 7.0).round(1)] }
    }
  )
end

######################################################################
# write json
######################################################################

File.write(File.join(__dir__, '../data/', 'data.json'), JSON.generate(data_json))

File.write(File.join(__dir__, '../data/', 'patient_municipalities.json'), JSON.generate(data_patient_municipalities_json))

# File.write(File.join(__dir__, '../data/', 'positive_by_diagnosed.json'), JSON.generate(data_positive_by_diagnosed_json))

File.write(File.join(__dir__, '../data/', 'daily_positive_detail.json'), JSON.generate(data_daily_positive_detail_json))

File.write(File.join(__dir__, '../data/', 'positive_rate.json'), JSON.generate(data_positive_rate_json))

File.write(File.join(__dir__, '../data/', 'positive_status.json'), JSON.generate(data_positive_status_json))

File.write(File.join(__dir__, '../data/', 'news.json'), JSON.generate(data_news_json))

File.write(File.join(__dir__, '../data/', 'alert.json'), JSON.generate(data_alert_json))

File.write(File.join(__dir__, '../data/', 'urls.json'), JSON.generate(data_urls_json))

File.write(File.join(__dir__, '../data/', 'self_disclosures.json'), JSON.generate(data_self_disclosures_json))

File.write(File.join(__dir__, '../data/', 'main_summary.json'), JSON.generate(data_main_summary))

File.write(File.join(__dir__, '../data/', 'health_burden.json'), JSON.generate(data_health_burden_json))

File.write(File.join(__dir__, '../data/', 'confirmed_case_area.json'), JSON.generate(data_confirmed_case_area_json))

File.write(File.join(__dir__, '../data/', 'confirmed_case_age.json'), JSON.generate(data_confirmed_case_age_json))

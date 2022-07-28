#!/usr/bin/env ruby
# frozen_string_literal: true

def patient_municipalities_json(patients_summary, now)
  # 20220727以前のarchivedされたデータと、 input_patients_summary のデータを使って計算する
  # このまま全市町村の実数が公表され続けるなら数字は正確になっていく。
  # 数字が十分増えたので、 count_per_population を %.4f から %.2f に変更

  # 人口
  populations = {
    '盛岡市' => 289893,
    '宮古市' => 50401,
    '大船渡市' => 34739,
    '花巻市' => 93234,
    '北上市' => 93089,
    '久慈市' => 33063,
    '遠野市' => 25381,
    '一関市' => 111970,
    '陸前高田市' => 18271,
    '釜石市' => 32096,
    '二戸市' => 25528,
    '八幡平市' => 24042,
    '奥州市' => 113027,
    '滝沢市' => 55600,
    '雫石町' => 15742,
    '葛巻町' => 5638,
    '岩手町' => 12294,
    '紫波町' => 32166,
    '矢巾町' => 28076,
    '西和賀町' => 5137,
    '金ケ崎町' => 15545,
    '平泉町' => 7258,
    '住田町' => 5050,
    '大槌町' => 11013,
    '山田町' => 14332,
    '岩泉町' => 8732,
    '田野畑村' => 3059,
    '普代村' => 2489,
    '軽米町' => 8423,
    '野田村' => 3938,
    '九戸村' => 5376,
    '洋野町' => 15098,
    '一戸町' => 11506,
    '県外' => nil
  }

  # 20220727までの数
  data_until20220726 = JSON.parse(File.read(File.join(__dir__, '../../data_archived/patient_municipalities.json')))
  patients_data = JSON.parse(File.read(File.join(__dir__, '../../data_archived/data.json')))['patients']['data']

  end_date = Date.parse(LAST_DATE)
  start_date = end_date.days_ago(6)
  date_range = start_date..end_date

  archived_patients_data = patients_data.select do |patient|
    date_range.cover? Date.parse(patient['確定日'])
  end

  patients_summary_data = patients_summary.select do |patient|
    date_range.cover? Date.parse(patient['date'])
  end

  # 書き出し用のデータ
  json = {
    date: now.iso8601,
    datasets: {
      date: now.iso8601,
      data: []
    }
  }

  # input_patients_summary を使って count と count_per_population を計算する
  data = {}
  populations.each_key do |area|
    a = data_until20220726['datasets']['data'].find { |x| x['label'] == area }
    c = a['count'] + patients_summary.reduce(0) { |sum, row| sum + row[area].to_i }

    last7days_archived = archived_patients_data.select { |patient| patient['滞在地'] == area || patient['居住地'] == area }.size
    last7days = patients_summary_data.reduce(0) { |sum, d| sum + d[area].to_i }
    data[area] = a.merge(
      {
        'count' => c,
        'count_per_population' => populations[area] ? format('%.1f', (c / populations[area].to_f * 100).round(1)) : nil,
        'last7days' => last7days_archived + last7days,
        'last7_per_100k' => populations[area] ? format('%.1f', ((last7days_archived + last7days) * 100000 / populations[area]).round(1)) : nil
      }
    )
  end

  # json データの準備
  data.each_key do |key|
    json[:datasets][:data].append(data[key])
  end

  File.write(File.join(__dir__, '../../data/', 'patient_municipalities.json'), JSON.pretty_generate(json))
end



#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/http'
require 'json'
require 'csv'

res = Net::HTTP.get(URI('https://api.iwate-ninshou.jp/shop/'))
data = JSON.parse(res)['data']

csv = []
headers = ['店名', 'lat', 'lon', '詳細', '住所']

data.each do |d|
  csv << [d['shop_name'], d['shop_lat'], d['shop_lon'], "https://iwate-ninshou.jp/detail.html?id=#{d['id']}", d['shop_address']]
end

# 2000行ごとにファイルを分ける
ROW_SIZE = 2000

((csv.size / ROW_SIZE) + 1 ).times do |i|
  File.write(
    "tsv/restaurant#{i}.csv",
    ([headers] + csv[ROW_SIZE*i...ROW_SIZE*(i+1)]).map(&:to_csv).join
  )
end


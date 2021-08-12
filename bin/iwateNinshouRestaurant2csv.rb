#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/http'
require 'json'
require 'csv'

res = Net::HTTP.get(URI('https://api.iwate-ninshou.jp/shop/'))
data = JSON.parse(res)['data']

csv = [
  ['店名', 'lat', 'lon', 'url', '住所']
]

data.each do |d|
  csv << [d['shop_name'], d['shop_lat'], d['shop_lon'], d['shop_url'], d['shop_address']]
end

File.write('tsv/restaurant.csv', csv.map(&:to_csv).join)

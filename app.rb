# frozen_string_literal: true
#
# Google Cloud function

require 'active_support/core_ext/time'
require 'dotenv/load'
require 'erb'
require "functions_framework"
require 'json'
require "sinatra/base"
require 'typhoeus'
require_relative './lib/settings'
require_relative './lib/site'
require_relative './lib/twitter'

ENDPOINT_URL = 'https://api.twitter.com/2/users/:id/tweets'
USER_ID = 1251721687415980032
BEARER_TOKEN = ENV['TWITTER_BEARER_TOKEN']

class App < Sinatra::Base
  before do
    content_type 'text/plain'
  end

  get '/' do
    'hello'
  end

  get '/tweets2tsv' do
    tweets = Tweet2Tsv::Twitter.new(2)

    @main_summary1 = ''
    @main_summary2 = ''
    tweets.data[:main_summary].sort_by { |a| a['date'] }.uniq.each do |b|
      @main_summary1 += "#{b['date'].days_ago(1).strftime('%Y/%m/%d')}\t#{b['県PCR検査']}\t#{b['民間等'].to_i + b['地域外来等'].to_i}\t#{b['抗原検査']}\t#{b['県PCR検査'].to_i + b['民間等'].to_i + b['地域外来等'].to_i}\t#{b['県PCR検査'].to_i + b['民間等'].to_i + b['地域外来等'].to_i + b['抗原検査'].to_i}\n"
      @main_summary2 += "#{b['date'].strftime('%Y/%m/%d')}\t#{b['累計う\\sち検出']}\t#{b['入院中']}\t#{b['入院中うち重症者']}\t#{b['宿泊療養']}\t\t#{b['退院等']}\t#{b['死亡者']}\t#{b['調整中']}\n"
    end

    @positive_cases = ''
    prev_id = tweets.data[:patients].sort_by { |a| a['id'].to_i }.uniq[0]['id']
    tweets.data[:patients].sort_by { |a| a['id'].to_i }.uniq.each do |b|
      @positive_cases += "\n" * (b['id'].to_i - prev_id)
      @positive_cases += "#{b['id']}\t#{b['created_at'].strftime('%Y/%m/%d')}\t#{b['created_at'].days_ago(1).strftime('%Y/%m/%d')}\t\t\t#{b['年代']}\t#{b['性別']}\t#{b['居住地']}\t#{b['滞在地']}\t\t\t#{b['接触歴']}\t\tPCR検査\t#{b['職業']}"
      prev_id = b['id']
    end

    "検査件数\n#{@main_summary1}\n\n検査陽性者の状況\n#{@main_summary2}\n\n陽性者\n#{@positive_cases}"
  end

  get '/site2tsv' do
    id = recent_id
    data = SITES.map do |_city, site|
      Site2Tsv::Site.new(site: site, id: id).data
    end.flatten

    # 文字列組み立て
    @patients = ''
    prev_id = id
    data.sort_by { |a| a['id'] }.uniq.each do |b|
      @patients += "\n" * (b['id'] - prev_id)
      @patients += "#{b['id']}\t#{b['リリース日']}\t#{b['確定日']}\t#{b['発症日']}\t#{b['無症状']}\t#{b['年代']}\t#{b['性別']}\t#{b['居住地']}\t#{b['滞在地']}\t#{b['入院日']}\t#{b['url']}\t#{b['接触歴']}"
      prev_id = b['id']
    end

    "陽性者の状況\n\n#{@patients}"
  end
end

def recent_id
  json = JSON.parse(URI.open('https://raw.githubusercontent.com/MeditationDuck/covid19/development/data/data.json').read)
  json['patients']['data']
    .filter { |a| Time.parse(a['確定日']) < Time.parse(json['patients']['data'].last['確定日']) }
    .max_by { |a| a['id'] }['id']
    .to_i + 1
end

FunctionsFramework.http "covid19-iwate-data-tsv" do |request|
  App.call request.env
end

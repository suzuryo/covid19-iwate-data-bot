#!/usr/bin/env ruby
# frozen_string_literal: true

require 'active_support/core_ext/time'
require 'dotenv/load'
require 'json'
require 'thor'
require 'typhoeus'
require_relative 'lib/Tweet2TSV'

# Twitter API
ENDPOINT_URL = "https://api.twitter.com/2/users/:id/tweets"

# https://twitter.com/iwatevscovid19/ 's USER_ID
USER_ID = 1251721687415980032

# Twitter API TOKEN
BEARER_TOKEN = ENV['TWITTER_BEARER_TOKEN']

class Tweet2TsvCLI < Thor
  # Google Sheets にコピペしやすいTSVデータを出力する
  # data/tweets.tsv にファイルが出力される
  #
  # ./tweet_to_tsv.rb
  # オプションを何も指定しないと、直近1日のデータを探して出力する
  #
  # ./tweet_to_tsv.rb generate --days 2
  # オプション days を指定すると、days日分のデータを探して出力する

  default_command :generate
  option :days, type: :numeric
  desc 'generate', 'generate tsv data'

  def generate
    if options[:days].nil?
      # オプションが指定されていなければ、直近1日分のデータを取得
      days = 1
    else
      # オプションが指定されていれば、そのidを採用
      days = options[:days]
    end

    tweets = Site2TSV.new(days: days)

    # 最新データが空ならば何もしない
    return if tweets.data.blank?

    # 最新データがあればファイルを保存
    File.open(File.join(__dir__, '../tsv/', 'tweet.tsv'), 'w') do |f|
      tweets.data[:main_summary].sort_by{|a| a['date']}.uniq.each do |b|
        f.write '検査件数'
        f.write "\n"
        f.write "#{b['date'].days_ago(1).strftime('%Y/%m/%d')}\t#{b['県PCR検査']}\t#{b['民間等'].to_i + b['地域外来等'].to_i}\t#{b['抗原検査']}\t#{b['県PCR検査'].to_i + b['民間等'].to_i + b['地域外来等'].to_i}\t#{b['県PCR検査'].to_i + b['民間等'].to_i + b['抗原検査'].to_i}"
        f.write "\n" * 2
        f.write '検査陽性者の状況'
        f.write "\n"
        f.write "#{b['date'].strftime('%Y/%m/%d')}\t#{b['累計う\\sち検出']}\t#{b['入院中']}\t#{b['入院中うち重症者']}\t#{b['宿泊療養']}\t\t#{b['退院等']}\t#{b['死亡者']}\t#{b['調整中']}"
        f.write "\n" * 2
      end

      f.write '陽性者'
      f.write "\n"

      prev_id = tweets.data[:patients].sort_by{|a| a['id'].to_i}.uniq[0]['id']
      tweets.data[:patients].sort_by{|a| a['id'].to_i}.uniq.each do |b|
        f.write "\n" * (b['id'].to_i - prev_id)
        f.write "#{b['id']}\t#{b['created_at'].strftime('%Y/%m/%d')}\t#{b['created_at'].days_ago(1).strftime('%Y/%m/%d')}\t\t\t#{b['年代']}\t#{b['性別']}\t#{b['居住地']}\t\t\t#{b['接触歴']}\t\tPCR検査\t#{b['職業']}"
        prev_id = b['id']
      end

    end

  end

  def self.exit_on_failure?
    true
  end
end

Tweet2TsvCLI.start

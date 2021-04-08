#!/usr/bin/env ruby
# frozen_string_literal: true

require 'active_support/core_ext/time'
require 'dotenv/load'
require 'json'
require 'thor'
require 'typhoeus'

# ENV['TWITTER_BEARER_TOKEN']

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
      # オプションが指定されていなければ、公開済みの最新のidを取得
      days = 1
    else
      # オプションが指定されていれば、そのidを採用
      days = options[:days]
    end

    tweets = Tweet2TSV.new(days: days)

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


class Tweet2TSV
  def initialize(days: nil)
    @tweets = []
    @days = days
    @user_id = USER_ID
    @now = Time.now
  end

  def get_user_tweets
    now = Time.now
    days_ago = now.days_ago(@days)
    start_time = Time.new(days_ago.year, days_ago.month, days_ago.day, 15, 0, 'JST').rfc3339
    end_time = now.rfc3339

    options = {
      method: 'get',
      headers: {
        "User-Agent" => "v2RubyExampleCode",
        "Authorization" => "Bearer #{BEARER_TOKEN}",
      },
      params: {
        "max_results" => 100,
        "start_time" => start_time,
        "end_time" => end_time,
        "tweet.fields" => "author_id,created_at,id",
      }
    }

    url = ENDPOINT_URL.gsub(':id', USER_ID.to_s)
    request = Typhoeus::Request.new(url, options)
    response = request.run
    # 自分の呟きだけをフィルタ

    JSON.parse(response.body)['data'].select {|d| d['author_id'] == USER_ID.to_s}
  end

  def data
    d = {
      main_summary: [],
      patients: []
    }

    get_user_tweets.each do |line|
      text = line['text'].gsub(' ', '').gsub('　', '').gsub('年代：', '').gsub('性別：', '').gsub('居住地：', '').gsub('職業：', '') + "\n"
      created_at = Time.parse(line['created_at']).in_time_zone('Asia/Tokyo')

      # main_summary
      main_summary = /【検査報告】\s(?<month>\d+)月(?<day>\d+)日[（(](?<曜日>[日月火水木金土])[)）]\s/.match(text)
      if main_summary
        h = {}
        # 実施報告件数の場合
        h.merge! main_summary.named_captures
        h.merge! /■実施報告[：:](?<実施報告>\d+)件\s.*※うち検出[：:](?<実施報告うち検出>\d+)件\s/.match(text).named_captures
        h.merge! /■検査内訳\s・県PCR検査[：:](?<県PCR検査>\d+)件\s・民間等[：:](?<民間等>\d+)件\s・地域外来等[：:](?<地域外来等>\d+)件\s・抗原検査[：:](?<抗原検査>\d+)件/.match(text).named_captures
        h.merge! /■累計[：:](?<累計>[\d,]+)件[（(]うち検出(?<累計う\sち検出>\d+)件[)）]\s/.match(text).named_captures
        h.merge! /■患者等状況\s・入院中(?<入院中>\d+)名[（(]うち重症者(?<入院中うち重症者>\d+)名[)）]\s・宿泊療養(?<宿泊療養>\d+)名\s・退院等(?<退院等>\d+)名\s・死亡者(?<死亡者>\d+)名\s・調整中(?<調整中>\d+)名/.match(text).named_captures
        h.merge! ({'date' => Date.parse("2021/#{h['month']}/#{h['day']}")})
        d[:main_summary] << h
      end


      # patients
      pat1 = /
        【第(?<例目>\d+?)例目】\s
        ①(?<年代>.+?)\s
        ②(?<性別>.+?)\s
        ③(?<居住地>.+?)\s
        ④(?<職業>.+?)\s
      /x

      pat2 = /
        【第(?<例目>\d+?)例目】\s
        ①(?<年代>.+?)\s
        ②(?<性別>.+?)\s
        ③(?<居住地>.+?)\s
        ④(?<職業>.+?)\s
        [・※](?<接触歴>.+)\s
      /x

      patients1 = text.scan(pat1)
      patients2 = text.scan(pat2)

      if patients1
        patients1.each do |patient|
          h = {}
          h['created_at'] = created_at
          h['id'] = patient[0].to_i
          h['年代'] = patient[1]
          h['性別'] = patient[2]
          h['居住地'] = patient[3].split(/[(（]/)[0]
          h['職業'] = patient[4]
          h['接触歴'] = '不明'
          d[:patients] << h
        end
      end

      if patients2
        patients2.each do |patient|
          d[:patients].reject!{|item| item['id'] == patient[0].to_i }
          h = {}
          h['created_at'] = created_at
          h['id'] = patient[0].to_i
          h['年代'] = patient[1]
          h['性別'] = patient[2]
          h['居住地'] = patient[3].split(/[(（]/)[0]
          h['職業'] = patient[4]
          h['接触歴'] = '判明'
          d[:patients] << h
        end
      end
    end
    d
  end

end

Tweet2TsvCLI.start

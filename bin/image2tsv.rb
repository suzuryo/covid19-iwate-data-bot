#!/usr/bin/env ruby
# frozen_string_literal: true

require 'active_support/all'
require 'dotenv/load'
require 'down'
require 'fileutils'
require 'highline/import'
require 'rtesseract'
require 'thor'
require 'typhoeus'

module Image2Tsv
  VERSION = '0.1.0'
  USERS_ENDPOINT_URL = 'https://api.twitter.com/2/users/:id/tweets'
  TWEETS_ENDPOINT_URL = 'https://api.twitter.com/2/tweets?ids=:tweet_ids'
  USER_ID = 1251721687415980032
  BEARER_TOKEN = ENV['TWITTER_BEARER_TOKEN']

  # TweetImage2Tsv CLI
  class Cli < Thor
    check_unknown_options!
    # デフォルトは generate
    default_command :generate
    # CLIの説明

    def self.exit_on_failure?
      true
    end

    def self.source_root
      File.join(__dir__, '../template/')
    end

    desc 'version', 'Display Iwate Covid19 Image2Tsv version'
    map %w[-v --version] => :version

    class_option 'verbose', type: :boolean, default: false

    def version
      say "Image2Tsv #{VERSION}"
    end

    desc 'generate', 'Generate a images.tsv'
    option :rm, type: :boolean

    def generate
      if options[:rm]
        exit unless HighLine.agree('本当にダウンロード済のPNGを削除しますか？ [y/N]')
        FileUtils.rm(Dir.glob(File.join(File.expand_path(File.join(__dir__, '../input/images')), '*.png')), force: true)
        FileUtils.rm(Dir.glob(File.join(File.expand_path(File.join(__dir__, '../input/images')), '*.jpg')), force: true)
      end

      now = Time.now
      days_ago = now.hour >= 15 ? now.days_ago(0) : now.days_ago(1)
      start_time = Time.new(days_ago.year, days_ago.month, days_ago.day, 15, 0, 0, '+09:00').rfc3339
      end_time = now.rfc3339

      options_ids = {
        method: 'get',
        headers: {
          'User-Agent' => 'v2RubyExampleCode',
          'Authorization' => "Bearer #{BEARER_TOKEN}"
        },
        params: {
          'max_results' => 100,
          'start_time' => start_time,
          'end_time' => end_time,
          'tweet.fields' => 'attachments,author_id,created_at,id'
        }
      }
      user_tweet_url = USERS_ENDPOINT_URL.gsub(':id', USER_ID.to_s)
      user_tweet_request = Typhoeus::Request.new(user_tweet_url, options_ids)
      user_tweet_response = user_tweet_request.run

      user_tweet_ids = JSON.parse(user_tweet_response.body)['data']
                         .select { |d| d['author_id'] == USER_ID.to_s && d['attachments'] }
                         .map { |d| d['id'] }

      options_media = {
        method: 'get',
        headers: {
          'User-Agent' => 'v2RubyExampleCode',
          'Authorization' => "Bearer #{BEARER_TOKEN}"
        },
        params: {
          'tweet.fields' => 'attachments,author_id,created_at,id',
          'media.fields' => 'url',
          'expansions' => 'attachments.media_keys'
        }
      }

      media_tweet_url = TWEETS_ENDPOINT_URL.gsub(':tweet_ids', user_tweet_ids.join(','))
      media_tweet_request = Typhoeus::Request.new(media_tweet_url, options_media)
      media_tweet_response = media_tweet_request.run

      media_urls = JSON.parse(media_tweet_response.body)['includes']['media'].map { |d| d['url'] }

      media_urls.each do |url|
        # Twitterからpngをダウンロード
        tempfile = Down.download("#{url}?name=4096x4096")

        # ファイルを移動して元の名前を維持する
        FileUtils.mv(tempfile.path, "./input/images/#{tempfile.original_filename}")

      end

      d1 = Date.today.strftime('%Y/%m/%d')
      d2 = Date.today.days_ago(1).strftime('%Y/%m/%d')

      cityArea = {
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
      cities = cityArea.keys

      # 管内の配列
      areas = cityArea.values.uniq

      h = {}

      Dir.glob([
                 File.join(File.expand_path(File.join(__dir__, '../input/images')), '*.png'),
                 File.join(File.expand_path(File.join(__dir__, '../input/images')), '*.jpg')
               ]).each do |file|
        p file
        image = RTesseract.new(file, lang: 'jpn')
        text = image.to_s.gsub('|', '')

        text.split(/\n/).each do |a|
          row = a
                  .gsub(' ', '')
                  .gsub(/紀岡市|貫岡市|大岡市|弓岡市|紅岡市|答岡市|故岡市/, '盛岡市')
                  .gsub(/替石町/, '雫石町')
                  .gsub(/ー関市|-関市|—関市|ｰ関市|−関市|–関市/, '一関市')
                  .gsub(/ー関保健所管内|-関保健所管内|—関保健所管内|ｰ関保健所管内|−関保健所管内|–関保健所管内/, '一関保健所管内')
                  .gsub(/自州保健所管内|臭州保健所管内/, '奥州保健所管内')
                  .gsub(/県天保健所管内/, '県央保健所管内')
                  .gsub(/10穫未満/, '10歳未満')
                  .gsub(/90穫以上/, '90歳以上')
                  .gsub(/10穫/, '10代')
                  .gsub(/20穫/, '20代')
                  .gsub(/30穫/, '30代')
                  .gsub(/40穫/, '40代')
                  .gsub(/50穫/, '50代')
                  .gsub(/60穫/, '60代')
                  .gsub(/70穫/, '70代')
                  .gsub(/80穫/, '80代')

          next if row.blank?

          r_id = /^(?<id>\d{5})/.match(row)

          p row
          next if r_id.blank?
          r_age = /(?<age>10歳未満|10代|20代|30代|40代|50代|60代|70代|80代|90歳以上)/.match(row)
          r_sex = /(?<sex>男|女)/.match(row)
          r_city = /(?<city>#{cities.join('|')}|#{areas.join('|')})/.match(row)
          r_track = /あり/.match(row)
          id = r_id.nil? ? '' : r_id[:id].to_s
          age = if r_age.nil?
                  ''
                else
                  r_age[:age].to_s
                end
          sex = r_sex.nil? ? '' : r_sex[:sex].to_s.gsub('女', '女性').gsub('男', '男性')
          track = r_track.nil? ? '不明' : '判明'
          city = if r_city.nil?
                   ''
                 else
                   r_city[:city].to_s
                 end

          unless id.blank?
            h[id] = {
              id: id,
              age: age,
              sex: sex,
              city: city,
              track: track
            }
          end
        end
      end

      tsv = ''
      prev_val = 0
      h.sort_by { |_k, v| v[:id] }.each_with_index do |v, i|
        tsv += if i.zero? || prev_val == v[0].to_i - i
                 "#{v[1][:id]}\t#{d1}\t#{d2}\t\t\t#{v[1][:age]}\t#{v[1][:sex]}\t#{v[1][:city]}\t\t\t\t#{v[1][:track]}\tPCR検査\n"
               else
                 "#{prev_val + 1}\n"
               end

        prev_val = v[0].to_i - i
      end

      File.write(File.join(__dir__, '../tsv/', 'images.tsv'), tsv)
    end
  end
end

Image2Tsv::Cli.start

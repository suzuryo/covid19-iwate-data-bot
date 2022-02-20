#!/usr/bin/env ruby
# frozen_string_literal: true

require 'active_support/all'
require 'dotenv/load'
require 'rtesseract'
require 'thor'

module Image2Tsv
  VERSION = '0.1.0'
  BEARER_TOKEN = ENV['TWITTER_BEARER_TOKEN']

  # TweetImage2Tsv CLI
  class Cli < Thor
    check_unknown_options!
    include Thor::Actions

    default_command :new

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

    desc 'new', 'Create a new image.tsv'
    def new

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

      Dir.glob(['input/images/*.png', 'input/images/*.jpg']).each do |file|
        image = RTesseract.new(file, lang: 'jpn')
        text = image.to_s.gsub('|', '')

        text.split(/\n/).each do |a|
          row = a.gsub(' ', '')
          next if row.blank?

          r_id = /^(?<id>\d\d\d\d)/.match(row)

          p row
          next if r_id.blank?
          r_age = /(?<age>10歳未満|10代|20代|30代|40代|50代|60代|70代|80代|90歳以上)/.match(row)
          r_sex = /(?<sex>男|女)/.match(row)
          r_city = /(?<city>#{cities.join('|')}|#{areas.join('|')})|紀岡市|貫岡市|大岡市|弓岡市|紅岡市|答岡市|故岡市|ー関市|ー関保健所管内|自州保健所管内|臭州保健所管内|県天保健所管内/.match(row)
          r_track = /あり/.match(row)
          id = r_id.nil? ? '' : r_id[:id].to_s
          age = r_age.nil? ? '' : r_age[:age].to_s
          sex = r_sex.nil? ? '' : r_sex[:sex].to_s.gsub('女', '女性').gsub('男', '男性')
          track = r_track.nil? ? '不明' : '判明'
          city = if r_city.nil?
                   ''
                 else
                   r_city[:city].to_s
                                .gsub(/紀岡市|貫岡市|大岡市|弓岡市|紅岡市|答岡市|故岡市/, '盛岡市')
                                .gsub(/ー関市/, '一関市')
                                .gsub(/ー関保健所管内/, '一関保健所管内')
                                .gsub(/自州保健所管内|臭州保健所管内/, '奥州保健所管内')
                                .gsub(/県天保健所管内/, '県央保健所管内')
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

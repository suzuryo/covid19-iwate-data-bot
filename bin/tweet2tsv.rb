#!/usr/bin/env ruby
# frozen_string_literal: true

require 'active_support/core_ext/time'
require 'dotenv/load'
require 'json'
require 'thor'
require 'typhoeus'
require_relative '../lib/twitter'

module Tweet2Tsv
  VERSION = '0.1.0'
  ENDPOINT_URL = 'https://api.twitter.com/2/users/:id/tweets'
  USER_ID = 1251721687415980032
  BEARER_TOKEN = ENV['TWITTER_BEARER_TOKEN']

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

    desc 'version', 'Display Iwate Covid19 Tweet2Tsv version'
    map %w[-v --version] => :version

    class_option 'verbose', type: :boolean, default: false

    def version
      say "Tweet2Tsv #{VERSION}"
    end

    desc 'new', 'Create a new tweet.tsv'
    option :days, type: :numeric, default: 1, aliases: '-d'

    def new
      # オプションが指定されていなければ、直近1日分のデータを取得
      days = options[:days].nil? ? 1 : options[:days].to_i

      tweets = Tweet2Tsv::Twitter.new(days)

      # 最新データが空ならば何もしない
      raise Error, set_color('ERROR: data blank', :red) if tweets.data.blank?

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
        @positive_cases += "#{b['id']}\t#{b['created_at'].strftime('%Y/%m/%d')}\t#{b['created_at'].days_ago(1).strftime('%Y/%m/%d')}\t\t\t#{b['年代']}\t#{b['性別']}\t#{b['居住地']}\t\t\t#{b['接触歴']}\t\tPCR検査\t#{b['職業']}"
        prev_id = b['id']
      end

      remove_file File.join(__dir__, '../tsv/tweet.tsv')
      template File.join(__dir__, '../template/tweet.tsv.erb'), File.join(__dir__, '../tsv/tweet.tsv')
    end
  end
end

Tweet2Tsv::Cli.start

#!/usr/bin/env ruby
# frozen_string_literal: true

require 'active_support/core_ext/date'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'thor'
require_relative '../lib/site'
require_relative '../lib/settings'

module Site2Tsv
  class Cli < Thor
    # remove_file や template を利用する
    include Thor::Actions
    # 規定外のオプションをチェック
    check_unknown_options!
    # デフォルトは generate
    default_command :generate
    # CLIの説明
    desc 'generate', 'Generate a site.tsv'
    option :id, type: :numeric

    def generate
      # オプションが指定されていなければ、公開済みの昨日のid以降を取得
      id = options[:id].nil? ? recent_id : options[:id].to_i
      # データの取得
      data = SITES.map do |_city, site|
        Site2Tsv::Site.new(site: site, id: id).data
      end.flatten

      # データが空ならば何もしない
      raise Error, set_color('ERROR: data blank', :red) if data.blank?

      # 文字列組み立て
      @patients = ''
      prev_id = id
      data.sort_by { |a| a['id'] }.uniq.each do |b|
        @patients += "\n" * (b['id'] - prev_id)
        @patients += "#{b['id']}\t#{b['リリース日']}\t#{b['確定日']}\t#{b['発症日']}\t#{b['無症状']}\t#{b['年代']}\t#{b['性別']}\t#{b['居住地']}\t#{b['入院日']}\t#{b['url']}\t#{b['接触歴']}"
        prev_id = b['id']
      end

      remove_file File.join(__dir__, '../tsv/site.tsv')
      template File.join(__dir__, '../template/site.tsv.erb'), File.join(__dir__, '../tsv/site.tsv')
    end

    def self.exit_on_failure?
      true
    end

    def self.source_root
      File.join(__dir__, '../template/')
    end

    private

    def recent_id
      json = JSON.parse(URI.open('https://raw.githubusercontent.com/MeditationDuck/covid19/development/data/data.json').read)
      json['patients']['data']
        .filter { |a| Time.parse(a['確定日']) < Time.parse(json['patients']['data'].last['確定日']) }
        .max_by { |a| a['id'] }['id']
        .to_i + 1
    end
  end
end

Site2Tsv::Cli.start

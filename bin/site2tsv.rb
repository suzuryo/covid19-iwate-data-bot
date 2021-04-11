#!/usr/bin/env ruby
# frozen_string_literal: true

require 'active_support/core_ext/date'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'thor'
require_relative 'lib/SiteParser'

module Site2Tsv
  VERSION = '0.1.0'
  MORIOKA_URL = 'http://www.city.morioka.iwate.jp/kenkou/kenko/1031971/1032075/1032217/'
  IWATE_URL = 'https://www.pref.iwate.jp/kurashikankyou/iryou/covid19/1039755/index.html'

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
      say "Site2Tsv #{VERSION}"
    end

    desc 'new', 'Create a new site.tsv'
    option :id, type: :numeric, aliases: '-1'

    def new
      # オプションが指定されていなければ、公開済みの昨日のid以降を取得
      id = options[:id].nil? ? recent_id : options[:id].to_i

      sites = Site2Tsv::SiteParser.new(
        id: id,
        url_iwate: IWATE_URL,
        url_morioka: MORIOKA_URL
      )

      # 最新データが空ならば何もしない
      raise Error, set_color('ERROR: data blank', :red) if sites.data.blank?

      @patients = ""
      prev_id = id
      sites.data.sort_by { |a| a[:id] }.uniq.each do |b|
        @patients += "\n" * (b[:id] - prev_id)
        @patients += "#{b[:id]}\t#{b[:リリース日]}\t#{b[:確定日]}\t#{b[:発症日]}\t#{b[:無症状]}\t#{b[:年代]}\t#{b[:性別]}\t#{b[:居住地]}\t#{b[:入院日]}\t#{b[:url]}\t#{b[:接触歴]}"
        prev_id = b[:id]
      end

      remove_file File.join(__dir__, '../tsv/site.tsv')
      template File.join(__dir__, '../template/site.tsv.erb'), File.join(__dir__, '../tsv/site.tsv')
    end

    private

    def recent_id
      json = JSON.parse(URI.open('https://raw.githubusercontent.com/MeditationDuck/covid19/development/data/data.json').read)
      json['patients']['data'].filter{|a| Time.parse(a['確定日']) < Time.parse(json['patients']['data'][-1]['確定日'])}.sort_by{|a| a['id']}[-1]['id'].to_i + 1
    end

  end

end

Site2Tsv::Cli.start

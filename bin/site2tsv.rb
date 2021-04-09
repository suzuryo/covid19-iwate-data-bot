#!/usr/bin/env ruby
# frozen_string_literal: true

require 'active_support/core_ext/date'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'thor'
require_relative 'lib/Site2TSV'

class Site2TsvCLI < Thor
  # Google Sheets にコピペしやすいTSVデータを出力する
  # data/sites.tsv にファイルが出力される
  #
  # ./generate_tsv.rb
  # オプションを何も指定しないと、最新のid以降のデータを探して出力する
  #
  # ./generate_tsv.rb generate --id 667
  # オプション id を指定すると、それ以降のidのデータを探して出力する

  default_command :generate
  option :id, type: :numeric
  desc 'generate', 'generate tsv data'

  def generate
    if options[:id].nil?
      # オプションが指定されていなければ、公開済みの昨日のid以降を取得
      json = JSON.parse(URI.open('https://raw.githubusercontent.com/MeditationDuck/covid19/development/data/data.json').read)
      id = json['patients']['data'].filter{|a| Time.parse(a['確定日']) < Time.parse(json['patients']['data'][-1]['確定日'])}.sort_by{|a| a['id']}[-1]['id'].to_i + 1
    else
      # オプションが指定されていれば、そのidを採用
      id = options[:id]
    end

    sites = Site2TSV.new(
      id: id,
      url_iwate: 'https://www.pref.iwate.jp/kurashikankyou/iryou/covid19/1039755/index.html',
      url_morioka: 'http://www.city.morioka.iwate.jp/kenkou/kenko/1031971/1032075/1032217/'
    )

    # 最新データが空ならば何もしない
    return if sites.data.blank?

    # 最新データがあればファイルを保存
    File.open(File.join(__dir__, '../tsv/', 'site.tsv'), 'w') do |f|
      prev_id = id
      sites.data.sort_by { |a| a[:id] }.uniq.each do |b|
        f.write "\n" * (b[:id] - prev_id)
        f.write "#{b[:id]}\t#{b[:リリース日]}\t#{b[:確定日]}\t#{b[:発症日]}\t#{b[:無症状]}\t#{b[:年代]}\t#{b[:性別]}\t#{b[:居住地]}\t#{b[:入院日]}\t#{b[:url]}\t#{b[:接触歴]}"
        prev_id = b[:id]
      end
    end
  end

  def self.exit_on_failure?
    true
  end
end

Site2TsvCLI.start

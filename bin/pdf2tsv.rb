#!/usr/bin/env ruby
# frozen_string_literal: true

require 'active_support/all'
require 'csv'
require 'down'
require 'fileutils'
require 'highline/import'
require 'nokogiri'
require 'open-uri'
require 'thor'
require_relative '../lib/settings'

module Pdf2Tsv
  # Site2Tsv CLI
  class Cli < Thor
    # remove_file や template を利用する
    include Thor::Actions
    # 規定外のオプションをチェック
    check_unknown_options!
    # デフォルトは generate
    default_command :generate
    # CLIの説明
    desc 'generate', 'Generate a pdf.tsv'
    option :rm, type: :boolean

    def generate
      cities = PDFS.keys

      if options[:rm]
        exit unless HighLine.agree('本当にダウンロード済のPDFと変換済みのCSVファイルを削除しますか？ [y/N]')
        cities.each do |city|
          FileUtils.rm(Dir.glob(File.join(PDFS[city][:pdf_dir], '*.pdf')), force: true)
          FileUtils.rm(Dir.glob(File.join(PDFS[city][:csv_dir], '*.csv')), force: true)
        end
      end

      # データ取得
      @patients = []
      cities.each do |city|
        @patients += parse_pdf(city)
      end
      @patients.sort_by! { |a| a['id'].to_s }

      # TSV文字列組み立て
      @tsv = ''
      unless @patients.blank?
        prev_id = @patients.first['id']
        @patients.each do |b|
          @tsv += "\n" * (b['id'] - prev_id)
          @tsv += "#{b['id']}\t#{b['リリース日']}\t#{b['確定日']}\t#{b['発症日']}\t#{b['無症状']}\t#{b['年代']}\t#{b['性別']}\t#{b['居住地']}\t#{b['滞在地']}\t#{b['入院日']}\t#{b['url']}\t#{b['接触歴']}\t#{b['陽性最終確定検査手法']}"
          prev_id = b['id']
        end
      end

      # データが空ならば何もしない
      raise Error, set_color('ERROR: patients blank', :red) if @tsv.blank?

      remove_file File.join(__dir__, '../tsv/pdf.tsv')
      template File.join(__dir__, '../template/pdf.tsv.erb'), File.join(__dir__, '../tsv/pdf.tsv')
    end

    def self.exit_on_failure?
      true
    end

    def self.source_root
      File.join(__dir__, '../template/')
    end

    private

    def parse_pdf(city)
      files = []

      # すでにダウンロード済みのPDFファイル
      pdf_filenames = Dir.children(PDFS[city][:pdf_dir]).reject {|a| a.to_s.include? '.gitkeep'}

      # ページからPDFのURLを抜き出す
      html = URI.open(PDFS[city][:url]).read

      # ダウンロードしたファイル名
      new_pdf_filenames = []
      Nokogiri::HTML(html).css(PDFS[city][:selector]).filter_map do |node|
        # pdfファイルのURLを絶対パスにする
        url = node[:href].gsub(PDFS[city][:url_replace][0], PDFS[city][:url_replace][1])
        pdf_filename =  File.basename(URI.parse(url).path)

        # ダウンロード済みの場合はスキップ
        next if pdf_filenames.include? pdf_filename

        # ダウンロード
        tempfile = Down.download(url)

        # ファイル名出力 新規ファイルならば NEW ! を付ける
        p "#{pdf_filename}#{' [ NEW ]' unless pdf_filenames.include? pdf_filename}"

        # ファイルをPDF_DIRに移動して元の名前を維持する
        FileUtils.mv(tempfile.path, "#{PDFS[city][:pdf_dir]}/#{pdf_filename}")

        files << {url: url, pdf: "#{PDFS[city][:pdf_dir]}/#{pdf_filename}"}

        # ダウンロードしたファイル名
        new_pdf_filenames << pdf_filename
      end

      # PDFからcamelotでテーブルを検出してCSVを生成
      files.map {|a| a[:pdf] }.each do |pdf|
        # すでに生成済みのCSVファイル
        csv_filenames = Dir.children(PDFS[city][:csv_dir]).reject { |a| a.to_s.include? '.gitkeep' }
        `camelot --pages 1-end --format csv --output #{File.join(PDFS[city][:csv_dir], File.basename(pdf, '.*'))}.csv lattice #{pdf}`
        files.find{ |b| b[:pdf] === pdf }[:csv] = (Dir.children(PDFS[city][:csv_dir]).reject { |a| a.to_s.include? '.gitkeep' } - csv_filenames)
      end

      patients = []

      if city === :morioka
        # 盛岡市の場合
        files.map {|a| a[:csv]}.flatten.each do |f|
          csv_file = File.join(PDFS[city][:csv_dir], f)
          CSV.read(csv_file, headers: true).each do |row|
            pp row
            h = {}
            # id、年代、性別はPDFからの認識ミスが発生するので、正規表現で取り出す
            m1 = /(?<id>\d{4,5})\s*[(（](?<morioka_id>\d{4})[)）](?<age>\d{2}(代|歳未満|歳以上))\s*(?<sex>[男|女]性)/.match(row[0] + row[1] + row[2])&.named_captures
            h['id'] = m1 ? m1['id'].to_i : ''
            next if h['id'].blank?

            h['年代'] = m1 ? m1['age'] : ''
            h['性別'] = m1 ? m1['sex'] : ''

            r3 = row[3].gsub(/\s/, '')
            h['居住地'] = r3
            h['滞在地'] = if r3.match(/盛岡市/)
                         ''
                       else
                         '盛岡市'
                       end

            h['職業'] = row[7]

            if row[4].match(/無症状/)
              # 症状が無い場合は発症日が空
              h['無症状'] = '無症状'
              h['発症日'] = ''
            else
              # 無症状でない場合
              h['無症状'] = ''
              p row[5]
              m2 = row[5].match(/(?<month>\d+)\/(?<day>\d+)/)
              h['発症日'] = m2 ? Date.parse("2022/#{m2[:month]}/#{m2[:day]}").strftime('%Y/%m/%d') : ''
              p h['発症日']
            end

            h['陽性最終確定検査手法'] = 'PCR検査'

            h['接触歴'] = row[6].length > 1 ? '判明' : '不明'

            m2 = /^04(?<month>\d{1,2})(?<day>\d{1,2})/.match f

            h['リリース日'] = m2 ? Date.parse("2022/#{m2[:month]}/#{m2[:day]}").strftime('%Y/%m/%d') : ''
            h['確定日'] = m2 ? Date.parse("2022/#{m2[:month]}/#{m2[:day]}").days_ago(1).strftime('%Y/%m/%d') : ''
            h['url'] = files.find { |a| a[:csv].include? f }[:url]
            patients << h
          end
        end
      end

      if city === :iwate
        # 岩手県の場合
        files.map {|a| a[:csv]}.flatten.each do |f|
          csv_file = File.join(PDFS[city][:csv_dir], f)
          CSV.read(csv_file, headers: true).each do |row|
            pp row
            h = {}
            # id、年代、性別はPDFからの認識ミスが発生するので、正規表現で取り出す
            m1 = /(?<id>\d{4,5})\s*(?<age>\d{2}(代|歳未満|歳以上))\s*(?<sex>[男|女]性)/.match(row[0] + row[1] + row[2])&.named_captures
            h['id'] = m1 ? m1['id'].to_i : ''
            next if h['id'].blank?

            h['年代'] = m1 ? m1['age'] : ''
            h['性別'] = m1 ? m1['sex'] : ''

            r3 = row[3].gsub(/\s/, '')
            h['居住地'] = r3.split(/[(（]/)[0]
            h['滞在地'] = if r3.split(/[(（]/)[1].nil?
                         ''
                       else
                         r3.split(/[(（]/)[1].gsub(/[)）]/, '')
                       end

            h['職業'] = row[7]

            if row[4].match(/無症状/)
              # 症状が無い場合は発症日が空
              h['無症状'] = '無症状'
              h['発症日'] = ''
            else
              # 無症状でない場合
              h['無症状'] = ''
              m2 = row[5].match(/(?<month>\d+)月(?<day>\d+)日/)
              h['発症日'] = m2 ? Date.parse("2022/#{m2[:month]}/#{m2[:day]}").strftime('%Y/%m/%d') : ''
            end

            # 2022/01/28 から検査確定手法の記載が無くなったため、PCRに固定
            h['陽性最終確定検査手法'] = 'PCR検査'

            h['接触歴'] = row[6].length > 1 ? '判明' : '不明'
            h['接触歴'] = '不明' if row[6] == '(cid:695)'

            m2 = /(?<year>2022)(?<month>.{2})(?<day>.{2})/.match f

            h['リリース日'] = m2 ? Date.parse("#{m2[:year]}/#{m2[:month]}/#{m2[:day]}").strftime('%Y/%m/%d') : ''
            h['確定日'] = m2 ? Date.parse("#{m2[:year]}/#{m2[:month]}/#{m2[:day]}").days_ago(1).strftime('%Y/%m/%d') : ''
            h['url'] = files.find { |a| a[:csv].include? f }[:url]
            patients << h
          end
        end
      end
      patients
    end
  end
end

Pdf2Tsv::Cli.start

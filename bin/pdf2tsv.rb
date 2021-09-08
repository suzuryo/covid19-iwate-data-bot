#!/usr/bin/env ruby
# frozen_string_literal: true

require 'active_support/core_ext/date'
require 'csv'
require 'down'
require 'fileutils'
require 'nokogiri'
require 'open-uri'
require 'thor'

PDF_DIR_IWATE = File.expand_path(File.join(__dir__, '../download/pdf/iwate'))
CSV_DIR_IWATE = File.expand_path(File.join(__dir__, '../download/csv/iwate'))
PDF_DIR_MORIOKA = File.expand_path(File.join(__dir__, '../download/pdf/morioka'))
CSV_DIR_MORIOKA = File.expand_path(File.join(__dir__, '../download/csv/morioka'))

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
    desc 'generate', 'Generate a site.tsv'

    def generate
      # 文字列組み立て
      @patients = []
      @patients += iwate
      @patients += morioka
      @patients.sort_by! { |a| a['id'] }

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

    def morioka
      files = []
      # すでにダウンロード済みのPDFファイル
      pdf_filenames = Dir.children(PDF_DIR_MORIOKA).reject {|a| a.to_s.include? '.gitkeep'}

      # 盛岡市のページからPDFのURLを抜き出す
      html = URI.open('http://www.city.morioka.iwate.jp/kenkou/kenko/1031971/1032075/1036827.html').read

      # ダウンロードしたファイル名
      new_pdf_filenames = []
      Nokogiri::HTML(html).css('#voice > h2 + p + ul.objectlink > li.pdf > a[href$=".pdf"]').filter_map do |node|
        # pdfファイルのURLを絶対パスにする
        url = node[:href].gsub('../../../../', 'http://www.city.morioka.iwate.jp/')
        pdf_filename =  File.basename(URI.parse(url).path)

        # ダウンロード済みの場合はスキップ
        next if pdf_filenames.include? pdf_filename

        # ダウンロード
        tempfile = Down.download(url)

        # ファイル名出力 新規ファイルならば NEW ! を付ける
        p "#{pdf_filename}#{' [ NEW ]' unless pdf_filenames.include? pdf_filename}"

        # ファイルをPDF_DIRに移動して元の名前を維持する
        FileUtils.mv(tempfile.path, "#{PDF_DIR_MORIOKA}/#{pdf_filename}")

        files << {url: url, pdf: "#{PDF_DIR_MORIOKA}/#{pdf_filename}"}

        # ダウンロードしたファイル名
        new_pdf_filenames << pdf_filename
      end

      # PDFからcamelotでテーブルを検出してCSVを生成
      files.map {|a| a[:pdf] }.each do |pdf|
        # すでに生成済みのCSVファイル
        csv_filenames = Dir.children(CSV_DIR_MORIOKA).reject { |a| a.to_s.include? '.gitkeep' }
        `camelot --pages 1-end --format csv --output #{File.join(CSV_DIR_MORIOKA, File.basename(pdf, '.*'))}.csv lattice #{pdf}`
        files.find{ |b| b[:pdf] === pdf }[:csv] = (Dir.children(CSV_DIR_MORIOKA).reject { |a| a.to_s.include? '.gitkeep' } - csv_filenames)
      end

      patients = []

      files.map {|a| a[:csv]}.flatten.each do |f|
        csv_file = File.join(CSV_DIR_MORIOKA, f)
        CSV.read(csv_file, headers: true).each do |row|
          h = {}
          # id、年代、性別はPDFからの認識ミスが発生するので、正規表現で取り出す
          m1 = /(?<id>\d{4})\s*[(（](?<morioka_id>\d{4})[)）](?<age>\d{2}(代|歳未満|歳以上))\s*(?<sex>[男|女]性)/.match(row[0] + row[1] + row[2])&.named_captures
          h['id'] = m1['id'].to_i
          h['年代'] = m1['age']
          h['性別'] = m1['sex']

          r3 = row[3].gsub(/\s/, '')
          h['居住地'] = if /^県外/.match r3.split(/[(（]/)[0]
                       '県外'
                     else
                       r3.split(/[(（]/)[0].gsub('滞在地', '').gsub(/[:：]/, '')
                     end
          h['滞在地'] = unless r3.split(/滞在地[:：]/)[1].nil?
                       r3.split(/滞在地/)[1].split(/[(（]/)[0].gsub('滞在地', '').gsub(/[:：]/, '').gsub(/[)）]/, '')
                     else
                       nil
                     end

          h['職業'] = row[4]

          if row[5].match(/無症状/)
            # 症状が無い場合は発症日が空
            h['無症状'] = '無症状'
            h['発症日'] = nil
          else
            # 無症状でない場合
            h['無症状'] = nil
            m2 = row[6].match(/(?<month>\d+)\/(?<day>\d+)/)
            h['発症日'] = m2 ? Date.parse("2021/#{m2[:month]}/#{m2[:day]}").strftime('%Y/%m/%d') : ''
          end

          h['陽性最終確定検査手法'] = if /PCR[：:]検出/.match row[8]
                              'PCR検査'
                            elsif /抗原[：:]検出/.match row[8]
                              '抗原検査'
                            else
                              nil
                            end

          h['接触歴'] = row[13].length > 1 ? '判明' : '不明'

          m2 = /^(?<month>\d{1,2})(?<day>\d{1,2})/.match f

          h['リリース日'] = m2 ? Date.parse("2021/#{m2[:month]}/#{m2[:day]}").strftime('%Y/%m/%d') : ''
          h['確定日'] = m2 ? Date.parse("2021/#{m2[:month]}/#{m2[:day]}").days_ago(1).strftime('%Y/%m/%d') : ''
          h['url'] = files.find { |a| a[:csv].include? f }[:url]
          patients << h
        end
      end

      patients
    end

    def iwate
      files = []
      # すでにダウンロード済みのPDFファイル
      pdf_filenames = Dir.children(PDF_DIR_IWATE).reject {|a| a.to_s.include? '.gitkeep'}

      # 岩手県のページからPDFのURLを抜き出す
      html = URI.open('https://www.pref.iwate.jp/kurashikankyou/iryou/covid19/1046698.html').read

      # ダウンロードしたファイル名
      new_pdf_filenames = []
      Nokogiri::HTML(html).css('#voice > ul.objectlink > li.pdf > a').filter_map do |node|
        # pdfファイルのURLを絶対パスにする
        url = node[:href].gsub('../../../', 'https://www.pref.iwate.jp/')
        pdf_filename =  File.basename(URI.parse(url).path)

        # ダウンロード済みの場合はスキップ
        next if pdf_filenames.include? pdf_filename

        # ダウンロード
        tempfile = Down.download(url)

        # ファイル名出力 新規ファイルならば NEW ! を付ける
        p "#{pdf_filename}#{' [ NEW ]' unless pdf_filenames.include? pdf_filename}"

        # ファイルをPDF_DIRに移動して元の名前を維持する
        FileUtils.mv(tempfile.path, "#{PDF_DIR_IWATE}/#{pdf_filename}")

        files << {url: url, pdf: "#{PDF_DIR_IWATE}/#{pdf_filename}"}

        # ダウンロードしたファイル名
        new_pdf_filenames << pdf_filename
      end

      # デバッグ用
      # new_pdf_filenames = Dir.children(PDF_DIR).reject {|a| a.to_s.include? '.gitkeep'}

      # PDFからcamelotでテーブルを検出してCSVを生成
      files.map {|a| a[:pdf] }.each do |pdf|
        # すでに生成済みのCSVファイル
        csv_filenames = Dir.children(CSV_DIR_IWATE).reject { |a| a.to_s.include? '.gitkeep' }
        `camelot --pages 1-end --format csv --output #{File.join(CSV_DIR_IWATE, File.basename(pdf, '.*'))}.csv lattice #{pdf}`
        files.find{ |b| b[:pdf] === pdf }[:csv] = (Dir.children(CSV_DIR_IWATE).reject { |a| a.to_s.include? '.gitkeep' } - csv_filenames)
      end

      patients = []

      files.map {|a| a[:csv]}.flatten.each do |f|
        csv_file = File.join(CSV_DIR_IWATE, f)
        CSV.read(csv_file, headers: true).each do |row|
          h = {}
          # id、年代、性別はPDFからの認識ミスが発生するので、正規表現で取り出す
          m1 = /(?<id>\d{4})\s*(?<age>\d{2}(代|歳未満|歳以上))\s*(?<sex>[男|女]性)/.match(row[0] + row[1] + row[2])&.named_captures
          h['id'] = m1['id'].to_i
          h['年代'] = m1['age']
          h['性別'] = m1['sex']

          r3 = row[3].gsub(/\s/, '')
          h['居住地'] = if /^県外/.match r3.split(/[(（]/)[0]
                       '県外'
                     else
                       r3.split(/[(（]/)[0].gsub('滞在地', '').gsub(/[:：]/, '')
                     end
          h['滞在地'] = unless r3.split(/滞在地[:：]/)[1].nil?
                       r3.split(/滞在地/)[1].split(/[(（]/)[0].gsub('滞在地', '').gsub(/[:：]/, '').gsub(/[)）]/, '')
                     else
                       nil
                     end

          h['職業'] = row[4]

          if row[5].match(/無症状/)
            # 症状が無い場合は発症日が空
            h['無症状'] = '無症状'
            h['発症日'] = nil
          else
            # 無症状でない場合
            h['無症状'] = nil
            m2 = row[6].match(/(?<month>\d+)月(?<day>\d+)日/)
            h['発症日'] = m2 ? Date.parse("2021/#{m2[:month]}/#{m2[:day]}").strftime('%Y/%m/%d') : ''
          end

          h['陽性最終確定検査手法'] = if /PCR[：:]検出/.match row[8]
                              'PCR検査'
                            elsif /抗原[：:]検出/.match row[8]
                              '抗原検査'
                            else
                              nil
                            end

          h['接触歴'] = row[13].length > 1 ? '判明' : '不明'

          m2 = /(?<year>2021)(?<month>.{2})(?<day>.{2})/.match f

          h['リリース日'] = m2 ? Date.parse("#{m2[:year]}/#{m2[:month]}/#{m2[:day]}").strftime('%Y/%m/%d') : ''
          h['確定日'] = m2 ? Date.parse("#{m2[:year]}/#{m2[:month]}/#{m2[:day]}").days_ago(1).strftime('%Y/%m/%d') : ''
          h['url'] = files.find { |a| a[:csv].include? f }[:url]
          patients << h
        end
      end

      patients
    end
  end
end

Pdf2Tsv::Cli.start

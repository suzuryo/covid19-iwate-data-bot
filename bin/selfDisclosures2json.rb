#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'time'
require 'date'
require 'active_support/all'
require_relative '../lib/googlesheets'

GoogleSheets = GoogleSheetsIwate.new

# ここまで Google Sheets API を使うための Quickstart テンプレ
# https://developers.google.com/sheets/api/quickstart/ruby

######################################################################
# Google Sheets から batch_get_spreadsheet_values した値をシートごとに Hash の Array にする
######################################################################

SELF_DISCLOSURES = GoogleSheets.data(GoogleSheetsIwate::SHEET_RANGES[:SELF_DISCLOSURES])
raise if SELF_DISCLOSURES.empty?

######################################################################
# Common
######################################################################
# データを生成した日時
now = Time.now

######################################################################
# データ生成 テンプレート
# self_disclosures.json
######################################################################
data_self_disclosures_json = {
  date: now.iso8601,
  newsItems: []
}

SELF_DISCLOSURES.each do |row|
  data_self_disclosures_json[:newsItems].append(
    {
      date: Time.parse(row['date']).strftime('%Y-%m-%d'),
      url: {
        ja: row['url_ja'].blank? ? nil : row['url_ja'],
        en: row['url_en'].blank? ? nil : row['url_en']
      },
      text: {
        ja: row['text_ja'].blank? ? nil : row['text_ja'],
        en: row['text_en'].blank? ? nil : row['text_en']
      }
    }
  )
end


######################################################################
# write json
######################################################################

File.write(File.join(__dir__, '../data/', 'self_disclosures.json'), JSON.generate(data_self_disclosures_json))

# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../lib/site/morioka'
require_relative '../../lib/googlesheets'
require_relative '../../lib/settings'

describe 'Morioka' do
  before :all do
    # 盛岡市のid 78未満はフォーマットが安定しないのでスキップ
    # 盛岡市のid 415未満は発症日が年をまたぐのでスキップ
    @site_morioka = Morioka.new(url: SITES[:morioka][:url].to_s, selector: SITES[:morioka][:selector].to_s, id: TARGET_MIN_ID)
    @urls = @site_morioka.uris
    @google_sheets = GoogleSheetsIwate.new
  end

  describe 'uris method' do
    it 'url が iwate の url を入れると raise' do
      morioka = Morioka.new(url: SITES[:iwate][:url].to_s, selector: SITES[:morioka][:selector].to_s, id: TARGET_MIN_ID)
      expect { morioka.data }.to raise_error NotValidUrlError
    end

    it 'url が iwate の url を入れると not raise' do
      expect { @site_morioka.uris }.not_to raise_error
    end

    it 'uris methods の戻り値は URI の array' do
      expect(@urls.class).to eq Array
      expect(@urls.first.instance_of?(URI::HTTP)).to eq true
    end
  end

  describe 'data methods' do
    describe 'city.moriokaのサイトから読み込んだデータに対しての検証' do
      it 'MeditationDuck/covid19 の data.json の patients の項目 について' do
        data = @site_morioka.data
        data.each do |d|
          id = d['id']
          next if id < TARGET_MIN_ID

          # # DEBUG
          # p id

          expect(d['id']).to eq find_data(id)['id']
          expect(d['確定日']).to eq Date.parse(find_data(id)['確定日']).strftime '%Y/%m/%d'
          expect(d['発症日']).to eq Date.parse(find_data(id)['発症日']).strftime '%Y/%m/%d' if find_data(id)['発症日']
          expect(d['無症状']).to eq find_data(id)['無症状'] ? '無症状' : ''
          expect(d['年代']).to eq find_data(id)['年代']
          expect(d['居住地']).to eq find_data(id)['居住地']
          expect(d['url']).to eq find_data(id)['url']
          # 1181 は過去の事例との接触歴ありだけど公表資料には何も書かないので、
          # プログラム的に資料上では不明と判定されるが、パーサーの方で対応済みなので、他と同じようにチェックできる
          expect(d['接触歴']).to eq find_data(id)['接触歴']

          # 以下 data.json には含めていない項目
          # expect(d['性別']).to eq find_data(id)['性別']
          # expect(d['職業']).to eq find_data(id)['職業']
          # expect(d['入院日']).to eq Date.parse(find_data(id)['入院日']).strftime '%Y/%m/%d'
        end
      end
    end

    describe 'google sheets から読み込んだデータに対しての検証' do
      it 'google sheets の項目について' do
        google_sheets = @google_sheets.data(GoogleSheetsIwate::SHEET_RANGES[:PATIENTS])
        data = @site_morioka.data
        data.each do |d|
          id = d['id']
          next if id < TARGET_MIN_ID

          # DEBUG
          p id

          row = google_sheets.find { |a| a['id'] == id.to_s }

          expect(d['id'].to_s).to eq row['id']
          expect(d['確定日']).to eq row['確定日']
          expect(d['発症日']).to eq Date.parse(row['発症日']).strftime '%Y/%m/%d' unless row['発症日'].blank?
          expect(d['無症状']).to eq row['無症状']
          expect(d['年代']).to eq row['年代']
          expect(d['性別']).to eq row['性別']
          expect(d['居住地']).to eq row['居住地']
          expect(d['入院日']).to eq Date.parse(row['入院日']).strftime '%Y/%m/%d' unless row['入院日'].blank?
          expect(d['url']).to eq row['url']
          # 1181 は接触歴ありだけど資料には何も書かない
          if id == 1181
            # 1181 は過去の事例との接触歴ありだけど公表資料には何も書かないので、
            # プログラム的に資料上では不明と判定されるが、GoogleSheetsとjson上では判明になっている。
            expect('判明').to eq find_data(id)['接触歴']
          else
            expect(d['接触歴']).to eq find_data(id)['接触歴']
          end
          # expect(d['職業']).to eq row['職業']
        end
      end
    end
  end
end

require 'csv'
require 'json'
require_relative '../spec_helper'
require_relative '../../lib/googlesheets'
require_relative '../../lib/settings'

describe 'PDF' do
  before :all do
    @tsv = CSV.read(File.join(__dir__,'../../tsv/pdf.tsv'), col_sep: "\t")[1..-1]
    @google_sheets = GoogleSheetsIwate.new.data(GoogleSheetsIwate::SHEET_RANGES[:PATIENTS])
  end

  describe 'google sheets から読み込んだデータに対しての検証' do
    it 'pdfから生成したtsvと比較する' do
      @tsv.each do |d|
        id = d[0].to_s
        p id
        next if id == ''
        google_sheet = @google_sheets.find { |a| a['id'] == id }

        expect(d[0].to_s).to eq google_sheet['id']
        # 盛岡市の場合はPDFファイルが分割されていないので、PDFからリリース日を確定できない
        expect(d[1].to_s).to eq google_sheet['リリース日'] unless d[7] == '盛岡市' || d[8] == '盛岡市'
        # 盛岡市の場合はPDFファイルが分割されていないので、PDFから確定日を確定できない
        expect(d[2].to_s).to eq google_sheet['確定日'] unless d[7] == '盛岡市' || d[8] == '盛岡市'
        expect(d[3].to_s).to eq google_sheet['発症日']
        expect(d[4].to_s).to eq google_sheet['無症状']
        expect(d[5].to_s).to eq google_sheet['年代']
        expect(d[6].to_s).to eq google_sheet['性別']
        # 3162の場合は居住地が県内なのでスキップする
        expect(d[7].to_s).to eq google_sheet['居住地'] unless id == '3162'
        expect(d[8].to_s).to eq google_sheet['滞在地']
        expect(d[9].to_s).to eq google_sheet['入院日']
        expect(d[10].to_s).to eq google_sheet['url']
        expect(d[11].to_s).to eq google_sheet['接触歴']
        # 3270,3379,3381は何で検出したのかPDFに書いてない
        expect(d[12].to_s).to eq google_sheet['陽性最終確定検査手法'] unless ['3270', '3379', '3381'].include? id
      end
    end
  end
end

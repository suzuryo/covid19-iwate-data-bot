# frozen_string_literal: true

require 'google/apis/sheets_v4'
require 'googleauth'
require 'googleauth/stores/file_token_store'

# GoogleSheetsIwate
class GoogleSheetsIwate
  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
  APPLICATION_NAME = 'iwate.stopcovid19.jp DATA JSON Converter'
  CREDENTIALS_PATH = File.join(__dir__, '../credentials.json')
  TOKEN_PATH = File.join(__dir__, '../token.yaml')
  SCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS_READONLY
  SPREADSHEET_ID = '1VjxD8YTwEngvkfYOLD-4JG1tA5AnzTlgnzDO1lkTlNc'

  SHEET_RANGES = {
    PATIENTS: 'output_patients',
    PATIENT_MUNICIPALITIES: 'output_patient_municipalities',
    POSITIVE_BY_DIAGNOSED: 'output_positive_by_diagnosed',
    POSITIVE_RATE: 'output_positive_rate',
    HOSPITALIZED_NUMBERS: 'output_hospitalized_numbers',
    NEWS: 'input_news',
    ALERT: 'input_alert',
    SELF_DISCLOSURES: 'input_self_disclosures'
  }.freeze

  def initialize
    # Initialize the API
    service = Google::Apis::SheetsV4::SheetsService.new
    service.client_options.application_name = APPLICATION_NAME
    service.authorization = authorize

    ######################################################################
    # Google Sheets から データを取得して Hash の Array にする
    ######################################################################
    @spreadsheet_batch_data = service.batch_get_spreadsheet_values(SPREADSHEET_ID, ranges: SHEET_RANGES.values)
  end

  def authorize
    client_id = Google::Auth::ClientId.from_file CREDENTIALS_PATH
    token_store = Google::Auth::Stores::FileTokenStore.new file: TOKEN_PATH
    authorizer = Google::Auth::UserAuthorizer.new client_id, SCOPE, token_store
    user_id = 'default'
    credentials = authorizer.get_credentials user_id
    if credentials.nil?
      url = authorizer.get_authorization_url base_url: OOB_URI
      puts 'Open the following URL in the browser and enter the ' \
         "resulting code after authorization:\n" + url
      code = gets
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: OOB_URI
      )
    end
    credentials
  end

  # ここまで Google Sheets API を使うための Quickstart テンプレ
  # https://developers.google.com/sheets/api/quickstart/ruby

  # 特定の RANGES 項目のデータを返す
  def data(pat)
    # シートの名前を受け取って、1行目をヘッダーとしてhashの配列を返す
    keys, *values = @spreadsheet_batch_data.value_ranges.find { |range| range.range.match /^#{pat}/ }.values
    values.map { |row| keys.zip(row).to_h }
  end
end

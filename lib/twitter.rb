# frozen_string_literal: true

module Tweet2Tsv
  # Twitter
  class Twitter
    def initialize(days)
      @tweets = []
      @days = days
      @user_id = USER_ID
      @now = Time.now
    end

    def user_tweets
      now = Time.now
      days_ago = now.days_ago(@days)
      start_time = Time.new(days_ago.year, days_ago.month, days_ago.day, 15, 0, 'JST').rfc3339
      end_time = now.rfc3339

      options = {
        method: 'get',
        headers: {
          'User-Agent' => 'v2RubyExampleCode',
          'Authorization' => "Bearer #{BEARER_TOKEN}"
        },
        params: {
          'max_results' => 100,
          'start_time' => start_time,
          'end_time' => end_time,
          'tweet.fields' => 'author_id,created_at,id'
        }
      }

      url = ENDPOINT_URL.gsub(':id', USER_ID.to_s)
      request = Typhoeus::Request.new(url, options)
      response = request.run
      # 自分の呟きだけをフィルタ

      JSON.parse(response.body)['data'].select { |d| d['author_id'] == USER_ID.to_s }
    end

    def data
      d = {
        main_summary: [],
        patients: []
      }

      # 日別に tweets{} にまとめる
      tweets = {}
      user_tweets.reverse.each do |line|
        created_at = Time.parse(line['created_at']).in_time_zone('Asia/Tokyo')
        ymd = created_at.strftime('%Y%m%d')
        tweets[ymd] = {
          created_at: created_at,
          text: tweets[ymd] ? tweets[ymd][:text] + line['text'] + "\n\n" : ''
        }
      end

      tweets.each do |ymd, line|
        # p line
        text = "#{line[:text].gsub(' ', '').gsub('　', '').gsub('年代：', '').gsub('性別：', '').gsub('居住地：', '').gsub('職業：', '')}\n"

        h = {}

        # main_summary
        h.merge! /\s(?<month>\d+)月(?<day>\d+)日[（(](?<曜日>[日月火水木金土])[)）]\s■実施報告[：:](?<実施報告>[\d,]+)件\s.*※うち検出[：:](?<実施報告うち検出>[\d,]+)件/.match(text)&.named_captures
        h.merge! /県PCR検査[：:](?<県PCR検査>[\d,]+)件/.match(text)&.named_captures
        h.merge! /民間等[：:](?<民間等>[\d,]+)件/.match(text)&.named_captures
        h.merge! /地域外来等[：:](?<地域外来等>[\d,]+)件/.match(text)&.named_captures
        h.merge! /抗原検査[：:](?<抗原検査>[\d,]+)件/.match(text)&.named_captures
        h.merge! /■累計[：:](?<累計>[\d,]+)件[（(]うち検出(?<累計う\sち検出>[\d,]+)件[)）]/.match(text)&.named_captures
        h.merge! /入院中(?<入院中>[\d,]+)名/.match(text)&.named_captures
        h.merge! /うち重症者(?<入院中うち重症者>[\d,]+)名/.match(text)&.named_captures
        h.merge! /宿泊療養(?<宿泊療養>[\d,]+)名/.match(text)&.named_captures
        h.merge! /退院等(?<退院等>[\d,]+)名/.match(text)&.named_captures
        h.merge! /死亡者(?<死亡者>[\d,]+)名/.match(text)&.named_captures
        h.merge! /調整中(?<調整中>[\d,]+)名/.match(text)&.named_captures
        h.merge!({ 'date' => Date.parse("2021/#{h['month']}/#{h['day']}") })
        d[:main_summary] << h

        # patients
        # 90歳以上 と 90歳\n以上 の2パターンある
        # ①xxx例目 と ①第xxx例目 の2パターンある
        pat1 = /
        【第*(?<例目>\d+?)例目】\s
        ①(?<年代>.+?)(?<年代a>\s|\s以上\s)
        ②(?<性別>.+?)\s
        ③(?<居住地>.+?)\s
        ④(?<職業>.+?)\s
      /x

        # ④の次の行が空行じゃなければ接触歴あり
        pat2 = /
        【第*(?<例目>\d+?)例目】\s
        ①(?<年代>.+?)(?<年代a>\s|\s以上\s)
        ②(?<性別>.+?)\s
        ③(?<居住地>.+?)\s
        ④(?<職業>.+?)\s
        (?<接触歴>\S+)\s
      /x

        patients1 = text.scan(pat1)
        patients2 = text.scan(pat2)

        if patients1
          patients1&.each do |patient|
            h = {}
            h['created_at'] = line[:created_at]
            h['id'] = patient[0].to_i
            h['年代'] = patient[1] == '90歳' ? '90歳以上' : patient[1] # 90歳以上 と 90歳\n以上 の2パターンある
            h['性別'] = patient[3].gsub(/^男$/, '男性').gsub(/^女$/, '女性')
            h['居住地'] = if /^県外/.match patient[4].split(/[(（]/)[0]
                         '県外'
                       else
                         patient[4].split(/[(（]/)[0].gsub('滞在地', '').gsub(/[:：]/, '')
                       end
            h['滞在地'] = if h['居住地'] === '県外'
                         patient[4].split(/滞在地/)[1].split(/[(（]/)[0].gsub('滞在地', '').gsub(/[:：]/, '').gsub(/[)）]/, '')
                       else
                         ''
                       end
            h['職業'] = patient[5]
            h['接触歴'] = '不明'
            d[:patients] << h
          end
        end

        next unless patients2

        patients2&.each do |patient|
          d[:patients].reject! { |item| item['id'] == patient[0].to_i }
          h = {}
          h['created_at'] = line[:created_at]
          h['id'] = patient[0].to_i
          h['年代'] = patient[1] == '90歳' ? '90歳以上' : patient[1] # 90歳以上 と 90歳\n以上 の2パターンある
          h['性別'] = patient[3].gsub(/^男$/, '男性').gsub(/^女$/, '女性')
          h['居住地'] = if /^県外/.match patient[4].split(/[(（]/)[0]
                       '県外'
                     else
                       patient[4].split(/[(（]/)[0].gsub('滞在地', '').gsub(/[:：]/, '')
                     end
          h['滞在地'] = if h['居住地'] === '県外'
                       patient[4].split(/滞在地/)[1].split(/[(（]/)[0].gsub('滞在地', '').gsub(/[:：]/, '').gsub(/[)）]/, '')
                     else
                       ''
                     end
          h['職業'] = patient[5]
          h['接触歴'] = '判明'
          d[:patients] << h
        end
      end
      d
    end
  end
end

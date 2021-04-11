module Tweet2Tsv
  class TwitterParser
    def initialize(days)
      @tweets = []
      @days = days
      @user_id = USER_ID
      @now = Time.now
    end

    def get_user_tweets
      now = Time.now
      days_ago = now.days_ago(@days)
      start_time = Time.new(days_ago.year, days_ago.month, days_ago.day, 15, 0, 'JST').rfc3339
      end_time = now.rfc3339

      options = {
        method: 'get',
        headers: {
          "User-Agent" => "v2RubyExampleCode",
          "Authorization" => "Bearer #{BEARER_TOKEN}",
        },
        params: {
          "max_results" => 100,
          "start_time" => start_time,
          "end_time" => end_time,
          "tweet.fields" => "author_id,created_at,id",
        }
      }

      url = ENDPOINT_URL.gsub(':id', USER_ID.to_s)
      request = Typhoeus::Request.new(url, options)
      response = request.run
      # 自分の呟きだけをフィルタ

      JSON.parse(response.body)['data'].select {|d| d['author_id'] == USER_ID.to_s}
    end

    def data
      d = {
        main_summary: [],
        patients: []
      }

      get_user_tweets.each do |line|
        text = line['text'].gsub(' ', '').gsub('　', '').gsub('年代：', '').gsub('性別：', '').gsub('居住地：', '').gsub('職業：', '') + "\n"
        created_at = Time.parse(line['created_at']).in_time_zone('Asia/Tokyo')

        # main_summary
        main_summary = /【検査報告】\s(?<month>\d+)月(?<day>\d+)日[（(](?<曜日>[日月火水木金土])[)）]\s/.match(text)
        if main_summary
          h = {}
          # 実施報告件数の場合
          h.merge! main_summary.named_captures
          h.merge! /■実施報告[：:](?<実施報告>\d+)件\s.*※うち検出[：:](?<実施報告うち検出>\d+)件\s/.match(text).named_captures
          h.merge! /■検査内訳\s・県PCR検査[：:](?<県PCR検査>\d+)件\s・民間等[：:](?<民間等>\d+)件\s・地域外来等[：:](?<地域外来等>\d+)件\s・抗原検査[：:](?<抗原検査>\d+)件/.match(text).named_captures
          h.merge! /■累計[：:](?<累計>[\d,]+)件[（(]うち検出(?<累計う\sち検出>\d+)件[)）]\s/.match(text).named_captures
          h.merge! /■患者等状況\s・入院中(?<入院中>\d+)名[（(]うち重症者(?<入院中うち重症者>\d+)名[)）]\s・宿泊療養(?<宿泊療養>\d+)名\s・退院等(?<退院等>\d+)名\s・死亡者(?<死亡者>\d+)名\s・調整中(?<調整中>\d+)名/.match(text).named_captures
          h.merge! ({'date' => Date.parse("2021/#{h['month']}/#{h['day']}")})
          d[:main_summary] << h
        end


        # patients
        pat1 = /
        【第(?<例目>\d+?)例目】\s
        ①(?<年代>.+?)\s
        ②(?<性別>.+?)\s
        ③(?<居住地>.+?)\s
        ④(?<職業>.+?)\s
      /x

        pat2 = /
        【第(?<例目>\d+?)例目】\s
        ①(?<年代>.+?)\s
        ②(?<性別>.+?)\s
        ③(?<居住地>.+?)\s
        ④(?<職業>.+?)\s
        [・※](?<接触歴>.+)\s
      /x

        patients1 = text.scan(pat1)
        patients2 = text.scan(pat2)

        if patients1
          patients1.each do |patient|
            h = {}
            h['created_at'] = created_at
            h['id'] = patient[0].to_i
            h['年代'] = patient[1]
            h['性別'] = patient[2]
            h['居住地'] = patient[3].split(/[(（]/)[0]
            h['職業'] = patient[4]
            h['接触歴'] = '不明'
            d[:patients] << h
          end
        end

        if patients2
          patients2.each do |patient|
            d[:patients].reject!{|item| item['id'] == patient[0].to_i }
            h = {}
            h['created_at'] = created_at
            h['id'] = patient[0].to_i
            h['年代'] = patient[1]
            h['性別'] = patient[2]
            h['居住地'] = patient[3].split(/[(（]/)[0]
            h['職業'] = patient[4]
            h['接触歴'] = '判明'
            d[:patients] << h
          end
        end
      end
      d
    end
  end
end


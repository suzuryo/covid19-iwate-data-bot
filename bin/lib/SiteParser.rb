module Site2Tsv
  class SiteParser
    def initialize(url_iwate: nil, url_morioka: nil, id: nil)
      @patients = []
      @url_iwate = url_iwate
      @url_morioka = url_morioka
      @id = id
    end

    def data
      @patients.concat from_iwate(Nokogiri::HTML(URI.parse(@url_iwate).open)).compact
      @patients.concat from_morioka(Nokogiri::HTML(URI.parse(@url_morioka).open)).compact
    end

    # 盛岡市のページをスクレイピング
    def from_morioka(base_doc)
      links = []

      # 指定id以降のデータが存在すればデータ取得の準備
      base_doc.css('#voice > ul > li > a').each do |link|
        links << link if link.text.match(/県内(?<id>\d+)例目/)[:id].to_i >= @id
      end

      links.map do |link|
        patient = {}

        # url
        url = URI.parse('http://www.city.morioka.iwate.jp/' + link.attribute('href').value.delete("\n").gsub('../../../../../', ''))

        # document
        doc = Nokogiri::HTML(url.open)

        # id
        ids = doc.css('#voice > h1').text.match(/(?<morioka_id>\d+)（県内(?<id>\d+)例目）/)
        patient[:id] = ids[:id].to_i
        patient[:morioka_id] = ids[:morioka_id].to_i

        # リリース日
        m = doc.css('#voice > div.box > p.update').text.match(/令和\d+年(?<month>\d+)月(?<day>\d+)日/)
        patient[:リリース日] = Date.parse("2021/#{m[:month]}/#{m[:day]}").strftime('%Y/%m/%d')

        # 確定日
        patient[:確定日] = Date.parse("2021/#{m[:month]}/#{m[:day]}").days_ago(1).strftime('%Y/%m/%d')

        doc.css('#voice > h4').each do |h4|
          patient[:接触歴] = '不明'
          case h4.text
          when /^症状：/
            if h4.text.match(/無症状病原体保有者/)
              # 無症状
              patient[:無症状] = '無症状'
            else
              # 有症状
              patient[:無症状] = ''
            end
          when /^発症日：/
            if patient[:無症状] == '無症状'
              patient[:発症日] = ''
            else
              m = h4.text.match(/(?<month>\d+)月(?<day>\d+)/)
              patient[:発症日] = m ? Date.parse("2021/#{m[:month]}/#{m[:day]}").strftime('%Y/%m/%d') : ''
            end
          when /^年代：/
            patient[:年代] = h4.text.gsub('年代：', '').strip
          when /^性別：/
            patient[:性別] = h4.text.gsub('性別：', '').strip
          when /^居住地：/
            patient[:居住地] = h4.text.gsub('居住地：', '').strip
            if patient[:居住地].match(/県外/)
              patient[:居住地] = '県外'
            end
          when /^入院状況：/
            m = h4.text.match(/(?<month>\d+)月(?<day>\d+)/)
            patient[:入院日] = m ? Date.parse("2021/#{m[:month]}/#{m[:day]}").strftime('%Y/%m/%d') : ''
          when /^その他/
            patient[:接触歴] = '判明'
          end
        end

        # url
        patient[:url] = url.to_s

        patient
      end
    end

    # 岩手県のページをスクレイピング
    def from_iwate(base_doc)
      links = []

      base_doc.css('#voice > table > tbody > tr > td:nth-child(1) a').each do |link|
        links << link if link.text.match(/第(?<id>\d+)例目/)[:id].to_i >= @id
      end

      links.map do |link|
        patient = {}

        # url
        url = URI.parse(link.attribute('href').value.delete("\n"))

        # document
        doc = Nokogiri::HTML(url.open)

        # id
        ids = doc.css('#voice > h2').text.match(/第(?<id>\d+)例目の患者に関する情報/)
        patient[:id] = ids[:id].to_i

        # リリース日
        m = doc.css('#voice > h2').text.match(/令和3年(?<month>\d+)月(?<day>\d+)日/)
        patient[:リリース日] = m ? Date.parse("2021/#{m[:month]}/#{m[:day]}").strftime('%Y/%m/%d') : ''

        # 確定日
        patient[:確定日] = m ? Date.parse("2021/#{m[:month]}/#{m[:day]}").days_ago(1).strftime('%Y/%m/%d') : ''

        # 無症状
        # 発症日
        mm = doc.css('#voice > dl > dd:nth-child(10)').text.match(/無症状病原体保有者/)
        if mm
          patient[:無症状] = '無症状'
          patient[:発症日] = ''
        else
          m = doc.css('#voice > dl > dd:nth-child(12)').text.match(/(?<month>\d+)月(?<day>\d+)/)
          patient[:無症状] = ''
          patient[:発症日] = m ? Date.parse("2021/#{m[:month]}/#{m[:day]}").strftime('%Y/%m/%d') : ''
        end

        # 年代
        patient[:年代] = doc.css('#voice > dl > dd:nth-child(2)').text.strip

        # 性別
        patient[:性別] = doc.css('#voice > dl > dd:nth-child(4)').text.strip

        # 居住地
        patient[:居住地] = doc.css('#voice > dl > dd:nth-child(6)').text.strip
        if patient[:居住地].match(/県外/)
          patient[:居住地] = '県外'
        end

        # 入院日
        m = doc.css('#voice > dl > dd:nth-child(14)').text.match(/(?<month>\d+)月(?<day>\d+)/)
        patient[:入院日] = m ? Date.parse("2021/#{m[:month]}/#{m[:day]}").strftime('%Y/%m/%d') : ''

        # url
        patient[:url] = url.to_s

        # 接触歴
        patient[:接触歴] = doc.css('#voice > dl > dd:nth-child(22)').text == 'なし' ? '不明' : '判明'

        patient[:morioka_id] = nil

        patient
      end
    end
  end

end

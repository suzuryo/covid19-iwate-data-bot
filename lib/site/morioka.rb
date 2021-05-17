# frozen_string_literal: true

# id > 414 に対応

require 'active_support/core_ext/date'
require 'nokogiri'
require 'open-uri'

# SiteIwate
class Morioka
  def initialize(url: nil, selector: nil, id: nil)
    @url = url
    @selector = selector
    @id = id
  end

  def data
    uris.map do |uri|
      parse(uri, doc(uri))
    end
  end

  def uris
    raise NotValidUrlError unless @url.morioka?

    html = URI.parse(@url).open if URI.parse(@url).instance_of?(URI::HTTP)

    Nokogiri::HTML(html).css(@selector).filter_map do |node|
      # 個別ページへのリンクから id を抽出
      m = /(?<morioka_id>\d+)（県内(?<id>\d+)例目）/.match node.text

      # マッチしたものだけを採用
      next unless m

      # 指定 id よりも多いものだけを採用
      next if m[:id].to_i < @id

      URI.parse("http://www.city.morioka.iwate.jp/#{node.attribute('href').value.delete("\n").gsub('../../../../../', '').rstrip}")
    end
  end

  def doc(uri)
    raise NotValidUrlError unless uri.to_s.morioka?

    Nokogiri::HTML(uri.open)
  end

  def parse(uri, doc)
    p uri
    patient = {}

    # id
    ids = doc.css('#voice > h1').text.match(/(?<morioka_id>\d+)（県内(?<id>\d+)例目）/)
    patient['id'] = ids[:id].to_i
    patient['morioka_id'] = ids[:morioka_id].to_i

    # リリース日
    m = doc.css('#voice > div.box > p.update').text.match(/令和\d+年(?<month>\d+)月(?<day>\d+)日/)
    patient['リリース日'] = m ? Date.parse("2021/#{m[:month]}/#{m[:day]}").strftime('%Y/%m/%d') : ''

    # 確定日
    patient['確定日'] = m ? Date.parse("2021/#{m[:month]}/#{m[:day]}").days_ago(1).strftime('%Y/%m/%d') : ''

    # h4
    doc.css('#voice > h4').each do |h4|
      patient['接触歴'] = '不明'
      case h4.text
      when /^症状：/
        patient['無症状'] = if h4.text.match(/無症状病原体保有者/)
                           '無症状'
                         else
                           ''
                         end
      when /^発症日：/
        if patient['無症状'] == '無症状'
          patient['発症日'] = ''
        else
          m = h4.text.match(/(?<month>\d+)月(?<day>\d+)/)
          patient['発症日'] = m ? Date.parse("2021/#{m[:month]}/#{m[:day]}").strftime('%Y/%m/%d') : ''
        end
      when /^年代：/
        patient['年代'] = h4.text.gsub('年代：', '').strip
      when /^性別：/
        patient['性別'] = h4.text.gsub('性別：', '').strip
      when /^居住地：/
        patient['居住地'] = h4.text.gsub('居住地：', '').strip
        patient['居住地'] = '県外' if patient['居住地'].match(/県外/)
      when /^入院状況：/
        m = h4.text.match(/(?<month>\d+)月(?<day>\d+)/)
        patient['入院日'] = m ? Date.parse("2021/#{m[:month]}/#{m[:day]}").strftime('%Y/%m/%d') : ''
      when /^その他/
        h4_next_element = h4.next_element.text
        patient['接触歴'] = if /よりよいウェブサイトにするために/.match(h4_next_element) || h4_next_element.blank?
                           '不明'
                         else
                           '判明'
                         end
      end

      # 1181 は過去の事例との接触歴ありと口頭説明されたけど、公表資料には何も書かないということなので、 判明に固定する
      patient['接触歴'] = '判明' if patient['id'] == 1181
    end

    # url
    patient['url'] = uri.to_s

    patient
  end
end

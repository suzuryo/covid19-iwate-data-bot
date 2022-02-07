#!/usr/bin/env ruby
# frozen_string_literal: true

require 'active_support/all'
require 'dotenv/load'
require 'json'
require 'rtesseract'
require 'thor'

module Image2Tsv
  VERSION = '0.1.0'
  BEARER_TOKEN = ENV['TWITTER_BEARER_TOKEN']

  # TweetImage2Tsv CLI
  class Cli < Thor
    check_unknown_options!
    include Thor::Actions

    default_command :new

    def self.exit_on_failure?
      true
    end

    def self.source_root
      File.join(__dir__, '../template/')
    end

    desc 'version', 'Display Iwate Covid19 Image2Tsv version'
    map %w[-v --version] => :version

    class_option 'verbose', type: :boolean, default: false

    def version
      say "Image2Tsv #{VERSION}"
    end

    desc 'new', 'Create a new image.tsv'
    def new

      tsv = ''

      Dir.glob('input/images/*.jpg').each do |file|
        image = RTesseract.new(file, lang: 'jpn')
        text = image.to_s.gsub('|', '')

        text.split(/\n/).each do |a|
          row = a.gsub(' ', '')
          next if row.blank?

          r = /^(?<no>\d\d\d\d)(?<age>10歳未満|10代|20代|30代|40代|50代|60代|70代|80代|90歳以上)(?<sex>男性|女性)(?<city>.+市|.+町|.+管内)/.match(row)
          pp r
          tsv += if r.nil?
                   "\n"
                 else
            "#{r['no']}\t\t\t\t\t#{r['age']}\t#{r['sex']}\t#{r['city']}\n"
                 end
        end
      end

      File.write(File.join(__dir__, '../tsv/', 'images.tsv'), tsv)
    end
  end
end

Image2Tsv::Cli.start

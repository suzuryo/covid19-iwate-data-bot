#!/usr/bin/env ruby
# frozen_string_literal: true

def confirmed_case_area_age_json(positive_rate, patients, now)
  area_json = {
    date: now.iso8601,
    data: []
  }

  age_json = {
    date: now.iso8601,
    data: []
  }

  positive_rate.map { |a| a['diagnosed_date'] }.each do |diagnosed_date|
    end_date = Date.parse(diagnosed_date)
    start_date = end_date.days_ago(6)
    date_range = start_date..end_date

    _patients = patients.select do |patient|
      date_range.cover? Date.parse(patient['確定日'])
    end

    r_area = Ractor.new name: 'area' do
      __patients, __end_date = Ractor.receive
      area_sum = __patients.each_with_object(AREAS.to_h { |a| [a, 0] }) do |patient, hash|
        area = patient['滞在地'].blank? ? findArea(patient['居住地']) : findArea(patient['滞在地'])
        hash[area] += 1 unless hash[area].nil?
      end
      {
        date: __end_date.strftime('%Y-%m-%d'),
        data: area_sum.to_h { |key, val| [key.to_s.gsub('保健所管内', ''), (val / 7.0).round(1)] }
      }
    end

    r_age = Ractor.new name: 'age' do
      __patients, __end_date = Ractor.receive
      age_sum = __patients.each_with_object(AGES.to_h { |a| [a, 0] }) do |patient, hash|
        age = patient['年代']
        hash[age] += 1 unless hash[age].nil?
      end
      {
        date: __end_date.strftime('%Y-%m-%d'),
        data: age_sum.to_h { |key, val| [key, (val / 7.0).round(1)] }
      }
    end

    r_area.send [_patients, end_date]
    r_age.send [_patients, end_date]
    area_json[:data].append r_area.take
    age_json[:data].append r_age.take
  end

  File.write(File.join(__dir__, '../../data/', 'confirmed_case_area.json'), JSON.pretty_generate(area_json))
  File.write(File.join(__dir__, '../../data/', 'confirmed_case_age.json'), JSON.pretty_generate(age_json))
end

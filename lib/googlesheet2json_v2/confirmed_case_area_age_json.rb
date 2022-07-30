#!/usr/bin/env ruby
# frozen_string_literal: true

def confirmed_case_area_age_json(patients_summary, hospitalized_numbers, now)
  patients_data = JSON.parse(File.read(File.join(__dir__, '../../data_archived/data.json')))['patients']['data']

  area_json = {
    date: now.iso8601,
    data: []
  }

  age_json = {
    date: now.iso8601,
    data: []
  }

  date_range = hospitalized_numbers.slice(0..-1).map { |a| a['date'] }

  date_range.each_with_index do |date, index|
    # next if index < 890

    end_date = Date.parse(date)
    start_date = end_date.days_ago(6)
    date_range = start_date..end_date

    archived_patients_data = patients_data.select do |patient|
      date_range.cover? Date.parse(patient['確定日'])
    end

    patients_summary_data = patients_summary.select do |patient|
      date_range.cover? Date.parse(patient['date'])
    end

    r_area = Ractor.new name: 'area' do
      apd, psd, ed = Ractor.receive
      area_sum = apd.each_with_object(AREAS.to_h { |a| [a, 0] }) do |patient, hash|
        area = patient['滞在地'].blank? ? findArea(patient['居住地']) : findArea(patient['滞在地'])
        hash[area] += 1 unless hash[area].nil?
      end

      psd.each do |row|
        row.each do |r|
          area_sum[findArea(r[0])] += r[1].to_i if findArea(r[0])
        end
      end

      {
        date: ed.strftime('%Y-%m-%d'),
        data: area_sum.to_h { |key, val| [key.to_s.gsub('保健所管内', ''), (val / 7.0).round(1)] }
      }
    end

    r_age = Ractor.new name: 'age' do
      apd, psd, ed = Ractor.receive
      age_sum = apd.each_with_object(AGES.to_h { |a| [a, 0] }) do |patient, hash|
        age = patient['年代']
        hash[age] += 1 unless hash[age].nil?
      end

      psd.each do |row|
        row.each do |r|
          age_sum[r[0]] += r[1].to_i if AGES.include?(r[0])
        end
      end

      {
        date: ed.strftime('%Y-%m-%d'),
        data: age_sum.to_h { |key, val| [key, (val / 7.0).round(1)] }
      }
    end

    r_area.send [archived_patients_data, patients_summary_data, end_date]
    r_age.send [archived_patients_data, patients_summary_data, end_date]
    area_json[:data].append r_area.take
    age_json[:data].append r_age.take
  end

  File.write(File.join(__dir__, '../../data/', 'confirmed_case_area.json'), JSON.pretty_generate(area_json))
  File.write(File.join(__dir__, '../../data/', 'confirmed_case_age.json'), JSON.pretty_generate(age_json))
end

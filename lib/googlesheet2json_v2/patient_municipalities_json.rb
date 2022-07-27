#!/usr/bin/env ruby
# frozen_string_literal: true

def patient_municipalities_json(patient_municipalities, now)
  json = {
    date: now.iso8601,
    datasets: {
      date: now.iso8601,
      data: []
    }
  }

  patient_municipalities.each do |row|
    json[:datasets][:data].append(
      {
        code: row['code'],
        area: row['area'],
        label: row['label'],
        ruby: row['ruby'],
        count: row['count'].to_i,
        count_per_population: row['count_per_population']
      }
    )
  end

  File.write(File.join(__dir__, '../../data/', 'patient_municipalities.json'), JSON.pretty_generate(json))
end



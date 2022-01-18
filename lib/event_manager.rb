# frozen-string-literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phonenumber(phone)
  phone = phone.tr('^0-9', '')

  if phone.length < 10 || phone.length > 11
    'Invalid phone.'
  elsif phone.length == 11
    phone[0] == 1 ? phone.slice(1, -1) : 'Invalid phone.'
  else
    phone
  end
end

def registration_hour(registration_date)
  Time.strptime(registration_date, '%m/%d/%y %H:%M').hour
end

def registration_day(registration_date)
  Date.strptime(registration_date, '%m/%d/%y').wday
end

def peak_hours(hours_count)
  (hours_count.sort_by { |_, count| count })
    .reverse
    .take(3)
    .map { |hour, _| hour }
end

def peak_wdays(days_count)
  (days_count.sort_by { |_, count| count })
    .reverse
    .take(3)
    .map { |day, _| Date::DAYNAMES[day] }
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip, levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'Event Manager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

hours_count = Hash.new(0)
days_count = Hash.new(0)

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)
  phone = clean_phonenumber(row[:homephone])

  hours_count[registration_hour(row[:regdate])] += 1
  days_count[registration_day(row[:regdate])] += 1

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

p peak_hours(hours_count)
p peak_wdays(days_count)

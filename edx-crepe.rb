require "net/http"
require "json"
require "csv"

class CourseImporter
  EDX_ENDPOINT = URI("https://www.edx.org/search/api/all").freeze

  attr_accessor :courses

  def initialize
    self.courses = import_courses
  end

  private

  def import_courses
    JSON.parse Net::HTTP.get(EDX_ENDPOINT)
  end
end

class CSVGenerator
  EDX_ROOT_URL = "https://www.edx.org".freeze

  attr_accessor :records

  def initialize(records)
    self.records = records
  end

  def generate_csv
    CSV.open("./csvs/#{Time.now.to_i}.csv", "w") do |csv|
      csv << row_headers(records.first.keys)

      records.each do |r|
        csv << transform_row(r.values) if in_english?(r)
      end
    end
  end

  private

  def row_headers(headers)
    headers.map do |h|
      case h
      when "l"
        "course_name"
      when "staff-nids"
        "staff_ids"
      when "image"
        "image_url"
      else
        h
      end
    end
  end

  def transform_row(row)
    row.map do |r|
      if r.is_a? Array
        transform_array(r)
      elsif r.is_a? Hash
        transform_image_url(r)
      elsif r.is_a?(Fixnum) && r > 1000000000 # hacky, should work until edx has more than a billion courses
        transform_time(r)
      else
        r
      end
    end
  end

  def transform_array(arr)
    arr.map! { |i| "\"#{i}\"" } if arr.all? { |i| i.is_a? Fixnum }
    arr.join(",")
  end

  def transform_image_url(r)
    EDX_ROOT_URL + r["src"]
  end

  def transform_time(r)
    Time.at(r).strftime("%B %-d, %-Y")
  end

  def in_english?(record)
    record["languages"].map(&:downcase).include?("english")
  end
end

class CSVPivotGenerator < CSVGenerator
  PIVOT_HEADERS = %w(course_name schools level start availability subjects types).freeze
  PIVOT_COLUMNS = %w(l schools level start availability subjects types).freeze

  def generate_csv
    CSV.open("./csvs/#{Time.now.to_i}_pivot.csv", "w") do |csv|
      csv << selected_row_headers(records.first.keys)

      records.each do |r|
        r["subjects"].each { |s| csv << transform_pivot_row(r, s) } if in_english?(r)
      end
    end
  end

  private

  def selected_row_headers(headers)
    row_headers(headers).select { |h| PIVOT_HEADERS.include?(h) }
  end

  def transform_pivot_row(row, subject)
    row.merge!("subjects" => subject)

    PIVOT_COLUMNS.map { |c| Array(row[c]).join(",") }
  end
end

puts "BEGIN BY COMBINING FLOUR, MILK, EGGS AND SUGAR WITH A PINCH OF SALT"
c = CourseImporter.new

puts "BLEND UNTIL SMOOTH"
csv = CSVGenerator.new(c.courses)
puts "REST FOR 30 MINUTES AT ROOM TEMPERATURE"
pivot_csv = CSVPivotGenerator.new(c.courses)

puts "BUTTER A PAN AND FRY THE MIXTURE IN BATCHES UNTIL EACH CREPE IS LIGHTLY GOLDEN"
csv.generate_csv
puts "TRANSFER TO A PLATE AND COVER WITH FOIL UNTIL THE LAST CREPE IS COMPLETE"
pivot_csv.generate_csv
puts "YOUR CREPES ARE READY TO ENJOY"

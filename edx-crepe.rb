require "net/http"
require "json"
require "csv"

class CourseImporter
  EDX_ROOT_URL = "https://www.edx.org".freeze
  EDX_ENDPOINT = URI("#{EDX_ROOT_URL}/search/api/all").freeze

  attr_accessor :courses

  def initialize
    self.courses = import_courses
  end

  def import_courses
    JSON.parse Net::HTTP.get(EDX_ENDPOINT)
  end

  def generate_csv
    CSV.open("./csvs/#{Time.now.to_i}.csv", "w") do |csv|
      csv << row_headers(courses.first.keys)
      courses.each { |c| csv << transform_row(c.values) }
    end
  end

  # minor transformations to make headers more intelligible
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

  # transform row output to more convenient types
  def transform_row(row)
    row.map do |r|
      if r.is_a? Array
        transform_array(r)
      elsif r.is_a? Hash
        EDX_ROOT_URL + r["src"]
      elsif r.is_a?(Fixnum) && r > 1000000000 # hacky, this will be a time
        Time.at(r).strftime('%B %-d, %-Y')
      else
        r
      end
    end
  end

  def transform_array(arr)
    arr.map! { |i| "\"#{i}\"" } if arr.all? { |i| i.is_a? Fixnum }
    arr.join(",")
  end
end

c = CourseImporter.new
c.generate_csv

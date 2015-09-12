require 'dns/zone'
require 'csv'

wide_ip_list                 = File.read('wide-ip.txt').split
wide_ip_with_trailing_dot    = wide_ip_list.map { |x| x + '.' }
output_filename              = "output.csv"
output_file                  = File.open(output_filename, "w")
zone_file_progress           = 1
number_of_zone_files         = Dir['zone-files/*'].length

output = {}
# wide_ip.each { |wide_ip| output[wide_ip] = [] }

# Clean characters from the zonefile which break the DNS parser: '\' and '('. First discovered in barcapint.com
def clean(filename)
  file_contents = File.read(filename)
  new_contents  = file_contents.gsub('\(', "")

  File.open(filename, "w") { |file| file.puts new_contents }
end

output_file.puts "Wide IP,Alias Count,Alias Source,Alias Domain Source"

Dir['zone-files/*'].each do |filename|
  puts "#{zone_file_progress} of " + number_of_zone_files.to_s  + " - " + File.basename(filename)
  clean(filename)
  wide_ip_without_domain = wide_ip_list.map { |x| x.gsub('.' + File.basename(filename), "") }
  file = File.read(filename)
  zone = DNS::Zone.load(file)

  zone.records.each do |record|
    if record.is_a?(DNS::Zone::RR::CNAME) && (wide_ip_list.include?(record.domainname) || wide_ip_with_trailing_dot.include?(record.domainname))
      wide_ip        = record.domainname.gsub(/\.$/, '')
      if output[wide_ip].nil?
        output_array = wide_ip, record.label, zone.records[0].label
      else
        output_array = output[wide_ip]
        output_array << record.label << zone.records[0].label
      end
      output[wide_ip] = output_array
    elsif record.is_a?(DNS::Zone::RR::CNAME) && wide_ip_without_domain.include?(record.domainname)
      wide_ip        = record.domainname + '.' + zone.records[0].label
      if output[wide_ip].nil?
        output_array = wide_ip, record.label, zone.records[0].label
      else
        output_array = output[wide_ip]
        output_array << record.label << zone.records[0].label
      end
      output[wide_ip] = output_array
    end
  end
  zone_file_progress += 1
end

output.each_pair do |key, value|
  alias_count = value.count / 2 if value.count > 0
  value.insert(1, alias_count)
  output_file.puts value.to_csv
end
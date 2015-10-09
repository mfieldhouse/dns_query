require 'dns/zone'
require 'csv'

start_time = Time.now

ip_addresses = File.read("../input/ip-addresses.txt").split
found_fqdn = []
output = {}
output_filename = "../output/output.csv"
output_file = File.open(output_filename, "w")
output_file.puts "VIP IP,Short A Name,A Name Domain,Fully-Qualified A Name,Short Alias Name,Alias Domain,Fully-Qualified Alias Name\n"

# Set variables for search progress counters
number_of_ip_addresses = ip_addresses.length
number_of_zone_files = Dir['../input/zone-files/*'].length
puts "Number of IP addresses: " + number_of_ip_addresses.to_s
puts "Number of zone files: " + number_of_zone_files.to_s
zone_file_progress = 1

puts "-----"
puts "Searching for A records"

# Search for A records
Dir['../input/zone-files/*'].each do |filename|
  puts "#{zone_file_progress} of " + number_of_zone_files.to_s  + " - " + File.basename(filename)

  file = File.read(filename)
  zone = DNS::Zone.load(file)

  zone.records.each do |record|
    output_array = []

    if record.is_a?(DNS::Zone::RR::A) and ip_addresses.include?(record.address)
      ip        = record.address
      a_name    = record.label
      zone_name = zone.records[0].label
      fqdn      = a_name + '.' + zone_name
      found_fqdn << fqdn
      output_array << record.address << a_name << zone_name << fqdn
      output[a_name] = output_array
    end
  end
  zone_file_progress += 1
end

# Reset the progress counter ready for CNAME search
zone_file_progress = 1

puts "-----"
puts "Searching for CNAMEs"

# Create an array from the found FQDNs which contains only the host part of the domain
found_hosts = found_fqdn.map { |x| x.split('.')[0] }

# Search for CNAMEs
Dir['../input/zone-files/*'].each do |filename|
  puts "#{zone_file_progress} of " + number_of_zone_files.to_s  + " - " + File.basename(filename)

  file = File.read(filename)
  zone = DNS::Zone.load(file)

  zone.records.each do |record|

    # if 'The record is a CNAME and the domain part matches a found host or a found FQDN with or without the trailing dot'

    if record.is_a?(DNS::Zone::RR::CNAME) and found_hosts.include?(record.domainname) || found_fqdn.include?(record.domainname[0,record.domainname.length - 1])
      alias_name = record.label
      zone_name = zone.records[0].label
      host = record.domainname.split('.')[0]
      fqdn = alias_name + '.' + zone_name
      output_array = output[host]
      output_array << alias_name << zone_name << fqdn
      output[host] = output_array
    end
  end
  zone_file_progress += 1
end

output.each_pair do |key, value|
  output_file.puts value.to_csv
end

puts "Done! All results output to #{output_filename}"

end_time = Time.now
time_taken = end_time - start_time
puts "Time taken: #{time_taken.round(2)} seconds"
#!/usr/bin/ruby

require 'ipaddr'
require 'json'
require 'set'
require 'yaml'

def walk(value, &block)
  yield value
  case value
  when Hash
    value.each_value { |child| walk(child, &block) }
  when Array
    value.each { |child| walk(child, &block) }
  end
end

def blocking_rule?(expr)
  blocked = false
  walk(expr) do |value|
    next unless value.is_a?(Hash)

    blocked = true if value.key?('drop') || value.key?('reject')
    target = value.dig('jump', 'target') || value.dig('goto', 'target')
    blocked = true if target == '_reject'
  end
  blocked
end

def referenced_sets(expr)
  result = Set.new
  walk(expr) do |value|
    next unless value.is_a?(String) && value.start_with?('@')

    result << value.delete_prefix('@')
  end
  result
end

def range_to_cidrs(first_value, last_value)
  first_ip = IPAddr.new(first_value)
  last_ip = IPAddr.new(last_value)
  bits = first_ip.ipv4? ? 32 : 128
  current = first_ip.to_i
  finish = last_ip.to_i
  result = []

  while current <= finish
    alignment = current.zero? ? (1 << bits) : (current & -current)
    remaining = finish - current + 1
    block = alignment
    block >>= 1 while block > remaining
    prefix = bits - (block.bit_length - 1)
    result << "#{IPAddr.new(current, first_ip.family)}/#{prefix}"
    current += block
  end
  result
rescue IPAddr::InvalidAddressError
  []
end

def element_values(value)
  case value
  when String
    [value]
  when Array
    value.flat_map { |item| element_values(item) }
  when Hash
    if value.key?('prefix')
      prefix = value['prefix']
      ["#{prefix['addr']}/#{prefix['len']}"]
    elsif value.key?('range')
      range_to_cidrs(*value['range'])
    elsif value.key?('elem')
      element_values(value['elem'])
    elsif value.key?('val')
      element_values(value['val'])
    else
      []
    end
  else
    []
  end
end

def clash_ip_rule(value)
  ip_text = value.to_s
  ip = IPAddr.new(ip_text)
  ip_text = "#{ip_text}/#{ip.ipv4? ? 32 : 128}" unless ip_text.include?('/')
  "#{ip.ipv4? ? 'IP-CIDR' : 'IP-CIDR6'},#{ip_text},no-resolve"
rescue IPAddr::InvalidAddressError
  nil
end

table = JSON.parse($stdin.read)
objects = table.fetch('nftables', [])
blocked_sets = Set.new

objects.each do |entry|
  rule = entry['rule']
  next unless rule && rule['chain'] == '_outbound'
  next unless blocking_rule?(rule['expr'])

  blocked_sets.merge(referenced_sets(rule['expr']))
end

set_types = {}
objects.each do |entry|
  set = entry['set']
  set_types[set['name']] = set['type'].to_s if set
end

rules = Set.new
objects.each do |entry|
  set = entry['set']
  if set && blocked_sets.include?(set['name']) && !set['type'].to_s.include?('.')
    element_values(set['elem']).each do |value|
      rule = clash_ip_rule(value)
      rules << rule if rule
    end
  end

  element = entry['element']
  next unless element && blocked_sets.include?(element['name'])
  next if set_types[element['name']].include?('.')

  element_values(element['elem']).each do |value|
    rule = clash_ip_rule(value)
    rules << rule if rule
  end
end

blocklist = ARGV[0]
if blocklist && File.file?(blocklist)
  File.foreach(blocklist) do |line|
    value = line.sub(/\s+#.*$/, '').strip.downcase
    next if value.empty?
    next unless value.match?(/\A(?:[a-z0-9_-]{1,63}\.)+[a-z]{2,}\z/)

    rules << "DOMAIN-SUFFIX,#{value}"
  end
end

puts({ 'payload' => rules.sort }.to_yaml)

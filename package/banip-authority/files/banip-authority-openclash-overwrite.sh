#!/bin/sh

config_file="$1"
provider_file="/etc/openclash/rule_provider/banip-authority.yaml"

[ -s "$config_file" ] || exit 0
[ -s "$provider_file" ] || exit 0

ruby -ryaml -e '
config_file, provider_file = ARGV
value = YAML.load_file(config_file)
exit 0 unless value.is_a?(Hash)

provider_name = "banip-authority"
provider_rule = "RULE-SET,#{provider_name},REJECT"
value["rule-providers"] = {} unless value["rule-providers"].is_a?(Hash)
value["rule-providers"][provider_name] = {
  "type" => "file",
  "behavior" => "classical",
  "format" => "yaml",
  "path" => provider_file
}
value["rules"] = [] unless value["rules"].is_a?(Array)
value["rules"].delete(provider_rule)
value["rules"].unshift(provider_rule)

tmp_file = "#{config_file}.banip-authority.#{$$}"
File.open(tmp_file, "w") { |file| file.write(YAML.dump(value)) }
File.rename(tmp_file, config_file)
' "$config_file" "$provider_file"

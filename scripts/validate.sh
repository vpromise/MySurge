#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
repo_root=${script_dir:h}
manifest_file="$repo_root/manifest.json"
surge_cli=${SURGE_CLI:-/Applications/Surge.app/Contents/Applications/surge-cli}
validation_tmp=$(mktemp -d /tmp/mysurge-validate.XXXXXX)
combined_file="$validation_tmp/combined.conf"

if [[ ! -x "$surge_cli" ]]; then
  print -u2 "Surge checker not found: $surge_cli"
  exit 1
fi

jq -e '
  .schema == 1
  and (.modules | length == 17)
  and ([.modules[].id] | length == (unique | length))
  and ([.modules[].order] == ([.modules[].order] | sort))
' "$manifest_file" >/dev/null

: > "$combined_file"

while IFS=$'\t' read -r module_id module_url local_path; do
  module_file="$validation_tmp/$module_id.sgmodule"

  if [[ -n "$local_path" ]]; then
    cp "$repo_root/$local_path" "$module_file"
    module_source="local"
  else
    http_meta=$(curl --globoff -L --fail --silent --show-error \
      --max-time 30 \
      --output "$module_file" \
      --write-out '%{http_code} %{content_type}' \
      "$module_url")
    module_source="$http_meta"
  fi

  check_file="$validation_tmp/check-$module_id.conf"
  sed '/^#!/d' "$module_file" > "$check_file"
  print '\n[Rule]\nFINAL,DIRECT' >> "$check_file"
  "$surge_cli" --check "$check_file" >/dev/null

  sed '/^#!/d' "$module_file" >> "$combined_file"
  print >> "$combined_file"

  module_sha=$(shasum -a 256 "$module_file" | awk '{print $1}')
  module_bytes=$(wc -c < "$module_file" | tr -d ' ')
  printf '%-20s %-30s %8s bytes  %s\n' \
    "$module_id" "$module_source" "$module_bytes" "$module_sha"
done < <(jq -r '.modules[] | [.id, .url, (.localPath // "")] | @tsv' "$manifest_file")

print '\n[Rule]\nFINAL,DIRECT' >> "$combined_file"
"$surge_cli" --check "$combined_file" >/dev/null

rule_meta=$(curl -L --fail --silent --show-error \
  --max-time 30 \
  --output "$validation_tmp/AdvertisingLite.list" \
  --write-out '%{http_code} %{content_type}' \
  'https://yfamilys.com/rule/AdvertisingLite.list')

if ! rg -q '^(DOMAIN|IP-CIDR|URL-REGEX|AND),' "$validation_tmp/AdvertisingLite.list"; then
  print -u2 "AdvertisingLite.list does not look like a Surge rule set"
  exit 1
fi

if rg -n -i \
  '(^|[^[:alpha:]])(passphrase|p12|private-key|proxy-auth|password|bearer[[:space:]]+)[[:space:]]*=' \
  "$repo_root" \
  -g '!scripts/validate.sh' \
  -g '!.git/**'; then
  print -u2 "Potential secret material found in repository"
  exit 1
fi

printf '\nCombined profile: OK\n'
printf 'AdvertisingLite.list: %s, %s bytes\n' \
  "$rule_meta" "$(wc -c < "$validation_tmp/AdvertisingLite.list" | tr -d ' ')"
printf 'Validation artifacts: %s\n' "$validation_tmp"

#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
repo_root=${script_dir:h}
manifest_file="$repo_root/manifest.json"
ci_tmp=$(mktemp -d /tmp/mysurge-ci-validate.XXXXXX)
module_count=$(jq '.modules | length' "$manifest_file")
upstream_count=$(jq '[.modules[] | select(.upstreamUrl != null)] | length' "$manifest_file")
fallback_hosts=${MYSURGE_CI_FALLBACK_HOSTS:-}
fallback_hosts=${fallback_hosts// /}

function is_fallback_url() {
  local url_without_scheme=${1#*://}
  local url_host=${url_without_scheme%%/*}
  [[ ",${fallback_hosts:l}," == *",${url_host:l},"* ]]
}

for required_tool in curl git grep jq perl shasum; do
  if ! command -v "$required_tool" >/dev/null 2>&1; then
    print -u2 "Required tool not found: $required_tool"
    exit 1
  fi
done

jq -e '
  .schema == 1
  and (.modules | length > 0)
  and ([.modules[].id] | length == (unique | length))
  and ([.modules[].localPath] | length == (unique | length))
  and ([.modules[].url] | length == (unique | length))
  and ([.modules[].order] == [range(1; (.modules | length) + 1)])
  and (all(.modules[];
    (.localPath | startswith("modules/") and endswith(".sgmodule"))
    and (.url == ("https://raw.githubusercontent.com/vpromise/MySurge/main/" + .localPath))
  ))
' "$manifest_file" >/dev/null

while IFS=$'\t' read -r module_id local_path; do
  module_file="$repo_root/$local_path"

  if [[ ! -s "$module_file" ]]; then
    print -u2 "Missing or empty module: $module_id ($local_path)"
    exit 1
  fi

  category_count=$(grep -c '^#!category=vpromise$' "$module_file" || true)
  name_count=$(grep -c '^#!name[[:space:]]*=' "$module_file" || true)

  if [[ "$category_count" != 1 || "$name_count" != 1 ]]; then
    print -u2 "Invalid module metadata: $module_id (name=$name_count, category=$category_count)"
    exit 1
  fi

  if grep -Eqi '<!doctype|<html([[:space:]>])' "$module_file"; then
    print -u2 "Module looks like an HTML error page: $module_id"
    exit 1
  fi

  if ! grep -Eq '^\[[^]]+\]$' "$module_file"; then
    print -u2 "Module has no Surge section: $module_id"
    exit 1
  fi
done < <(jq -r '.modules[] | [.id, .localPath] | @tsv' "$manifest_file")

awk '
  /<script id="module-data" type="application\/json">/ { capture = 1; next }
  capture && /<\/script>/ { exit }
  capture { print }
' "$repo_root/index.html" > "$ci_tmp/index-modules.json"

jq -S '[.modules[] | {id, name, emoji, category, source, url, order}]' \
  "$manifest_file" > "$ci_tmp/manifest-public.json"
jq -S '.' "$ci_tmp/index-modules.json" > "$ci_tmp/index-public.json"

if ! cmp -s "$ci_tmp/manifest-public.json" "$ci_tmp/index-public.json"; then
  print -u2 'The module list embedded in index.html differs from manifest.json'
  diff -u "$ci_tmp/manifest-public.json" "$ci_tmp/index-public.json" || true
  exit 1
fi

if [[ $(awk '!/^#/ && NF {n++} END{print n+0}' "$repo_root/sources.lock") != "$upstream_count" ]]; then
  print -u2 "sources.lock must contain $upstream_count upstream snapshots"
  exit 1
fi

jq -r '.modules[] | select(.upstreamUrl != null) | .id' "$manifest_file" | sort \
  > "$ci_tmp/manifest-upstream-ids"
awk -F $'\t' '!/^#/ && NF {print $1}' "$repo_root/sources.lock" | sort \
  > "$ci_tmp/locked-upstream-ids"

if ! cmp -s "$ci_tmp/manifest-upstream-ids" "$ci_tmp/locked-upstream-ids"; then
  print -u2 'sources.lock IDs differ from manifest.json upstream IDs'
  exit 1
fi

fallback_upstream_count=0
while IFS=$'\t' read -r module_id upstream_url local_path; do
  upstream_file="$ci_tmp/$module_id.upstream"
  upstream_normalized="$ci_tmp/$module_id.upstream.normalized"
  local_normalized="$ci_tmp/$module_id.local.normalized"
  locked_sha=$(awk -F $'\t' -v id="$module_id" '$1 == id {print $2}' "$repo_root/sources.lock")
  locked_url=$(awk -F $'\t' -v id="$module_id" '$1 == id {print $3}' "$repo_root/sources.lock")

  if ! curl --globoff -L --fail --silent --show-error \
    --retry 2 \
    --user-agent 'Surge iOS/6.0' \
    --max-time 30 \
    --output "$upstream_file" \
    "$upstream_url"; then
    if ! is_fallback_url "$upstream_url"; then
      exit 1
    fi

    if [[ ! "$locked_sha" =~ '^[0-9a-f]{64}$' || "$locked_url" != "$upstream_url" ]]; then
      print -u2 "Invalid locked fallback snapshot: $module_id"
      exit 1
    fi

    fallback_upstream_count=$((fallback_upstream_count + 1))
    print "::warning title=Upstream validation deferred::$module_id could not be fetched; the locked snapshot was retained"
    continue
  fi

  if [[ ! -s "$upstream_file" ]] || grep -Eqi '<!doctype|<html([[:space:]>])' "$upstream_file"; then
    print -u2 "Invalid upstream response: $module_id"
    exit 1
  fi

  current_sha=$(shasum -a 256 "$upstream_file" | awk '{print $1}')

  if [[ "$current_sha" != "$locked_sha" || "$upstream_url" != "$locked_url" ]]; then
    print -u2 "Upstream changed or source lock mismatch: $module_id"
    exit 1
  fi

  awk '{ gsub(/\r/, ""); sub(/^﻿/, ""); if ($0 !~ /^#!category[[:space:]]*=/) print }' \
    "$upstream_file" > "$upstream_normalized"
  awk '{ gsub(/\r/, ""); sub(/^﻿/, ""); if ($0 !~ /^#!category[[:space:]]*=/) print }' \
    "$repo_root/$local_path" > "$local_normalized"
  perl -0pi -e 's/\n+\z/\n/' "$upstream_normalized" "$local_normalized"

  if ! cmp -s "$upstream_normalized" "$local_normalized"; then
    print -u2 "Local snapshot differs from upstream beyond category metadata: $module_id"
    exit 1
  fi
done < <(jq -r '.modules[] | select(.upstreamUrl != null) | [.id, .upstreamUrl, .localPath] | @tsv' "$manifest_file")

perl -ne '
  while (/script-path\s*=\s*(https:\/\/[^,\s]+)/g) { print "$1\n" }
  while (/RULE-SET,\s*(https:\/\/[^,\s]+)/g) { print "$1\n" }
' "$repo_root"/modules/*.sgmodule | sort -u > "$ci_tmp/runtime-urls"

runtime_url_count=0
fallback_runtime_count=0
while IFS= read -r runtime_url; do
  [[ -z "$runtime_url" ]] && continue
  runtime_url_count=$((runtime_url_count + 1))
  runtime_file="$ci_tmp/runtime-$runtime_url_count"

  if ! curl --globoff -L --fail --silent --show-error \
    --retry 2 \
    --max-time 30 \
    --user-agent 'Surge iOS/6.0' \
    --output "$runtime_file" \
    "$runtime_url"; then
    if ! is_fallback_url "$runtime_url"; then
      exit 1
    fi

    fallback_runtime_count=$((fallback_runtime_count + 1))
    print "::warning title=Runtime validation deferred::$runtime_url could not be fetched from the hosted runner"
    continue
  fi

  if [[ ! -s "$runtime_file" ]] || grep -Eqi '<!doctype|<html([[:space:]>])' "$runtime_file"; then
    print -u2 "Invalid runtime dependency: $runtime_url"
    exit 1
  fi
done < "$ci_tmp/runtime-urls"

if git -C "$repo_root" grep -n -I -E \
  '(^|[^[:alpha:]])(passphrase|p12|private-key|proxy-auth|password|bearer[[:space:]]+)[[:space:]]*=' \
  -- . \
  ':!scripts/validate.sh' \
  ':!scripts/validate-ci.sh'; then
  print -u2 'Potential secret material found in repository'
  exit 1
fi

printf 'Portable validation: OK\n'
printf 'Modules: %s (%s upstream snapshots, %s curated local modules)\n' \
  "$module_count" "$upstream_count" "$((module_count - upstream_count))"
printf 'Fallback upstream snapshots: %s\n' "$fallback_upstream_count"
printf 'Runtime dependencies: %s (%s deferred)\n' "$runtime_url_count" "$fallback_runtime_count"
printf 'Validation artifacts: %s\n' "$ci_tmp"

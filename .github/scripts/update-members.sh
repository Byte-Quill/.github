#!/usr/bin/env bash
# Regenerates the members section of profile/README.md between the
# MEMBERS:START / MEMBERS:END markers. Uses only curl + jq (preinstalled
# on ubuntu-latest runners) — no Python setup, no pip installs.
#
# API budget: 2 org calls + 1 call per member (for display names).
set -euo pipefail

ORG="Byte-Quill"
README="profile/README.md"
API="https://api.github.com"
AUTH=(-H "Authorization: Bearer ${GITHUB_TOKEN:?GITHUB_TOKEN required}"
      -H "Accept: application/vnd.github+json")

# One call for all members, one call for admins (role detection without N extra calls)
members=$(curl -sf "${AUTH[@]}" "$API/orgs/$ORG/members?per_page=100")
admin_logins=$(curl -sf "${AUTH[@]}" "$API/orgs/$ORG/members?role=admin&per_page=100" | jq -r '.[].login')

is_admin() { grep -qx "$1" <<<"$admin_logins"; }

# Build member cards, 2 per table row
cards=""
row_open=0
while read -r login id url; do
  name=$(curl -sf "${AUTH[@]}" "$API/users/$login" | jq -r '.name // empty')
  [ -n "$name" ] || name="$login"
  role="Member"
  is_admin "$login" && role="Admin"

  [ "$row_open" -eq 0 ] && cards+="<tr>"$'\n'
  cards+="<td align=\"center\" width=\"200\">

[![${name}](https://avatars.githubusercontent.com/u/${id}?s=120&v=4)](${url})

**[${name}](${url})**

*${role}*

</td>"$'\n'

  if [ "$row_open" -eq 1 ]; then
    cards+="</tr>"$'\n'
    row_open=0
  else
    row_open=1
  fi
done < <(echo "$members" | jq -r '.[] | "\(.login) \(.id) \(.html_url)"')

# Odd member count: pad the last row with an empty cell
if [ "$row_open" -eq 1 ]; then
  cards+="<td align=\"center\" width=\"200\"></td>"$'\n'
  cards+="</tr>"$'\n'
fi

section="<div align=\"center\">
<table>
${cards}</table>

**[View all organization members →](https://github.com/orgs/${ORG}/people)**

</div>"

# Replace content between the markers
tmp=$(mktemp)
awk -v section="$section" '
  /<!-- MEMBERS:START/ { print; printf "%s\n", section; skip=1; next }
  /<!-- MEMBERS:END/   { skip=0 }
  !skip                { print }
' "$README" > "$tmp"
mv "$tmp" "$README"

echo "README updated with $(echo "$members" | jq 'length') members."

#!/bin/sh
# Issue #427, steps 1 to 4: after an app is published to production, check the Google Play addresses of site/stores.js and the
# redirect of the page the TV QR code opens. Run it only after the release (before it the addresses answer 404).
#   tools/check_store_links.sh
# It checks that the page of each address is the listing of its package id (after the redirects), and that `site/get/index.html`
# has the redirect code (it does not open the page in a browser). It prints one line for each address (OK or FAIL) and exits 1 when one fails. A person still checks the look of the listing
# (name, icon) and the badges of the English and Hebrew home pages, and opens /get/ on an Android phone (steps 1, 3, 4).
set -u
cd "$(dirname "$0")/.." || exit 1
fail=0
for key in play playTv; do
	url="$(sed -n "s/^ *$key: \"\([^\"]*\)\".*/\1/p" site/stores.js)"
	if [ -z "$url" ]; then echo "FAIL $key: no address in site/stores.js"; fail=1; continue; fi
	out="$(curl -s -m 20 -o /dev/null -L -w '%{http_code} %{url_effective}' "$url")"
	code="${out%% *}"
	final="${out#* }"
	id="${url##*id=}"
	if [ "$code" = "200" ] && case "$final" in *"details?id=$id"*) true ;; *) false ;; esac; then echo "OK   $key $url"; else echo "FAIL $key $url (HTTP $code)"; fail=1; fi
done
# /get/ sends an Android phone to stores.js `play` (the phone app): the page must load that file and have the redirect.
if grep -q 'stores.js' site/get/index.html && grep -q 'location.replace(s.play)' site/get/index.html; then
	echo "OK   get/ redirects an Android phone to the phone app"
else
	echo "FAIL get/ has no redirect to stores.js play"
	fail=1
fi
exit $fail

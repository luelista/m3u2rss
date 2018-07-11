#!/bin/bash -e

FILE="$1"
OUTFILE=${OUTFILE:-${FILE%%.m3u}.rss}

grep -q EXTM3U "$FILE" && EXTM3U=true

cat > "$OUTFILE" <<EOF
RSS HEAD
EOF

cat "$FILE" |
while read l; do
	echo 123 $l
done


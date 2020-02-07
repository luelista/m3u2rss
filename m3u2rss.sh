#!/bin/bash
#TODO: EXTM3U not supported

FILE="$1"
OUTFILE=${OUTFILE:-${FILE%%.m3u}.rss}

TMPHEADER=`mktemp`
TMPMEDIA=`mktemp`
TMPMEDIAHEADER=`mktemp`

#TODO: get more info from the 1st URL
cat > "$OUTFILE" <<EOF
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0">
<channel>
 <title>RSS Title</title>
 <description>This is an example of an RSS feed</description>
 <language>en-us</language>
 <copyright>example.com</copyright>
 <link>http://www.example.com/main.html</link>
 <image>
   <url>http://www.example.com/favicon.png</url>
   <link>http://www.example.com/main.html</link>
   <title>favicon</title>
 </image>
 <generator>m3u2rss.sh v 0.01</generator>
 <ttl>263520</ttl>
EOF
echo "<lastBuildDate>`date -R`</lastBuildDate>" >> "$OUTFILE"
echo "<pubDate>`date -R`</pubDate>" >> "$OUTFILE"
echo >> "$OUTFILE"

cat "$FILE" |
	tr -d '\r' |
	egrep -v '^#' |
	egrep -v '^$' |
while read l; do
	IS_URL=false ; rm -f "$TMPMEDIAHEADER"

	echo $l | egrep -q '^http' && IS_URL=true
	if $IS_URL; then
		curl -s --limit-rate 1k -m 2 -D $TMPHEADER --output $TMPMEDIA "$l"
		RES=$?
		if [[ -z `head -n1 $TMPHEADER | grep 200` ]]; then
			echo "ERROR: Failed to fetch $l . curl exitcode: $RES" >&2
			echo -n "   HTTP resp: " >&2 ; head -n1 $TMPHEADER >&2
			continue
		fi
		ffmpeg -loglevel panic -i $TMPMEDIA -f ffmetadata $TMPMEDIAHEADER < /dev/null
	else
		ffmpeg -loglevel panic -i "$l" -f ffmetadata $TMPMEDIAHEADER < /dev/null
		# TODO: local files not yet supported
		continue
	fi

	echo "<item>" >> "$OUTFILE"
	echo "<link>$l</link>" >> "$OUTFILE"
	echo "<guid>$l</guid>" >> "$OUTFILE"
	unset TITLE ; TITLE=`egrep '^title=' $TMPMEDIAHEADER | sed 's/title=//'`
	[[ -z "$TITLE" ]] && TITLE="$l"
	echo "<title>$TITLE</title>" >> "$OUTFILE"
	unset AUTHOR ; AUTHOR=`egrep '^artist=' $TMPMEDIAHEADER | 
		sed 's/artist=//'`
	[[ -z "$AUTHOR" ]] && AUTHOR=`egrep '^album_artist=' $TMPMEDIAHEADER | 
		sed 's/album_artist=//'`
	unset DESCRIPTION ; DESCRIPTION=`egrep '^comment=' $TMPMEDIAHEADER | 
		sed 's/comment=//'`
	echo "<description>$AUTHOR
$DESCRIPTION</description>" >> "$OUTFILE"
	PUBDATE=`egrep '^Last-Modified: ' $TMPHEADER | 
		sed 's/Last-Modified: //' | tr -d '\r'`
	[[ -z "$PUBDATE" ]] && PUBDATE=`egrep '^Date: ' $TMPHEADER | 
		sed 's/Date: //' | tr -d '\r'`
	echo "<pubDate>$PUBDATE</pubDate>" >> "$OUTFILE"
	CONTENT_TYPE=`egrep '^Content-Type: ' $TMPHEADER | 
		sed 's/Content-Type: //' | tr -d '\r'`
	CONTENT_LENGTH=`egrep '^Content-Length: ' $TMPHEADER | 
		sed 's/Content-Length: //' | tr -d '\r'`
	echo '<enclosure url="'"$l"'" length="'$CONTENT_LENGTH'" type="'$CONTENT_TYPE'" />' >> "$OUTFILE"

	echo "</item>" >> "$OUTFILE" ; echo >> "$OUTFILE"
done

cat >> "$OUTFILE" <<EOF
</channel>
</rss>
EOF

echo 'Please check result with: https://validator.w3.org/feed/#validate_by_input '


#!/bin/sh
. /tmp/loader

_http header_mimetype_output "text/html"
echo "OK"

echo "REMOTE_ADDR=${REMOTE_ADDR}&$QUERY_STRING" >>"/tmp/COLLECT_DATA"

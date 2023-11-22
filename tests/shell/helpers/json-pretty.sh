#!/bin/bash -e

# WARNING: the output is not guaranteed to be stable.

if command -v jq &>/dev/null ; then
	# If we have, use `jq`
	exec jq
fi

# Fallback to python.
exec python -c '
import json
import sys

parsed = json.load(sys.stdin)
print(json.dumps(parsed, indent=2))
'

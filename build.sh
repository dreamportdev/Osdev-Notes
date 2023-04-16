#!/bin/bash

result=`find . -maxdepth 1 -type d | sort`

echo $result

while IFS='' read -r -d '' filename; do
  : # something with "$filename"
  echo $filename
done < <(find .  -maxdepth 1 -not -path '*/.*' -type d -print0 | sort -zV )

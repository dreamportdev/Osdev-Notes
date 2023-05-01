#!/bin/bash

result=`find . -maxdepth 1 -type d | sort`

decorators=($(ls -d .pandoc/decorators/*))
counter=0
fileslit=""
echo $result
echo ${decorators[@]}
echo ${decorators[0]}
echo ${decorators[10]}

while IFS='' read -r -d '' filename; do
  : # something with "$filename"
  if [ $filename = "." ] || [ $filename = "./Images" ]; then
    continue
  fi
  echo $filename "- ${counter}"
  fileslist=$fileslist" "`ls -d $filename/*`" ${decorators[$counter]}"
  ((counter+=1))
done < <(find .  -maxdepth 1 -not -path '*/.*' -type d -print0 | sort -zV )

echo "=-===="
echo $fileslist

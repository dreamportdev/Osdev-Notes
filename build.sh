#!/bin/bash

result=`find . -maxdepth 1 -type d | sort`

decorators=($(ls -d .pandoc/decorators/*))
counter=0
fileslit=""
output_file="osdev_notes_book.pdf"
pandoc_flags="--toc --top-level-division=chapter -f markdown+raw_tex -t pdf --pdf-engine=pdflatex -N --lua-filter .pandoc/makerelative.lua -f markdown-implicit_figures"
pandoc_command="pandoc ${pandoc_flags}"
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
  fileslist=$fileslist" "`ls -R -d $filename/*`" ${decorators[$counter]}"
  #fileslist=$fileslist" "`find ${filename} -type f -name '*.md' | sort`" ${decorators[$counter]}"
  ((counter+=1))
done < <(find .  -maxdepth 1 -not -path '*/.*' -type d -print0 | sort -zV )

echo "=-===="
pandoc_command="$pandoc_command $fileslist LICENSE.md .pandoc/pandoc.yaml -o $output_file"

echo $pandoc_command
eval $pandoc_command

#!/bin/bash

get_entries() {
    echo $(find $1 -maxdepth 1 -regextype egrep -regex '.*\/[0-9A-Z]{1,2}_[A-Za-z_.]*' | sort)
}

pandoc_filename="osdev-notes-$(date +%F).pdf"
pandoc_flags="-s --resource-path=$(pwd) --toc --top-level-division=chapter -f markdown+raw_tex -t pdf --pdf-engine=pdflatex -N --lua-filter .pandoc/makerelative.lua"

echo "Building pandoc command line. Structure of the final pdf is based on the directory structure."
echo "Each directory in the format \"XX_Name\" (where XX is two digits) is included."
echo "|-- Title"
echo "|-- Table of Contents"
echo "|"

chapter_dirs="$(get_entries '.')"
for dir in $chapter_dirs; do
    if [ -f ".pandoc/decorators/${dir:2}.tex" ]; then
        cmd_body+=".pandoc/decorators/${dir:2}.tex "
        echo "|---- ${dir:2} (with decorator)"
    else
        echo "|---- ${dir:2} (no decorator file)"
    fi

    chapter_entries="$(get_entries $dir)"
    for entry in $chapter_entries; do
        if [[ $entry != *".md" ]]; then
            continue;
        fi
        echo "|  |- ${entry:2}"
        cmd_body+="$entry "
    done
    unset chapter_entries
    echo "|"
done

cmd_body+="LICENSE.md"
if [ -v ADD_COMMIT ]; then
    awk -v HASH=`git rev-parse HEAD`  '!found && /header-includes/ { print "   |\n   | based on commit: " HASH ; found=1 } 1' .pandoc/pandoc.yaml | tee .pandoc/pandoc_1.yaml
    mv .pandoc/pandoc_1.yaml .pandoc/pandoc.yaml
fi

$(pandoc $pandoc_flags $cmd_body .pandoc/pandoc.yaml -o $pandoc_filename)

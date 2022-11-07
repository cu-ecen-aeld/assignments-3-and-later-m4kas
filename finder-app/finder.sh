#!/bin/sh

if [ $# -ne 2 ]; then
    echo "Please provide 2 arguments ($# provided)"
    exit 1
fi
if [ -d $1 ]
then
    cd $1
    number_of_files="$(find . -type f | wc -l)"
    [ -z "$number_of_files" ] && number_of_files=0
    number_of_finds="$(grep -r $2 * | wc -l)"
    #[ -z "$number_of_finds" ] && number_of_finds=0
    echo "The number of files are ${number_of_files} and the number of matching lines are ${number_of_finds}"
else
    echo "Provided dir $1 does not exist!"
    exit 1
fi

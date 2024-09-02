#!/bin/bash

# dt - DirTouch; author - @logan9t8

ORIGINAL="$PWD"
LOCATION="$1"
MANIFEST="$2"

error() {
	echo -n "dt: ERROR $1: "
	case $1 in
	1) echo "Incorrect number of arguments ($#)" ;;
	2) echo "Location does not exists" ;;
	3) echo "Manifest does not exists" ;;
	4) echo "Manifest not readable" ;;
	5) echo "Manifest is empty" ;;
	6) echo "Leading space" ;;
	7) echo "Invalid indendation" ;;
	8) echo "Directory '$2' already exists" ;;
	9) echo "Cannot traverse directory. Exiting" ;;
	10) echo "Cannot create directory. Exiting" ;;
	esac
	exit
}

[[ "$#" -ne 2 ]] && error 1
[[ ! -d "$LOCATION" ]] && error 2
[[ ! -f "$MANIFEST" ]] && error 3
[[ ! -r "$MANIFEST" ]] && error 4
grep -q "[^[:space:]]" "$MANIFEST" || error 5

get1char() { # Shell version doesn't work
	python3 -c 'import sys; i = int(sys.argv[2]); print(sys.argv[1][i:i+1])' "$1" "$2"
}

level=()
clevel=0 # Current level

# Loop for tabulating hierarchy tree
while IFS= read -r line || [[ -n "$line" ]]; do # 2nd part - To support non standard POSIX file
	[[ -z "${line//$(echo -e "\t")/}" ]] && level+=(-1) && continue # Empty line ignored
	temp=0
	i=0
	while [[ $(get1char "$line" "$i") == $(echo -e "\t") ]]; do
		temp=$((temp + 1))
		i=$((i + 1))
	done
	[[ $(get1char "$line" "$i") == "#" ]] && level+=(-1) && continue # Comment line ignored
	[[ $(get1char "$line" "$i") == " " ]] && error 6
	diff=$((clevel - temp))
	[[ ${diff#-} -gt 1 && $temp -ne 0 ]] && error 7 # abs > 1
	if [[ $temp == 0 ]]; then
		[[ -e $(echo "$line" | sed -e 's/^[\t]*//' | sed 's/#.*//' | xargs echo) ]] && error 8 "$(echo "$line" | sed -e 's/^[\t]*//' | sed 's/#.*//' | xargs echo)"
	fi
	clevel=$temp
	level+=("$temp")
done <"$MANIFEST"

clevel=0
cdir="."
i=0
count=0 # Excluding empty & comment lines ($i includes them)
cd "$LOCATION" || error 9

# Execution loop
while IFS= read -r line || [[ -n "$line" ]]; do
	[[ ${level[i]} == -1 ]] && i=$((i + 1)) && continue # Empty line ignored
	if [[ ${level[i]} -gt $clevel ]]; then
		cd "$cdir" || error 9
	elif [[ ${level[i]} -lt $clevel ]]; then
		for ((j = 0; j < $((clevel - level[i])); j++)); do
			cd .. || error 9
		done
	else
		:
	fi
	cdir=$(echo "$line" | sed -e 's/^[\t]*//;s/#.*$//' | xargs echo)
	mkdir "$cdir" || error 10
	clevel=${level[i]}
	count=$((count + 1))
	i=$((i + 1))
done <"$ORIGINAL/$MANIFEST"

echo "dt: SUCCESS: $count directories created"

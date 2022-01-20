#!/usr/bin/bash

cd ~/git/basic_assembler_bash/
input=test.asm

if [ ! -f $input ]; then
	echo "File doesn't exist"
	exit 1
fi

# direct memory-reference, indirect memory-reference and non-memory-reference
declare -A labels
declare -A dmr=( ["AND"]=0 ["ADD"]=1 ["LDA"]=2 ["STA"]=3 ["BUN"]=4 ["BSA"]=5 ["ISZ"]=6 )
declare -A imr=( ["AND"]=8 ["ADD"]=9 ["LDA"]='A' ["STA"]='B' ["BUN"]='C' ["BSA"]='D' ["ISZ"]="E" )
declare -A nmr=( ["CLA"]=7800 ["CLE"]=7400 ["CMA"]=7200 ["CME"]=7100 ["CIR"]=7080 \
		["CIL"]=7040 ["INC"]=7020 ["SPA"]=7010 ["SNA"]=7008 ["SZA"]=7004 ["SZE"]=7002 \
		["HLT"]=7001 ["INP"]="F800" ["OUT"]="F400" ["SKI"]="F200" ["SKO"]="F100" \
		["ION"]="F080" ["IOF"]="F040" )

# First pass
while read -r line
do 

	# Remove comments 
	line=$(cut -d "/" -f 1 <<< $line)

	# look for ORG psuedo-instructions and set Location_counter (LC)
	if echo "$line" | grep -q "ORG"; then 
		location_counter="0x"$(grep -Po "[0-9]+" <<< $line)
		intermediate+="$(echo $line)"$'\n'
	else

		# break when we find the END psuedo-instruction
		if echo "$line" | grep -q "END"; then 
			break

		# if we find a "," means we found a label which needs to be saved
		elif echo "$line" | grep -q ","; then
			labels["$(grep -Po "^[a-zA-Z]+[^, ]" <<< "$line")"]=${location_counter:2:3}
			temp=$( xargs <<< "$location_counter $(cut -d "," -f 2 <<< $line)")
			intermediate+="$temp"$'\n'

		# not a label, ORG nor END
		else
			intermediate+="$location_counter $line"$'\n'

		fi
		# add 0x1 to the location_counter and save back to variable using (-v) flag
		printf -v location_counter "0x%x" $((location_counter + 1))

	fi

done < "$input"

# Remove trailing new lines at end of file
intermediate=$(awk 'NF' <<< $intermediate)

# Second pass

# clear output file and remove errors file if exists
rm -f errors.txt
> output.txt

line_number=0
while read -r line
do 

	line_number=$(expr $line_number + 1)
	location=${line:2:3}
	instruction=$(cut -d ' ' -f 2 <<< "$line")
	operand=$(cut -d " " -f 3 <<< "$line")

	if echo "$line" | grep -q "ORG"; then 
		continue
	elif $(grep -Poq " I$" <<< "$line") && [ -v 'imr[$instruction]' ]; then 
		echo "$location ${imr["$instruction"]}${labels["$operand"]}" >> output.txt
	elif [ -v 'dmr["$instruction"]' ]; then
		echo "$location ${dmr["$instruction"]}${labels["$operand"]}" >> output.txt
	elif [ -v 'nmr["$instruction"]' ]; then
		echo "$location ${nmr["$instruction"]}" >> output.txt
	else

		if [ "$instruction" = "HEX" ];then
			# pad operant with zeroes 
			operand=$(printf %4s $operand | tr ' ' 0)
			echo "$location $operand" >> output.txt
		elif [ "$instruction" = "DEC" ] && [ "${operand:0:1}" != "-" ]; then
			operand=$(printf %4s $(echo "obase=16; $operand" | bc) | tr ' ' 0)
			echo "$location $operand" >> output.txt
		elif [ "$instruction" = "DEC" ] && [ "${operand:0:1}" == "-" ]; then
			operand=$(printf '%x\n' $(echo ${operand:1:4} | xargs))
			operand=$(printf '%x\n' $(( ~ "0x$operand" )) )
			operand="0x${operand:12:4}"
			printf -v operand "0x%x" $((operand + 1))
			echo "$location ${operand:2:4}" >> output.txt
		else
			echo "Error found in line $line_number" >> errors.txt
		fi
	fi

done <<< "$intermediate"

# if errors file exists, show the content and empty the output file
if [ -f errors.txt ]; then
	cat errors.txt
	> output.txt
else
	cat output.txt
fi

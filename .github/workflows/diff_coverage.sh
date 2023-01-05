missing-lines() {
    for file in $(jq ".files | keys[]" $1); do
        for missing_line in $(jq ".files.$file.missing_lines[]" $1); do
            echo "$file:$missing_line"
        done
    done
}

executed-lines() {
    for file in $(jq ".files | keys[]" $1); do
        for executed_line in $(jq ".files.$file.executed_lines[]" $1); do
            echo "$file:$executed_line"
        done
    done
}

diff-lines() {
    local path=
    local line=
    while read -r; do
        esc=$'\033'
        if [[ $REPLY =~ ---\ (a/)?.* ]]; then
            continue
        elif [[ $REPLY =~ \+\+\+\ (b/)?([^[:blank:]$esc]+).* ]]; then
            path=${BASH_REMATCH[2]}
        elif [[ $REPLY =~ @@\ -[0-9]+(,[0-9]+)?\ \+([0-9]+)(,[0-9]+)?\ @@.* ]]; then
            line=${BASH_REMATCH[2]}
        elif [[ $REPLY =~ ^($esc\[[0-9;]*m)*([\\\ +-]) ]]; then
            # echo "$path:$line:$REPLY"
            prefix=${BASH_REMATCH[2]}
            if [[ $prefix =~ \+ ]]; then
                echo "\"$path\":$line"
            fi
            if [[ $prefix =~ [\ +] ]]; then
                ((line++))
            fi
        fi
    done
}

# coverage run --source=src/ -m pytest tests/
coverage json
missing-lines coverage.json > missing_lines.txt
executed-lines coverage.json > executed_lines.txt
git diff $1..$2 | diff-lines | uniq > diff_lines.txt

echo "---"
diff_ex=$(grep -cFxf executed_lines.txt diff_lines.txt)
diff_miss=$(grep -cFxf missing_lines.txt diff_lines.txt)
diff_stmts=$(($diff_miss + $diff_ex))
if [ $diff_stmts != 0 ]; then
    diff_cover=$((1 - $diff_miss / $diff_stmts))
fi
echo "JUST THE DIFF"
echo "TOTAL | $diff_stmts | $diff_miss | $diff_cover | "

echo "---"
echo "OVERALL"
# cover=$(jq ".totals.percent_covered" coverage.json)
# stmts=$(jq ".totals.num_statements" coverage.json)
# miss=$(jq ".totals.missing_lines" coverage.json)
ex=$(grep "" -c executed_lines.txt)
miss=$(grep "" -c missing_lines.txt)
stmts=$(($miss + $ex))
if [ $stmts != 0 ]; then
    cover=$(echo "scale=2; 1 - $miss / $stmts" | bc)
fi
echo "TOTAL | $stmts | $miss | $cover | "
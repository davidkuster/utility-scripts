#!/bin/bash

# See statistics by dev on a Git repo. 
# Mostly this is to investigate productive time of day (morning vs afternoon) and also gauge overwork (nights and weekends).
#
# Usage: 
# $ git-statistics.sh .


# Navigate to the git directory
cd $1

# Ensure it's a valid git directory
if [ ! -d .git ]; then
    echo "This is not a valid git directory."
    exit 1
fi

# calculate total lines of code once
echo "Calculating total LOC..."
total_lines=$(git ls-tree -r HEAD --name-only | xargs -n1 git blame | wc -l)
echo "LOC = $total_lines"


# Function to convert email to a case-insensitive regex pattern
case_insensitive_pattern() {
    local email="$1"
    local pattern=""
    for (( i=0; i<${#email}; i++ )); do
        char="${email:$i:1}"
        if [[ "$char" =~ [a-zA-Z] ]]; then
            lower=$(echo "$char" | tr '[:upper:]' '[:lower:]')
            upper=$(echo "$char" | tr '[:lower:]' '[:upper:]')
            pattern+="[$lower$upper]"
        else
            pattern+="$char"
        fi
    done
    echo "$pattern"
}

# Function to process commits for each developer
process_commits() {
    local email="$1"
    local pattern=$(case_insensitive_pattern "$email")
    echo "$email:"

    # Total commits
    total_commits=$(git log --author="$pattern" --oneline | wc -l)
 
    # Commits before noon
    before_noon=$(git log --author="$pattern" --pretty=format:'%ad' --date=format:'%H:%M' | awk -F: '$1 < 12' | wc -l)

    # Commits between noon and 5pm
    noon_to_5pm=$(git log --author="$pattern" --pretty=format:'%ad' --date=format:'%H:%M' | awk -F: '$1 >= 12 && $1 < 17' | wc -l)

    # Commits after 5pm
    after_5pm=$(git log --author="$pattern" --pretty=format:'%ad' --date=format:'%H:%M' | awk -F: '$1 >= 17' | wc -l)

    # Commits on weekends
    weekend_commits=$(git log --author="$pattern" --pretty=format:'%ad' | grep -E '^(Sat|Sun)' | wc -l)

    # Calculate code contribution percentage
    author_lines=$(git ls-tree -r HEAD --name-only | xargs -n1 git blame --line-porcelain | grep -i "^author-mail <$email>" | wc -l)
    if [ "$total_lines" -ne 0 ]; then
        contribution_percentage=$(echo "scale=2; $author_lines / $total_lines * 100" | bc)
    else
        contribution_percentage="0.00"
    fi


    # Calculate the percentage of total commits for each time period
    if [ "$total_commits" -ne 0 ]; then
        percent_before_noon=$(echo "scale=2; ($before_noon * 100) / $total_commits" | bc)
        percent_noon_to_5pm=$(echo "scale=2; ($noon_to_5pm * 100) / $total_commits" | bc)
        percent_after_5pm=$(echo "scale=2; ($after_5pm * 100) / $total_commits" | bc)
        percent_weekend_commits=$(echo "scale=2; ($weekend_commits * 100) / $total_commits" | bc)
    else
        percent_before_noon="0.00"
        percent_noon_to_5pm="0.00"
        percent_after_5pm="0.00"
        percent_weekend_commits="0.00"
    fi

    # print results
    echo "  Total commits:       $total_commits"
    echo "  Commits before noon: $before_noon ($percent_before_noon%)"
    echo "  Commits from 12-5pm: $noon_to_5pm ($percent_noon_to_5pm%)"
    echo "  Commits after 5pm:   $after_5pm ($percent_after_5pm%)"
    echo "  Commits on weekends: $weekend_commits ($percent_weekend_commits%)"
    echo ""
    echo "  LOC on HEAD:         $author_lines (of $total_lines)"
    echo "  Approximate code %:  $contribution_percentage%"
    echo ""
}

echo -e "\nGetting git statistics... \n(note totals may be > 100% as time-based commits currently include weekend commits)\n"

# Get list of authors
authors=$(git log --format='%aE' | sort -uf)

# Process each author
while IFS= read -r author; do
    process_commits "$author"
done <<< "$authors"

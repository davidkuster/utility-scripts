#!/bin/bash

# See statistics by dev on a Git repo. (Excluding binary files.)
#
# Mostly this is to investigate productive time of day (morning vs afternoon) and also gauge overwork (nights and weekends).
# Note that the overall commit numbers mimic what can be seen on the contributors graph in the GitHub UI, although this is
# by email instead of GitHub username.
#
# Usage:
#   $ git-statistics.sh             # current dir
#   $ git-statistics /path/to/repo  # specify dir


DIR=${1:-.}

cd "$DIR"

# Ensure it's a valid git directory
if [ ! -d .git ]; then
    echo "This is not a valid git directory."
    exit 1
fi

echo -e "\nGathering git statistics...\n"

# get the names of all non-binary files
files=$(git ls-tree -r HEAD --name-only | xargs -I {} sh -c 'git grep -Iq . "{}" && echo "{}"' 2>/dev/null)

# get the lines per author
lines_per_author=$(echo $files | xargs -n1 git blame --line-porcelain | grep author-mail)

# calculate total lines of code once
total_lines=$(echo "$lines_per_author" | wc -l)
echo "Total LOC = $total_lines"


commits=$(git log --pretty=format:'%ad %ae' --date=format:'%a %H:%M')


# Function to process commits for each developer
process_commits() {
    local email="$1"

    # Total commits
    total_commits=$(echo "$commits" | grep -i "$email" | wc -l)

    # Weekday commits before noon
    before_noon=$(echo "$commits" | awk '$1 ~ /^(Mon|Tue|Wed|Thu|Fri)$/ && $2 < 12' | grep -i "$email" | wc -l)

    # Weekday commits between noon and 5pm
    noon_to_5pm=$(echo "$commits" | awk '$1 ~ /^(Mon|Tue|Wed|Thu|Fri)$/ && $2 >= 12 && $2 < 17' | grep -i "$email" | wc -l)

    # Weekday commits after 5pm
    after_5pm=$(echo "$commits" | awk '$1 ~ /^(Mon|Tue|Wed|Thu|Fri)$/ && $2 >= 17' | grep -i "$email" | wc -l)

    # Commits on weekends
    weekend_commits=$(git log --pretty=format:'%ad %ae' | grep -E '^(Sat|Sun)' | grep -i "$email" | wc -l)

    # Calculate code contribution percentage
    author_lines=$(echo "$lines_per_author" | grep -i "$email" | wc -l)
    if [ "$total_lines" -ne 0 ]; then
        contribution_percentage=$(echo "scale=2; ($author_lines * 100) / $total_lines" | bc)
    else
        contribution_percentage="0.00"
    fi


    # Calculate the percentage of total commits for each time period
    if [ "$total_commits" -ne 0 ]; then
        percent_before_noon=$(echo "scale=1; ($before_noon * 100) / $total_commits" | bc)
        percent_noon_to_5pm=$(echo "scale=1; ($noon_to_5pm * 100) / $total_commits" | bc)
        percent_after_5pm=$(echo "scale=1; ($after_5pm * 100) / $total_commits" | bc)
        percent_weekend_commits=$(echo "scale=2; ($weekend_commits * 100) / $total_commits" | bc)
    else
        percent_before_noon="0.00"
        percent_noon_to_5pm="0.00"
        percent_after_5pm="0.00"
        percent_weekend_commits="0.00"
    fi

    # print results
    #echo "  Total commits:       $total_commits"
    #echo "  Commits before noon: $before_noon ($percent_before_noon%)"
    #echo "  Commits from 12-5pm: $noon_to_5pm ($percent_noon_to_5pm%)"
    #echo "  Commits after 5pm:   $after_5pm ($percent_after_5pm%)"
    #echo "  Commits on weekends: $weekend_commits ($percent_weekend_commits%)"
    #echo ""
    #echo "  LOC on HEAD:         $author_lines (of $total_lines)"
    #echo "  Approximate code %:  $contribution_percentage%"
    #echo ""

    # print results
    printf "%-40s | %10s | %-17s | %-17s | %-17s | %-17s | %12s | %10s\n" "$email" "$total_commits" "$before_noon ($percent_before_noon%)" "$noon_to_5pm ($percent_noon_to_5pm%)" "$after_5pm ($percent_after_5pm%)" "$weekend_commits ($percent_weekend_commits%)" "$author_lines" "  $contribution_percentage%"
}

# Get list of authors
authors=$(git log --format='%aE' | sort -uf | tr '[:upper:]' '[:lower:]' | uniq) #awk -F '@' '{print $1}' | uniq)

echo -e "\nCommits per author:\n"

# Print table header
printf "%-40s | %10s | %-17s | %-17s | %-17s | %-17s | %12s | %10s\n" "Email" "Commits  " " Mon-Fri < 12pm" " Mon-Fri 12-5pm" "  Mon-Fri > 5pm" "    Weekend" "LOC on HEAD" "Overall %"
printf "%-40s | %10s | %-17s | %-17s | %-17s | %-17s | %12s | %10s\n" "----------------------------------------" "----------" "-----------------" "-----------------" "-----------------" "-----------------" "------------" "---------"


# Process each author
while IFS= read -r author; do
    process_commits "$author"
done <<< "$authors"

echo ""

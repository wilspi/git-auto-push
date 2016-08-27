#!/usr/bin/env bash

# Config
verbose=true # Verbose mode

# No of commits to push at a time
# Defaults to 1
if [ $# -eq 0 ]; then
	pushing_limit=1
else
	re='^[0-9]+$'
	if ! [[ $1 =~ $re ]]; then
		echo "ERROR: pushing_limit must be a number" >&2; exit 1
	fi
	pushing_limit=$1
fi

# Get current branch name
branch_name="$(git symbolic-ref HEAD 2>/dev/null)" ||
branch_name="(unnamed branch)"     # detached HEAD
branch_name=${branch_name##refs/heads/}
if [ "$verbose" = true ]; then
	echo "You are on branch: " $branch_name
fi

user_plus_repo=git ls-remote --get-url | awk '{ sub(/.+com\//, ""); print  }'
remote_branch_exists=git ls-remote --heads git@github.com:$user_plus_repo $branch_name | wc -l
remote_branch_exists=true

# Get number of commits ahead and commits behind
if [ "$remote_branch_exists" = true ]; then
	commits_ahead="$(git rev-list origin/$branch_name..HEAD --count)"
	commits_behind="$(git rev-list HEAD..origin/$branch_name --count)"
else
	commits_ahead="$(git rev-list origin/master..HEAD --count)"
	commits_behind="0"
fi
if [ "$verbose" = true ]; then
	echo "Commits ahead: " $commits_ahead
	echo "Commits behind: " $commits_behind
fi

if [ "$commits_behind" != "0" ]; then
	if [ "$verbose" = true ]; then
		echo "Behind origin by " $commits_behind " commits. Please pull your branch."
	fi
	exit 1
fi

# No of commits to push
if [ $commits_ahead -lt $pushing_limit ]; then
	push_commits=$commits_ahead
else
	push_commits=$pushing_limit
fi

# Checkout to last pushed commit and push code
if [ "$commits_ahead" -gt "0" -a $(( $commits_ahead-$push_commits )) -gt "-1" ]; then
	git checkout HEAD~$(( $commits_ahead-$push_commits )) --quiet
	commit_sha="$(git rev-parse HEAD)"
	if [ "$verbose" = true ]; then
		echo "At commit: " ${commit_sha:0:7} " Pushing commits: " $push_commits
	fi
	git push origin $commit_sha:$branch_name --quiet

	# Back to where HEAD was
	git checkout $branch_name --quiet
else
	if [ "$verbose" = true ]; then
		echo "Origin is upto date."
	fi
	exit 1
fi

# Show Git log graph
if [ "$verbose" = true ]; then
	echo "Git Log: "
	git log --pretty=oneline --abbrev-commit --graph --decorate --all
fi

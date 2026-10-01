#!/usr/bin/env bash
# SessionStart hook: pull, then list what's new since this clone last looked.
# Its output goes into Claude's context; CLAUDE.md ("Session start") says what to do with it.
# "Last looked" is stored per clone in .git/claude-last-seen, so it is never committed.

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

state="$(git rev-parse --git-dir)/claude-last-seen"
branch=$(git rev-parse --abbrev-ref HEAD)

echo "## Session start (automatic, from .claude/hooks/session-start.sh)"
echo "Branch: $branch"

if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
	echo "Uncommitted local changes, so no pull was done:"
	git status --short --untracked-files=no | head -20
else
	if out=$(git pull --ff-only -q 2>&1); then
		echo "Pull: ok"
	else
		echo "Pull FAILED (offline, login, or diverged history):"
		echo "$out" | tail -3
	fi
fi

head=$(git rev-parse HEAD)
last=$(cat "$state" 2>/dev/null)

if [ -z "$last" ] || ! git cat-file -e "$last^{commit}" 2>/dev/null; then
	echo "First session in this clone: nothing to compare against. Last 10 commits:"
	git log --format='%h %an %ad  %s' --date=short -10
elif [ "$last" = "$head" ]; then
	echo "Nothing new since the last session."
else
	echo "New since the last session ($(git rev-list --count "$last..$head") commits):"
	git log --format='%h %an %ad  %s' --date=short "$last..$head"
	echo
	echo "Files changed:"
	git diff --stat "$last..$head" | tail -25
fi

echo "$head" > "$state"

# On another branch, the pull above doesn't bring main: say what's new there too.
main_state="$(git rev-parse --git-dir)/claude-last-seen-main"
if [ "$branch" = "main" ]; then
	echo "$head" > "$main_state"
else
	git fetch -q origin main 2>/dev/null
	main_head=$(git rev-parse -q --verify origin/main 2>/dev/null)
	main_last=$(cat "$main_state" 2>/dev/null)
	if [ -n "$main_head" ]; then
		echo
		if [ -n "$main_last" ] && [ "$main_last" != "$main_head" ] \
				&& git cat-file -e "$main_last^{commit}" 2>/dev/null; then
			echo "New on main since the last session ($(git rev-list --count "$main_last..$main_head") commits):"
			git log --format='%h %an %ad  %s' --date=short "$main_last..$main_head"
		else
			echo "Nothing new on main since the last session."
		fi
		echo "$branch is $(git rev-list --count "$main_head..$head") commits ahead of main and $(git rev-list --count "$head..$main_head") behind."
		echo "$main_head" > "$main_state"
	fi
fi
exit 0

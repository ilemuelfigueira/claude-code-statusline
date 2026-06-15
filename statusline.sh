#!/usr/bin/env bash
input=$(cat)

cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
used_percentage=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
repo_owner=$(echo "$input" | jq -r '.workspace.repo.owner // empty')
repo_name=$(echo "$input" | jq -r '.workspace.repo.name // empty')
session_name=$(echo "$input" | jq -r '.session_name // empty')
effort_level=$(echo "$input" | jq -r '.effort.level // empty')
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
five_hour_used=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_hour_resets_at=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

dir_display=$(basename "$cwd")

COLOR_RESET="\033[0m"
COLOR_GREEN="\033[32m"
COLOR_YELLOW="\033[33m"
COLOR_RED="\033[31m"
COLOR_MAGENTA="\033[35m"
COLOR_BLUE="\033[34m"

effort_label=""
has_effort_level=false
[ -n "$effort_level" ] && has_effort_level=true

if $has_effort_level; then
  is_low_effort=false
  is_medium_effort=false
  is_high_effort=false
  is_xhigh_effort=false
  is_max_effort=false

  [ "$effort_level" = "low" ]    && is_low_effort=true
  [ "$effort_level" = "medium" ] && is_medium_effort=true
  [ "$effort_level" = "high" ]   && is_high_effort=true
  [ "$effort_level" = "xhigh" ]  && is_xhigh_effort=true
  [ "$effort_level" = "max" ]    && is_max_effort=true

  if $is_low_effort; then
    effort_label=$(printf "${COLOR_GREEN}low${COLOR_RESET}")
  elif $is_medium_effort; then
    effort_label=$(printf "${COLOR_YELLOW}medium${COLOR_RESET}")
  elif $is_high_effort; then
    effort_label=$(printf "${COLOR_RED}high${COLOR_RESET}")
  elif $is_xhigh_effort; then
    effort_label=$(printf "${COLOR_MAGENTA}xhigh${COLOR_RESET}")
  elif $is_max_effort; then
    effort_label=$(printf "${COLOR_MAGENTA}max${COLOR_RESET}")
  else
    effort_label="$effort_level"
  fi
fi

visible_len() {
  local stripped
  stripped=$(printf '%s' "$1" | sed $'s/\033\[[0-9;]*m//g')
  printf '%s' "$stripped" | wc -m | tr -d ' \n'
}

left_parts=()
right_parts=()

has_session_name=false
[ -n "$session_name" ] && has_session_name=true
if $has_session_name; then
  left_parts+=("[$session_name]")
fi

has_repo_owner=false
[ -n "$repo_owner" ] && has_repo_owner=true
has_dir_display=false
[ -n "$dir_display" ] && has_dir_display=true

if $has_repo_owner; then
  repo_display=$(printf "${COLOR_MAGENTA}${repo_owner}${COLOR_RESET} @ ${COLOR_BLUE}${repo_name}${COLOR_RESET}")
  left_parts+=("$repo_display")
elif $has_dir_display; then
  dir_colored=$(printf "${COLOR_MAGENTA}${dir_display}${COLOR_RESET}")
  left_parts+=("$dir_colored")
fi

has_git_branch=false
[ -n "$git_branch" ] && has_git_branch=true
if $has_git_branch; then
  left_parts+=("on $git_branch")
fi

has_model=false
[ -n "$model" ] && has_model=true
if $has_model; then
  model_part="| $model"
  if $has_effort_level; then
    model_part="$model_part [${effort_label}]"
  fi
  left_parts+=("$model_part")
fi

has_used_percentage=false
[ -n "$used_percentage" ] && has_used_percentage=true
if $has_used_percentage; then
  used_int=$(printf '%.0f' "$used_percentage")
  bar_total=10
  filled=$(( used_int * bar_total / 100 ))
  empty=$(( bar_total - filled ))
  bar=""
  for i in $(seq 1 $filled); do bar="${bar}█"; done
  for i in $(seq 1 $empty); do bar="${bar}░"; done
  right_parts+=("[${bar}] ${used_int}%")
fi

has_cost_usd=false
[ -n "$cost_usd" ] && has_cost_usd=true
if $has_cost_usd; then
  cost_formatted=$(printf '| $%.2f' "$cost_usd")
  right_parts+=("$cost_formatted")
fi

has_five_hour_used=false
[ -n "$five_hour_used" ] && has_five_hour_used=true
if $has_five_hour_used; then
  five_hour_int=$(printf '%.0f' "$five_hour_used")
  rate_part="| 5h ${five_hour_int}%"
  has_resets_at=false
  [ -n "$five_hour_resets_at" ] && has_resets_at=true
  if $has_resets_at; then
    resets_time=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$five_hour_resets_at" "+%-I:%M%p" 2>/dev/null \
      || date -d "$five_hour_resets_at" "+%-I:%M%p" 2>/dev/null \
      || echo "")
    has_resets_time=false
    [ -n "$resets_time" ] && has_resets_time=true
    if $has_resets_time; then
      rate_part="$rate_part resets ${resets_time}"
    fi
  fi
  right_parts+=("$rate_part")
fi

left_str="${left_parts[*]}"
right_str="${right_parts[*]}"

terminal_width="${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}"
left_len=$(visible_len "$left_str")
right_len=$(visible_len "$right_str")
padding=$(( terminal_width - left_len - right_len ))
is_padding_positive=false
[ "$padding" -gt 0 ] && is_padding_positive=true

if $is_padding_positive; then
  printf '%s%*s%s' "$left_str" "$padding" "" "$right_str"
else
  printf '%s %s' "$left_str" "$right_str"
fi

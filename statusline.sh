#!/usr/bin/env bash
if ! command -v jq &>/dev/null; then
  printf 'statusline: jq not found — install with: brew install jq'
  exit 0
fi
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
  stripped=$(printf '%s' "$1" | sed $'s/\033\[[0-9;]*m//g' | sed 's/[█░]/x/g')
  echo "${#stripped}"
}

left_parts=()

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

# Build right suffix (cost + rate) — bar is calculated separately
cost_str=""
has_cost_usd=false
[ -n "$cost_usd" ] && has_cost_usd=true
if $has_cost_usd; then
  cost_str=$(printf '| $%.2f' "$cost_usd")
fi

rate_str=""
has_five_hour_used=false
[ -n "$five_hour_used" ] && has_five_hour_used=true
if $has_five_hour_used; then
  five_hour_int=$(printf '%.0f' "$five_hour_used")
  rate_str="| 5h ${five_hour_int}%"
  has_resets_at=false
  [ -n "$five_hour_resets_at" ] && has_resets_at=true
  if $has_resets_at; then
    resets_time=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$five_hour_resets_at" "+%-I:%M%p" 2>/dev/null \
      || date -d "$five_hour_resets_at" "+%-I:%M%p" 2>/dev/null \
      || echo "")
    has_resets_time=false
    [ -n "$resets_time" ] && has_resets_time=true
    if $has_resets_time; then
      rate_str="$rate_str resets ${resets_time}"
    fi
  fi
fi

right_suffix_parts=()
[ -n "$cost_str" ] && right_suffix_parts+=("$cost_str")
[ -n "$rate_str" ] && right_suffix_parts+=("$rate_str")
right_suffix="${right_suffix_parts[*]}"

# Layout calculation
left_str="${left_parts[*]}"
terminal_width=$(( ${COLUMNS:-$(tput cols 2>/dev/null || echo 80)} - 4 ))
left_len=$(visible_len "$left_str")
right_suffix_len=$(visible_len "$right_suffix")

has_right_suffix=false
[ -n "$right_suffix" ] && has_right_suffix=true
suffix_sep=0
$has_right_suffix && suffix_sep=1

# Responsive bar: 7 = "[" + "] " + "100%" (max 4 digits+%)
bar_min=5
bar_max=20
bar_overhead=7
bar_total=$(( terminal_width - left_len - right_suffix_len - suffix_sep - bar_overhead ))
[ "$bar_total" -gt "$bar_max" ] && bar_total=$bar_max
[ "$bar_total" -lt "$bar_min" ] && bar_total=$bar_min

# Build progress bar
bar_str=""
has_used_percentage=false
[ -n "$used_percentage" ] && has_used_percentage=true
if $has_used_percentage; then
  used_int=$(printf '%.0f' "$used_percentage")
  filled=$(( used_int * bar_total / 100 ))
  empty=$(( bar_total - filled ))
  bar=""
  for i in $(seq 1 $filled); do bar="${bar}█"; done
  for i in $(seq 1 $empty); do bar="${bar}░"; done
  bar_str="[${bar}] ${used_int}%"
fi

# Assemble right_str
if [ -n "$bar_str" ] && $has_right_suffix; then
  right_str="${bar_str} ${right_suffix}"
elif [ -n "$bar_str" ]; then
  right_str="$bar_str"
elif $has_right_suffix; then
  right_str="$right_suffix"
else
  right_str=""
fi

try_print() {
  local right="$1"
  local right_len
  right_len=$(visible_len "$right")
  local pad=$(( terminal_width - left_len - right_len ))
  local is_positive=false
  [ "$pad" -ge 0 ] && is_positive=true
  if $is_positive; then
    printf '%s%*s%s' "$left_str" "$pad" "" "$right"
    return 0
  fi
  return 1
}

right_no_resets=$(printf '%s' "$right_str" | sed 's/ resets [^ ]*//')
right_no_cost=$(printf '%s' "$right_no_resets" | sed 's/ | \$[0-9,.]*//')

if try_print "$right_str"; then
  :
elif try_print "$right_no_resets"; then
  :
elif try_print "$right_no_cost"; then
  :
else
  printf '%s %s' "$left_str" "$right_no_cost"
fi

#!/usr/bin/env bash
# Checks this repository's Architecture Decision Records: each record's name,
# heading, sections and status, the index in its folder's README, the relative
# links in every file agents read, and every place code or docs cite a record.
# Installed by the adr-setup skill, whose tests cover every rule here. Needs
# bash, git and a POSIX awk; runs on bash 3.2 (macOS) and mawk (Ubuntu) too.
#
#   scripts/adr.sh                  check
#   scripts/adr.sh --base <commit>  also check merged records against <commit>
#   scripts/adr.sh --fix            regenerate the indexes, then check
#   scripts/adr.sh new "<title>"    create a record from the template
#
# The awk programs are single-quoted on purpose: bash must not expand them.
# shellcheck disable=SC2016
set -euo pipefail
export LC_ALL=C

# Folders that hold records, relative to the repository root.
ADR_DIRS=(docs/adr)

# Files agents read as instructions. Every relative link in them must resolve.
GUIDE='(^|/)(AGENTS|CLAUDE|GEMINI)\.md$|^(README|CONTRIBUTING)\.md$|^\.github/copilot-instructions\.md$|^\.cursor/rules/|^\.claude/.+\.md$'

WORD_LIMIT=800
SKIPPED_DIRECTORY='(^|/)(node_modules|vendor|\.git|dist|build|coverage|target|\.venv|venv|__pycache__|\.next|\.turbo)/'
SKIPPED_FILE='(^|/)(package-lock\.json|npm-shrinkwrap\.json|pnpm-lock\.yaml|yarn\.lock|bun\.lockb?|Gemfile\.lock|Cargo\.lock|poetry\.lock|uv\.lock|composer\.lock|go\.sum|mix\.lock|Podfile\.lock)$'
CITATION_CANDIDATE='[0-9]{12}-[a-z0-9]|ADR[- #]?[0-9]'
LARGEST_SCANNED_FILE=1048576

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
root=$(git -C "$here" rev-parse --show-toplevel 2>/dev/null) || root=$(cd "$here/.." && pwd -P)
script=${here#"$root"/}/$(basename "${BASH_SOURCE[0]}")
fix_hint="; run $script --fix"
cd "$root"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
: >"$work/violations"
: >"$work/warnings"

violation() { printf '%s\n' "$1" >>"$work/violations"; }
# A warning has a path, a line number or "-", and a message.
warning() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >>"$work/warnings"; }

# Functions every awk program below shares. Data comes in through ENVIRON,
# never -v, so awk does not read backslashes in titles as escapes.
AWK_LIB='
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function replace_all(s, from, to,   out, at) {
  out = ""
  while ((at = index(s, from)) > 0) { out = out substr(s, 1, at - 1) to; s = substr(s, at + length(from)) }
  return out s
}
function stem_of(file) { sub(/\.md$/, "", file); return file }
function valid_record_name(file,   month, day, hour, minute) {
  if (file !~ /^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[a-z0-9]+(-[a-z0-9]+)*\.md$/) return 0
  month = substr(file, 5, 2) + 0; day = substr(file, 7, 2) + 0
  hour = substr(file, 9, 2) + 0; minute = substr(file, 11, 2) + 0
  return month >= 1 && month <= 12 && day >= 1 && day <= 31 && hour <= 23 && minute <= 59
}
function in_records(path,   count, dirs, i) {
  count = split(ENVIRON["ALL_DIRS"], dirs, "\n")
  for (i = 1; i <= count; i++) if (dirs[i] != "" && index(path, dirs[i] "/") == 1) return 1
  return 0
}
# Drops the comments that open on this line; in_comment carries one that does
# not closing onto the next line.
function drop_comments(text,   open, rest, closing) {
  while ((open = index(text, "<!--")) > 0) {
    rest = substr(text, open + 4)
    closing = index(rest, "-->")
    if (!closing) { text = substr(text, 1, open - 1); in_comment = 1; break }
    text = substr(text, 1, open - 1) substr(rest, closing + 3)
  }
  return text
}
function uncomment(text,   closing) {
  if (in_comment) {
    closing = index(text, "-->")
    if (!closing) return ""
    text = substr(text, closing + 3); in_comment = 0
  }
  return drop_comments(text)
}
# What markdown renders as prose: no comments, no fenced or inline code.
function prose(text,   closing) {
  if (in_comment) {
    closing = index(text, "-->")
    if (!closing) return ""
    text = substr(text, closing + 3); in_comment = 0
  } else if (text ~ /^[ \t]*(```|~~~)/) {
    in_fence = !in_fence
    return ""
  }
  if (in_fence) return ""
  text = drop_comments(text)
  gsub(/`[^`]*`/, "", text)
  return text
}
# Sets R_title, R_sections ("|"-joined), R_has_status, R_status_text,
# R_status and R_by (the file that superseded it) for the record at path.
function parse_record(path,   line, section, in_status, joined, parts, target) {
  R_title = ""; R_sections = "|"; R_has_status = 0; R_status_text = ""; R_status = ""; R_by = ""
  title_found = 0; in_status = 0; in_comment = 0; joined = ""; parts = 0
  while ((getline line < path) > 0) {
    sub(/\r$/, "", line)
    if (!title_found && line ~ /^# ./) { R_title = trim(substr(line, 3)); title_found = 1 }
    if (substr(line, 1, 3) == "## ") {
      section = trim(substr(line, 4))
      in_status = section == "Status" && !R_has_status
      if (in_status) R_has_status = 1
      R_sections = R_sections section "|"
      continue
    }
    if (in_status) { joined = (parts++ ? joined " " : "") uncomment(line) }
  }
  close(path)
  if (!R_has_status) return
  gsub(/[ \t]+/, " ", joined)
  R_status_text = trim(joined)
  if (R_status_text ~ /^(Proposed|Accepted|Rejected|Deprecated)$/) {
    R_status = R_status_text
  } else if (R_status_text ~ /^Superseded by \[[^]]+\]\((\.\/)?[^) \t]+\)$/) {
    target = R_status_text
    sub(/^.*\]\(/, "", target); sub(/\)$/, "", target); sub(/^\.\//, "", target)
    R_status = "Superseded"; R_by = target
  }
}
# The record without its Status section, trailing empty lines dropped.
function without_status(path,   line, out, status, pending) {
  out = ""; status = 0; pending = ""
  while ((getline line < path) > 0) {
    sub(/\r$/, "", line)
    if (substr(line, 1, 3) == "## ") status = trim(substr(line, 4)) == "Status"
    if (status) continue
    if (line == "") { pending = pending "\n"; continue }
    out = out pending line "\n"; pending = ""
  }
  close(path)
  return out
}
'

# Reads every record, then checks them, their indexes, links and citations;
# with MODE=fix, writes the indexes instead.
CHECK_AWK='
function v(message) { print "V\t" message }
function load_records(   entry, part, count) {
  count = 0
  while ((getline entry < ENVIRON["RECORDS"]) > 0) {
    split(entry, part, "\t")
    count++
    rdir[count] = part[1]; rfile[count] = part[2]; rpath[count] = part[1] "/" part[2]
    parse_record(rpath[count])
    rtitle[count] = R_title; rsections[count] = R_sections; rhas_status[count] = R_has_status
    rstatus_text[count] = R_status_text; rstatus[count] = R_status; rby[count] = R_by
    by_key[part[1] "\t" part[2]] = count
    by_stem[stem_of(part[2])] = count
  }
  close(ENVIRON["RECORDS"])
  return count
}
function superseder(i) { return (rdir[i] "\t" rby[i]) in by_key ? by_key[rdir[i] "\t" rby[i]] : 0 }
function check_records(   i, j, s, sections, path) {
  split("Status Context Decision Consequences", sections, " ")
  for (i = 1; i <= records; i++) {
    path = rpath[i]
    if (rtitle[i] == "") v(path ": has no \"# <decision title>\" heading")
    else if (index(rtitle[i], "{{")) v(path ": the heading is still the template'"'"'s placeholder")
    for (s = 1; s <= 4; s++) if (!index(rsections[i], "|" sections[s] "|")) v(path ": has no \"## " sections[s] "\" section")
    if (rhas_status[i] && rstatus_text[i] == "") v(path ": the Status section is empty")
    else if (rhas_status[i] && rstatus[i] == "") v(path ": status \"" rstatus_text[i] "\" is not Proposed, Accepted, Rejected, Deprecated, or Superseded by [title](./file.md)")
    if (rstatus[i] != "Superseded") continue
    j = superseder(i)
    if (!j) v(path ": superseded by " rby[i] ", which is not a record in this folder")
    else if (j == i) v(path ": superseded by itself")
    else if (substr(rfile[j], 1, 12) < substr(rfile[i], 1, 12)) v(path ": superseded by " rfile[j] ", which is older")
    else if (rstatus[j] == "Proposed" || rstatus[j] == "Rejected") v(path ": superseded by " rfile[j] ", which is " tolower(rstatus[j]) "; only a decision in effect replaces one")
  }
}
function escape_cell(text) { return replace_all(text, "|", "\\|") }
function status_cell(i,   j, title) {
  if (rstatus[i] != "Superseded") return rstatus_text[i]
  j = superseder(i)
  title = j && rtitle[j] != "" ? rtitle[j] : stem_of(rby[i])
  return "Superseded by [" title "](./" rby[i] ")"
}
# Fills expected[1..n] with the index rows for dir and returns n.
function index_rows(dir,   i, count) {
  count = 0
  for (i = 1; i <= records; i++) {
    if (rdir[i] != dir) continue
    expected[++count] = substr(rfile[i], 1, 4) "-" substr(rfile[i], 5, 2) "-" substr(rfile[i], 7, 2) \
      " | [" escape_cell(rtitle[i] != "" ? rtitle[i] : stem_of(rfile[i])) "](./" rfile[i] ")" \
      " | " escape_cell(status_cell(i))
  }
  return count
}
function read_lines(path,   line, count) {
  count = 0
  while ((getline line < path) > 0) { sub(/\r$/, "", line); L[++count] = line }
  close(path)
  return count
}
function starts_row(line) { sub(/^[ \t]+/, "", line); return substr(line, 1, 1) == "|" }
# Finds the index table in L[1..n]: sets T_heading, T_end, T_start, T_stop
# (0 when there is none). The table is the first run of "|" lines between
# "## Index" and the next heading.
function index_table(n,   i) {
  T_heading = 0; T_end = n + 1; T_start = 0; T_stop = 0
  for (i = 1; i <= n; i++) if (trim(L[i]) == "## Index") { T_heading = i; break }
  if (!T_heading) return
  for (i = T_heading + 1; i <= n; i++) if (L[i] ~ /^##? /) { T_end = i; break }
  for (i = T_heading + 1; i < T_end; i++) if (starts_row(L[i])) { T_start = i; break }
  if (!T_start) return
  for (T_stop = T_start; T_stop < T_end && starts_row(L[T_stop]); T_stop++) ;
}
function row_text(line,   count, parts, i, cell, out) {
  line = trim(line); sub(/^\|/, "", line); sub(/\|$/, "", line)
  line = replace_all(line, "\\|", "\001")
  count = split(line, parts, "|")
  out = ""; separator = 1
  for (i = 1; i <= count; i++) {
    cell = parts[i]; gsub(/[ \t]+/, " ", cell); cell = replace_all(trim(cell), "\001", "\\|")
    if (cell !~ /^:?-+:?$/) separator = 0
    cells[i] = cell
    out = out (i > 1 ? " | " : "") cell
  }
  cell_count = count
  return out
}
function linked_file(row,   cell) {
  row_text(row)
  cell = cell_count >= 2 ? cells[2] : ""
  if (!match(cell, /\]\([^) \t]+\)/)) return ""
  cell = substr(cell, RSTART + 2, RLENGTH - 3)
  sub(/^\.\//, "", cell)
  return cell
}
function check_index(dir,   path, n, rows, count, i, text, same, problems, file, row_for, files) {
  path = dir "/README.md"
  if ((getline probe < path) < 0) { v(path ": is missing; it holds the index"); return }
  close(path)
  n = read_lines(path)
  index_table(n)
  if (!T_heading) { v(path ": has no \"## Index\" section" ENVIRON["FIX_HINT"]); return }
  if (!T_start) { v(path ": the Index section has no table" ENVIRON["FIX_HINT"]); return }
  rows = 0
  for (i = T_start + 1; i < T_stop; i++) {
    text = row_text(L[i])
    if (separator) continue
    actual[++rows] = text
    actual_line[rows] = L[i]
  }
  count = index_rows(dir)
  same = rows == count
  for (i = 1; same && i <= count; i++) if (actual[i] != expected[i]) same = 0
  if (same) return
  problems = 0
  split("", row_for); split("", files)
  for (i = 1; i <= rows; i++) row_for[linked_file(actual_line[i])] = actual[i]
  for (i = 1; i <= count; i++) {
    file = linked_file("|" expected[i] "|")
    files[file] = 1
    if (!(file in row_for)) { v(path ": the index has no row for " file ENVIRON["FIX_HINT"]); problems++ }
    else if (row_for[file] != expected[i]) {
      v(path ": the index row for " file " reads \"" row_for[file] "\", the record says \"" expected[i] "\"" ENVIRON["FIX_HINT"]); problems++
    }
  }
  for (i = 1; i <= rows; i++) {
    file = linked_file(actual_line[i])
    if (file == "" || !(file in files)) { v(path ": the index lists " (file != "" ? file : actual[i]) ", which is not a record" ENVIRON["FIX_HINT"]); problems++ }
  }
  if (!problems) v(path ": the index rows are out of order, oldest first" ENVIRON["FIX_HINT"])
}
function fix_index(dir, out,   path, n, count, i, at, m) {
  path = dir "/README.md"
  if ((getline probe < path) < 0) return
  close(path)
  n = read_lines(path)
  count = index_rows(dir)
  table[1] = "| Date | Decision | Status |"; table[2] = "| --- | --- | --- |"
  for (i = 1; i <= count; i++) table[i + 2] = "| " expected[i] " |"
  count += 2
  index_table(n)
  m = 0
  if (!T_heading) {
    while (n > 0 && trim(L[n]) == "") n--
    for (i = 1; i <= n; i++) O[++m] = L[i]
    O[++m] = ""; O[++m] = "## Index"; O[++m] = ""
    for (i = 1; i <= count; i++) O[++m] = table[i]
  } else if (!T_start) {
    at = T_end
    while (at - 1 > T_heading && trim(L[at - 1]) == "") at--
    for (i = 1; i < at; i++) O[++m] = L[i]
    O[++m] = ""
    for (i = 1; i <= count; i++) O[++m] = table[i]
    if (at <= n && L[at] != "") O[++m] = ""
    for (i = at; i <= n; i++) O[++m] = L[i]
  } else {
    for (i = 1; i < T_start; i++) O[++m] = L[i]
    for (i = 1; i <= count; i++) O[++m] = table[i]
    for (i = T_stop; i <= n; i++) O[++m] = L[i]
  }
  for (i = 1; i <= m; i++) print O[i] > out
  close(out)
  print "F\t" path "\t" out
}
# Prints an L line for every relative link target in a document.
function extract_links(path,   line, rest, target, file, at) {
  in_comment = 0; in_fence = 0
  while ((getline line < path) > 0) {
    sub(/\r$/, "", line)
    line = prose(line)
    rest = line
    while (match(rest, /\]\([ \t]*/)) {
      rest = substr(rest, RSTART + RLENGTH)
      if (substr(rest, 1, 1) == "<" && (at = index(rest, ">")) > 0) {
        target = substr(rest, 2, at - 2); rest = substr(rest, at + 1)
      } else if (match(rest, /^[^) \t]+/)) {
        target = substr(rest, 1, RLENGTH); rest = substr(rest, RLENGTH + 1)
      } else continue
      link(path, target)
    }
    if (match(line, /^ ? ? ?\[[^]^][^]]*\]:[ \t]*/)) {
      rest = substr(line, RSTART + RLENGTH)
      if (substr(rest, 1, 1) == "<" && (at = index(rest, ">")) > 0) link(path, substr(rest, 2, at - 2))
      else if (match(rest, /^[^ \t>]+/)) link(path, substr(rest, 1, RLENGTH))
    }
  }
  close(path)
}
function link(path, target,   file, at) {
  if (target ~ /^[A-Za-z][A-Za-z0-9+.-]*:/ || substr(target, 1, 2) == "//") return
  file = target
  if ((at = index(file, "#")) > 0) file = substr(file, 1, at - 1)
  if ((at = index(file, "?")) > 0) file = substr(file, 1, at - 1)
  file = replace_all(file, "%20", " ")
  if (file == "") return
  print "L\t" path "\t" target "\t" file
}
function word_char(c) { return c ~ /^[A-Za-z0-9_]$/ }
function check_citations(path,   line, number, inside, pos, rest, stem, before, after, i) {
  inside = in_records(path)
  number = 0
  while ((getline line < path) > 0) {
    sub(/\r$/, "", line)
    number++
    for (pos = 1; match(rest = substr(line, pos), /[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[a-z0-9]+(-[a-z0-9]+)*/); ) {
      start = pos + RSTART - 1
      stem = substr(rest, RSTART, RLENGTH)
      before = start > 1 ? substr(line, start - 1, 1) : ""
      after = substr(line, start + RLENGTH, 1)
      if (word_char(before) || before == "-" || word_char(after) || after == "-") { pos = start + 1; continue }
      pos = start + RLENGTH
      citations++
      if (!(stem in by_stem)) { v(path ":" number ": cites " stem ", which is not a record"); continue }
      i = by_stem[stem]
      if (inside) continue
      if (rstatus[i] == "Superseded")
        print "W\t" path "\t" number "\tcites " stem ", which is superseded by " stem_of(rby[i]) "; cite the record that stands, or drop the reference"
      else if (rstatus[i] == "Deprecated")
        print "W\t" path "\t" number "\tcites " stem ", which is deprecated; drop the reference, or cite what replaced it"
    }
    for (pos = 1; match(rest = substr(line, pos), /ADR[- #]?[0-9]+/); ) {
      start = pos + RSTART - 1
      stem = substr(rest, RSTART, RLENGTH)
      before = start > 1 ? substr(line, start - 1, 1) : ""
      after = substr(line, start + RLENGTH, 1)
      digits = stem; sub(/^ADR[- #]?/, "", digits)
      if (word_char(before) || word_char(after) || length(digits) > 4) { pos = start + 1; continue }
      pos = start + RLENGTH
      citations++
      v(path ":" number ": cites " stem ", but records are named by timestamp, not number; cite the record'"'"'s file name")
    }
  }
  close(path)
}
function check_unread_folders(   path, folder, name, count, dirs, i, reported) {
  count = split(ENVIRON["ALL_DIRS"], dirs, "\n")
  for (i = 1; i <= count; i++) reported[dirs[i]] = 1
  while ((getline path < ENVIRON["FILES"]) > 0) {
    folder = path; name = path
    if (!sub(/\/[^\/]*$/, "", folder)) folder = "."
    sub(/^.*\//, "", name)
    if (folder in reported) continue
    if (folder ~ /(^|\/)(adr|adrs|decisions)$/ && valid_record_name(name)) {
      reported[folder] = 1
      v(folder ": holds records the check does not read; add it to ADR_DIRS in " ENVIRON["SCRIPT"])
    }
  }
  close(ENVIRON["FILES"])
}
BEGIN {
  records = load_records()
  dir_count = split(ENVIRON["EXISTING_DIRS"], dirs, "\n")
  if (ENVIRON["MODE"] == "fix") {
    for (d = 1; d <= dir_count; d++) if (dirs[d] != "") fix_index(dirs[d], ENVIRON["WORK"] "/readme." d)
    exit
  }
  print "R\t" records
  check_records()
  for (d = 1; d <= dir_count; d++) if (dirs[d] != "") check_index(dirs[d])
  check_unread_folders()
  while ((getline path < ENVIRON["DOCUMENTS"]) > 0) extract_links(path)
  citations = 0
  while ((getline path < ENVIRON["CANDIDATES"]) > 0) check_citations(path)
  print "C\t" citations
}
'

# Compares a merged record (BEFORE, as of the base) with the working tree
# (AFTER), and prints a violation for each way it broke immutability.
HISTORY_AWK='
function allowed(from, to) {
  if (from == "Proposed") return to ~ /^(Proposed|Accepted|Rejected)$/
  if (from == "Accepted") return to ~ /^(Accepted|Deprecated|Superseded)$/
  if (from == "Deprecated") return to ~ /^(Deprecated|Superseded)$/
  return to == from
}
function onward(from) {
  if (from == "Proposed") return "from Proposed it goes to Accepted or Rejected"
  if (from == "Accepted") return "from Accepted it goes to Deprecated or Superseded"
  if (from == "Deprecated") return "from Deprecated it goes to Superseded"
  return from " is final"
}
BEGIN {
  path = ENVIRON["RECORD"]
  if (without_status(ENVIRON["BEFORE"]) != without_status(path))
    print "V\t" path ": a merged record changes only in its Status section; write a new record that supersedes it"
  parse_record(ENVIRON["BEFORE"]); was = R_status; was_by = R_by
  parse_record(path); is = R_status; is_by = R_by
  if (was == "" || is == "") exit
  if (!allowed(was, is))
    print "V\t" path ": a merged record does not go from " was " to " is "; " onward(was)
  else if (was == "Superseded" && was_by != is_by)
    print "V\t" path ": a merged record keeps the record that superseded it (" was_by ")"
}
'

WORDS_AWK='
BEGIN {
  text = without_status(ENVIRON["RECORD"])
  count = split(text, lines, "\n")
  in_comment = 0; words = 0
  for (i = 1; i <= count; i++) words += split(uncomment(lines[i]), parts)
  print words
}
'

NEW_AWK='
BEGIN {
  while ((getline line < ENVIRON["TEMPLATE"]) > 0) {
    sub(/\r$/, "", line)
    if (!done && line ~ /^# /) { line = "# " ENVIRON["TITLE"]; done = 1 }
    print line
  }
}
'

run_awk() { awk "$AWK_LIB$1"; }

valid_name() {
  local pattern='^[0-9]{4}([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})-[a-z0-9]+(-[a-z0-9]+)*\.md$'
  [[ $1 =~ $pattern ]] || return 1
  local month=$((10#${BASH_REMATCH[1]})) day=$((10#${BASH_REMATCH[2]}))
  local hour=$((10#${BASH_REMATCH[3]})) minute=$((10#${BASH_REMATCH[4]}))
  ((month >= 1 && month <= 12 && day >= 1 && day <= 31 && hour <= 23 && minute <= 59))
}

in_records() {
  local dir
  for dir in "${ADR_DIRS[@]}"; do
    case $1 in "$dir"/*) return 0 ;; esac
  done
  return 1
}

joined_dirs() { printf '%s\n' "${ADR_DIRS[@]}"; }

existing_dirs() {
  local dir
  for dir in "${ADR_DIRS[@]}"; do
    if [ -d "$dir" ]; then printf '%s\n' "$dir"; fi
  done
}

# Lists the records into $work/records as "<dir>\t<file>", and reports the
# folders and file names that are not records.
list_records() {
  local dir path file count
  : >"$work/records"
  shopt -s nullglob dotglob
  for dir in "${ADR_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
      violation "$dir: is in ADR_DIRS but does not exist"
      continue
    fi
    count=0
    for path in "$dir"/*.md; do
      [ -f "$path" ] || continue
      file=${path##*/}
      case $file in README.md | template.md) continue ;; esac
      if ! valid_name "$file"; then
        violation "$path: a record is named YYYYMMDDHHMM-<decision-slug>.md"
        continue
      fi
      printf '%s\t%s\n' "$dir" "$file" >>"$work/records"
      count=$((count + 1))
    done
    if [ "$count" -eq 0 ]; then
      violation "$dir: holds no records; the check would pass on nothing"
    fi
  done
  shopt -u nullglob dotglob
}

# Tracked and untracked-but-not-ignored files, or every file outside git.
list_files() {
  {
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      git ls-files -z --cached --others --exclude-standard | tr '\0' '\n'
    else
      find . -type f | sed 's|^\./||'
    fi
  } | sort -u | { grep -Ev "$SKIPPED_DIRECTORY" || true; } | { grep -Ev "$SKIPPED_FILE" || true; } |
    while IFS= read -r path; do
      if [ -f "$path" ]; then printf '%s\n' "$path"; fi
    done
}

# Text files no larger than LARGEST_SCANNED_FILE that may cite a record.
list_candidates() {
  [ -s "$work/files" ] || return 0
  { tr '\n' '\0' <"$work/files" | xargs -0 grep -lIE "$CITATION_CANDIDATE" -- 2>/dev/null || true; } |
    while IFS= read -r path; do
      local size
      size=$(wc -c <"$path")
      if [ $((size)) -le "$LARGEST_SCANNED_FILE" ]; then printf '%s\n' "$path"; fi
    done
}

list_documents() {
  cut -f1,2 "$work/records" | tr '\t' '/'
  local dir
  while IFS= read -r dir; do
    if [ -f "$dir/README.md" ]; then printf '%s\n' "$dir/README.md"; fi
  done < <(existing_dirs)
  { grep -E "$GUIDE" "$work/files" || true; } | while IFS= read -r path; do
    if ! in_records "$path"; then printf '%s\n' "$path"; fi
  done
}

check_awk() {
  RECORDS="$work/records" FILES="$work/files" DOCUMENTS="$work/documents" CANDIDATES="$work/candidates" \
    ALL_DIRS="$(joined_dirs)" EXISTING_DIRS="$(existing_dirs)" WORK="$work" MODE="$1" \
    FIX_HINT="$fix_hint" SCRIPT="$script" run_awk "$CHECK_AWK"
}

fix() {
  list_records
  : >"$work/files"
  : >"$work/documents"
  : >"$work/candidates"
  local kind path out
  check_awk fix | while IFS=$'\t' read -r kind path out; do
    if [ "$kind" = F ]; then cat "$out" >"$path"; fi
  done
}

records=0
links=0
citations=0

check() {
  : >"$work/violations"
  list_records
  list_files >"$work/files"
  list_documents >"$work/documents"
  list_candidates >"$work/candidates"
  check_awk check >"$work/out"
  local kind a b c candidate
  while IFS=$'\t' read -r kind a b c; do
    case $kind in
      R) records=$a ;;
      C) citations=$a ;;
      V) violation "$a" ;;
      W) warning "$a" "$b" "$c" ;;
      L)
        links=$((links + 1))
        case $c in
          /*) candidate=$root$c ;;
          *) candidate=$(dirname "$a")/$c ;;
        esac
        if [ ! -e "$candidate" ]; then violation "$a: links to $b, which does not exist"; fi
        ;;
    esac
  done <"$work/out"
}

check_history() {
  local base=$1 path file dir words
  if [ -z "$base" ] || ! git rev-parse --verify --quiet "$base^{commit}" >/dev/null 2>&1; then
    violation "--base $base: not a commit in this clone; fetch it, or run without --base"
    return
  fi
  : >"$work/merged"
  git ls-tree -r -z --name-only "$base" -- "${ADR_DIRS[@]}" | tr '\0' '\n' | sort |
    while IFS= read -r path; do
      for dir in "${ADR_DIRS[@]}"; do
        if [ "${path%/*}" = "$dir" ] && valid_name "${path##*/}"; then printf '%s\n' "$path"; fi
      done
    done >"$work/merged"
  while IFS= read -r path; do
    if [ ! -e "$path" ]; then
      violation "$path: a merged record is never deleted or renamed; supersede it with a new record"
      continue
    fi
    git show "$base:$path" >"$work/before"
    BEFORE="$work/before" RECORD="$path" run_awk "$HISTORY_AWK" | while IFS=$'\t' read -r kind message; do
      printf '%s\n' "$message"
    done >>"$work/violations"
  done <"$work/merged"
  shopt -s nullglob dotglob
  while IFS= read -r dir; do
    for path in "$dir"/*; do
      file=${path##*/}
      valid_name "$file" || continue
      if grep -qxF "$path" "$work/merged"; then continue; fi
      words=$(RECORD="$path" run_awk "$WORDS_AWK")
      if [ "$words" -gt "$WORD_LIMIT" ]; then
        warning "$path" - "$words words, over $WORD_LIMIT; one decision per record, and what the change did goes in the pull request"
      fi
    done
  done < <(existing_dirs)
  shopt -u nullglob dotglob
}

slug_of() {
  local ascii
  # macOS iconv transliterates and still exits 1, so keep whatever it printed.
  ascii=$(printf '%s' "$1" | LC_ALL=C.UTF-8 iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null || true)
  if [ -z "$ascii" ]; then ascii=$1; fi
  # Slugs are ASCII by design; iconv already folded accents.
  # shellcheck disable=SC2018,SC2019
  printf '%s' "$ascii" | tr -d "'\"^~\`" | tr 'A-Z' 'a-z' |
    sed -e 's/[^a-z0-9][^a-z0-9]*/-/g' -e 's/^-*//' -e 's/-*$//'
}

fail() {
  printf 'adr: %s\n' "$1" >&2
  exit 1
}

create() {
  local dir=${ADR_DIRS[0]} picked=0 title='' word
  local argc=$#
  while [ $# -gt 0 ]; do
    case $1 in
      --dir)
        dir=${2-}
        picked=1
        if [ $# -gt 1 ]; then shift; fi
        ;;
      *) title="$title${title:+ }$1" ;;
    esac
    shift
  done
  title=$(printf '%s' "$title" | sed -e 's/^[[:blank:]]*//' -e 's/[[:blank:]]*$//')
  if [ -z "$title" ]; then
    printf 'usage: %s new [--dir <folder>] "<decision title>"\n\nfolders: %s\n' "$script" "$(joined_dirs | paste -sd, - | sed 's/,/, /g')"
    if [ "$argc" -gt 0 ]; then exit 1; fi
    exit 0
  fi
  if [ "$picked" -eq 0 ] && [ "${#ADR_DIRS[@]}" -gt 1 ]; then
    fail "pick a folder with --dir: $(joined_dirs | paste -sd, - | sed 's/,/, /g')"
  fi
  in_list=0
  for word in "${ADR_DIRS[@]}"; do
    if [ "$word" = "$dir" ]; then in_list=1; fi
  done
  if [ "$in_list" -eq 0 ]; then
    fail "$dir is not in ADR_DIRS ($(joined_dirs | paste -sd, - | sed 's/,/, /g'))"
  fi
  local slug
  slug=$(slug_of "$title")
  if [ -z "$slug" ]; then fail 'the title has no letters or digits to name the file'; fi
  local template="$dir/template.md"
  if [ ! -f "$template" ]; then fail "$template is missing"; fi
  if ! grep -q '^# ' "$template"; then fail "$template has no \"# \" heading to fill"; fi
  local path
  path="$dir/$(date +%Y%m%d%H%M)-$slug.md"
  if [ -e "$path" ]; then fail "$path already exists"; fi
  TEMPLATE="$template" TITLE="$title" run_awk "$NEW_AWK" >"$path"
  fix
  printf 'adr: created %s; fill in Context, Decision and Consequences\n' "$path"
}

print_warning() {
  local path=$1 line=$2 message=$3
  if [ "${GITHUB_ACTIONS-}" = true ]; then
    if [ "$line" = - ]; then
      printf '::warning file=%s::%s\n' "$path" "$message" >&2
    else
      printf '::warning file=%s,line=%s::%s\n' "$path" "$line" "$message" >&2
    fi
  elif [ "$line" = - ]; then
    printf '  ! %s: %s\n' "$path" "$message" >&2
  else
    printf '  ! %s:%s: %s\n' "$path" "$line" "$message" >&2
  fi
}

main() {
  if [ "${1-}" = new ]; then
    shift
    create "$@"
    return
  fi
  local fix_first=0 history=0 base=''
  while [ $# -gt 0 ]; do
    case $1 in
      --fix) fix_first=1 ;;
      --base)
        history=1
        base=${2-}
        if [ $# -gt 1 ]; then shift; fi
        ;;
    esac
    shift
  done
  if [ "$fix_first" -eq 1 ]; then fix; fi
  check
  printf 'adr: %s records in %s folder(s), %s links, %s citations\n' "$records" "${#ADR_DIRS[@]}" "$links" "$citations"
  if [ "$history" -eq 1 ]; then check_history "$base"; fi
  local path line message
  while IFS=$'\t' read -r path line message; do
    print_warning "$path" "$line" "$message"
  done <"$work/warnings"
  local count
  count=$(wc -l <"$work/violations")
  count=$((count))
  if [ "$count" -gt 0 ]; then
    sed 's/^/  ✗ /' "$work/violations" >&2
    printf 'adr: %s violation(s)\n' "$count" >&2
    exit 1
  fi
}

main "$@"

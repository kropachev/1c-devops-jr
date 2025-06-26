#!/usr/bin/env bash
set -e

docs_dir="docs"
output_page="hugo-site/content/p/wiki.md"
sidebar_file="$docs_dir/_Sidebar.md"

mkdir -p "$(dirname "$output_page")"

cat > "$output_page" <<EOT
+++
title = "Документация"
toc = true
+++

EOT

while IFS='' read -r line || [[ -n "$line" ]]; do
  [[ -z "${line//[[:space:]]/}" ]] && continue

  indent=$(( ${#line} - ${#line##[ ]*} ))
  level=$(( indent / 2 ))

  if [[ "$line" =~ \[([^]]+)\]\(([^)]+)\) ]]; then
    title="${BASH_REMATCH[1]}"
    filepath="${BASH_REMATCH[2]}"
    filepath="${filepath#/}"
    filepath="${filepath#docs/}"
    [[ "$filepath" != *.md ]] && filepath="${filepath}.md"

    heading_marks=$(printf '%0.s#' $(seq 1 $(( level + 2 ))))
    echo "${heading_marks} ${title}" >> "$output_page"
    echo "" >> "$output_page"

    file_path="$docs_dir/$filepath"
    if [[ -f "$file_path" ]]; then
      awk 'NR==1 { if($1 ~ /^#+$/) { next } }
           /^#{1,5} / { sub(/^#/, "##"); }
           { print }' "$file_path" >> "$output_page"
    else
      echo "_Файл '$filepath' не найден в docs/_Sidebar.md. Проверьте регистр или путь._" >> "$output_page"
    fi
    echo "" >> "$output_page"

  else
    section_title="${line##* }"
    heading_marks=$(printf '%0.s#' $(seq 1 $(( level + 2 ))))
    echo "${heading_marks} ${section_title}" >> "$output_page"
    echo "" >> "$output_page"
  fi
done < "$sidebar_file"

if [[ -d "$docs_dir/images" ]]; then
  mkdir -p hugo-site/static/p/wiki/images
  cp -R "$docs_dir/images/"* hugo-site/static/p/wiki/images/ 2>/dev/null || true
fi

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
  # пропускаем пустые строки
  [[ -z "${line//[[:space:]]/}" ]] && continue

  # считаем уровень вложенности по числу ведущих пробелов
  leading_spaces="${line%%[^ ]*}"
  indent=${#leading_spaces}
  level=$(( indent / 2 ))
  heading_marks=$(printf '%0.s#' $(seq 1 $(( level + 2 ))))

  # проверяем наличие Markdown-ссылки
  if echo "$line" | grep -qE '\[.*\]\(.*\)'; then
    title=$(echo "$line" | sed -E 's/^\s*[-*]?\s*\[(.*)\]\(.*\).*/\1/')
    filepath=$(echo "$line" | sed -E 's/.*\((.*)\).*/\1/')
    filepath="${filepath#/}"
    filepath="${filepath#docs/}"
    [[ "$filepath" != *.md ]] && filepath="${filepath}.md"

    echo "${heading_marks} ${title}" >> "$output_page"
    echo "" >> "$output_page"

    file_path="$docs_dir/$filepath"
    if [[ -f "$file_path" ]]; then
      awk 'NR==1 { if($1 ~ /^#+$/) next }
           /^#{1,5} / { sub(/^#/, "##") }
           { print }' "$file_path" >> "$output_page"
    else
      echo "_Файл '$filepath' не найден._" >> "$output_page"
    fi
    echo "" >> "$output_page"

  else
    section_title=$(echo "$line" | sed -E 's/^\s*[-*]?\s*(.*)/\1/')
    if [[ -n "$section_title" ]]; then
      echo "${heading_marks} ${section_title}" >> "$output_page"
      echo "" >> "$output_page"
    fi
  fi

done < "$sidebar_file"

# копируем изображения
if [[ -d "$docs_dir/images" ]]; then
  rm -rf hugo-site/static/images
  mkdir -p hugo-site/static/images
  cp -R "$docs_dir/images/"* hugo-site/static/images/
fi

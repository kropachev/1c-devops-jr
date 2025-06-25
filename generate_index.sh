#!/usr/bin/env bash
set -e

# Папки исходников и назначений
docs_dir="docs"
output_page="content/p/wiki.md"
sidebar_file="$docs_dir/_Sidebar.md"

# Создаем директорию для выходного файла (если нет)
mkdir -p "$(dirname "$output_page")"

# Записываем начало выходного файла с фронтматтером
cat > "$output_page" <<EOT
+++
title = "Документация"
toc = true
+++

EOT

# Проходим по каждой строке файла _Sidebar.md
while IFS='' read -r line || [[ -n "$line" ]]; do
    # Пропускаем пустые строки
    [[ -z "${line//[[:space:]]/}" ]] && continue
    # Определяем уровень вложенности по числу ведущих пробелов
    leading_spaces=${line%%[^ ]*}
    indent=${#leading_spaces}
    level=$(( indent / 2 ))  # считаем уровень списка (2 пробела = новый уровень)

    # Попробуем извлечь ссылку и заголовок
    link_text=$(echo "$line" | grep -oP '\[.*?\]\(.*?\)' || true)
    if [[ -n "$link_text" ]]; then
        title=$(echo "$link_text" | sed -E 's/^\[(.*)\]\(.*\)$/\1/')
        filepath=$(echo "$link_text" | sed -E 's/^\[.*\]\((.*)\)$/\1/')
        filepath="${filepath#/}"
        filepath="${filepath#docs/}"
        heading_level=$(( 2 + level ))
        heading_marks=$(printf '%0.s#' $(seq 1 $heading_level))
        echo "${heading_marks} ${title}" >> "$output_page"
        echo "" >> "$output_page"
        file_path="$docs_dir/$filepath"
        if [[ -f "$file_path" ]]; then
            awk 'NR==1 { if($1 ~ /^#+$/) { next } }
                 /^#{1,5} / { sub(/^#/, "##"); }
                 { print }' "$file_path" >> "$output_page"
        else
            echo "*Файл '${filepath}' не найден.*" >> "$output_page"
        fi
        echo "" >> "$output_page"
    else
        section_title="${line//* /}"
        section_title="${section_title## }"
        if [[ -n "$section_title" ]]; then
            heading_level=$(( 2 + level ))
            heading_marks=$(printf '%0.s#' $(seq 1 $heading_level))
            echo "${heading_marks} ${section_title}" >> "$output_page"
            echo "" >> "$output_page"
        fi
    fi
done < "$sidebar_file"

# Копируем все изображения из docs/images в статическую папку сайта, чтобы ссылки работали
if [[ -d "$docs_dir/images" ]]; then
    mkdir -p static/p/wiki/images
    cp -R "$docs_dir/images/"* static/p/wiki/images/ 2>/dev/null || true
fi

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
    # Проверяем, содержит ли строка ссылку [Text](path)
    if [[ $line =~ \[([^]]+)\]\(([^)]+)\) ]]; then
        title="${BASH_REMATCH[1]}"     # текст ссылки = заголовок раздела
        filepath="${BASH_REMATCH[2]}"  # путь к файлу
        # Удаляем префикс "docs/" и ведущий слеш, если есть
        filepath="${filepath#/}"
        filepath="${filepath#docs/}"
        # Определяем уровень заголовка для этого пункта (H2 для level=0, H3 для level=1, ...)
        heading_level=$(( 2 + level ))
        heading_marks=$(printf '%0.s#' $(seq 1 $heading_level))
        echo "${heading_marks} ${title}" >> "$output_page"
        echo "" >> "$output_page"
        # Вставляем содержимое соответствующего файла
        file_path="$docs_dir/$filepath"
        if [[ -f "$file_path" ]]; then
            # Пропускаем первую строку, если это заголовок, и увеличиваем уровень остальных заголовков на 1
            awk 'NR==1 { if($1 ~ /^#+$/) { next } }
                 /^#{1,5} / { sub(/^#/, "##"); }
                 { print }' "$file_path" >> "$output_page"
        else
            echo "*Файл '${filepath}' не найден.*" >> "$output_page"
        fi
        echo "" >> "$output_page"
    else
        # Строка без ссылки (может быть название секции в сайдбаре без собственного файла)
        section_title="${line//* /}"   # убираем маркер списка "*" 
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

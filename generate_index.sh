#!/usr/bin/env bash
set -e

DOCS_DIR="docs"
SIDEBAR_FILE="$DOCS_DIR/_Sidebar.md"
OUTPUT_FILE="hugo-site/content/_index.md"

mkdir -p "$(dirname "$OUTPUT_FILE")"

# Start _index.md with required front matter (enable TOC and set up Home menu link)
cat > "$OUTPUT_FILE" << 'EOL'
---
toc: true
menu:
  main:
    name: Home
    weight: -100
    params:
      icon: home
---
EOL

# Append all docs in the order listed in _Sidebar.md
# Extract file names from links in _Sidebar.md (everything between parentheses)
grep -oP '(?<=\().+?(?=\))' "$SIDEBAR_FILE" | while read -r FILE; do
  # Ensure the file has .md extension
  [[ "$FILE" != *.md ]] && FILE="$FILE.md"
  # Concatenate the file content if it exists
  if [[ -f "$DOCS_DIR/$FILE" ]]; then
    # Adjust image paths: make any "](images/..." link root-relative for Hugo
    sed -e 's#\](images/#\](/images/#g' "$DOCS_DIR/$FILE" >> "$OUTPUT_FILE"
    echo -e "\n" >> "$OUTPUT_FILE"   # Add an empty line between files
  fi
done

# Copy images and other static assets from docs to Hugo's static directory
if [[ -d "$DOCS_DIR/images" ]]; then
  rm -rf hugo-site/static/images
  mkdir -p hugo-site/static
  cp -R "$DOCS_DIR/images" hugo-site/static/
fi

# (Optional) Copy any other attachment directories or files from docs to static
for ITEM in "$DOCS_DIR"/*; do
  if [[ -d "$ITEM" && "$(basename "$ITEM")" != "images" ]]; then
    cp -R "$ITEM" hugo-site/static/
  fi
  if [[ -f "$ITEM" && "$ITEM" != *.md ]]; then
    cp "$ITEM" hugo-site/static/
  fi
done

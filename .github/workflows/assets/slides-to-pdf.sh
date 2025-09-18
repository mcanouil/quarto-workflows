#!/usr/bin/env bash

set -e

# if [ -z "${QUARTO_PROJECT_RENDER_ALL}" ]; then
#   exit 0
# fi

HTML_FILES=$(echo "${QUARTO_PROJECT_OUTPUT_FILES}" | tr ' ' '\n' | grep -E '\.html$')

SLIDES_FILES=""
for HTML_FILE in ${HTML_FILES}; do
  if grep -q '<div class="reveal">' "${HTML_FILE}"; then
    SLIDES_FILES="${SLIDES_FILES} ${HTML_FILE}"
  fi
done

SLIDES_FILES=$(echo "${SLIDES_FILES}" | xargs)

if [ "${CI}" == "true" ] && [ -n "${SLIDES_FILES}" ]; then
  mkdir -p release_assets
fi

for SLIDES_PATH in ${SLIDES_FILES}; do
  echo "Processing ${SLIDES_PATH}"

  PDF_AUTHOR=$(grep -o '<meta name="author" content="[^"]*"' "${SLIDES_PATH}" | sed 's/<meta name="author" content="\(.*\)"/\1/')
  PDF_TITLE=$(grep -o '<title>.*</title>' "${SLIDES_PATH}" | sed 's/<title>\(.*\)<\/title>/\1/')

  sed "s/el.parentElement.parentElement.parentElement;/el.parentElement.parentElement.parentElement.parentElement;/g;" "${SLIDES_PATH}" > "${SLIDES_PATH}.decktape.html"

  npx -y decktape reveal \
    --chrome-arg="--no-sandbox" \
    --chrome-arg="--disable-setuid-sandbox" \
    --size "1920x1080" \
    --screenshots \
    --screenshots-format png \
    --screenshots-directory . \
    --slides 1 \
    "${SLIDES_PATH}.decktape.html" index.pdf

  rm index.pdf
  mv index_1_1920x1080.png "${SLIDES_PATH%.html}.png"

  npx -y decktape reveal \
    --chrome-arg="--no-sandbox" \
    --chrome-arg="--disable-setuid-sandbox" \
    --size "1920x1080" \
    --pause 2000 \
    --load-pause 2000 \
    --fragments \
    --pdf-author "${PDF_AUTHOR}" \
    --pdf-title "${PDF_TITLE}" \
    "${SLIDES_PATH}.decktape.html" "${SLIDES_PATH%.html}.pdf"

  # Move the generated PDF to a file named after the current directory, in the same output directory
  OUTPUT_DIR=$(dirname "${SLIDES_PATH}")
  SLIDES_PATH_NO_EXT="${SLIDES_PATH%.html}"
  SLIDES_BASENAME=$(basename "${SLIDES_PATH_NO_EXT}")
  if [ "${SLIDES_BASENAME}" = "index" ]; then
    OUTPUT_NAME=$(basename "${OUTPUT_DIR}")
    if [ "${OUTPUT_NAME}" = "_site" ]; then
      OUTPUT_NAME=$(basename "$(pwd)")
    fi
    cp "${SLIDES_PATH_NO_EXT}.pdf" "${OUTPUT_DIR}/${OUTPUT_NAME}.pdf"
    cp "${SLIDES_PATH_NO_EXT}.png" "${OUTPUT_DIR}/${OUTPUT_NAME}.png"
  else
    OUTPUT_NAME="${SLIDES_BASENAME}"
    mv "${SLIDES_PATH_NO_EXT}.pdf" "${OUTPUT_DIR}/${OUTPUT_NAME}.pdf"
    mv "${SLIDES_PATH_NO_EXT}.png" "${OUTPUT_DIR}/${OUTPUT_NAME}.png"
  fi

  if [ "${CI}" == "true" ]; then
    cp "${OUTPUT_DIR}/${OUTPUT_NAME}.pdf" release_assets/
    cp "${OUTPUT_DIR}/${OUTPUT_NAME}.png" release_assets/
  fi

  rm "${SLIDES_PATH}.decktape.html"
done

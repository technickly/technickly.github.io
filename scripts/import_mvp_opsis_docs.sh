#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="${1:-/Users/nickanderson/mvp-opsis}"
DEST_DIR="$(cd "$(dirname "$0")/.." && pwd)/projects/opsis/docs"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "Source directory not found: $SRC_DIR" >&2
  exit 1
fi

mkdir -p "$DEST_DIR"

copy_doc() {
  local src_file="$1"
  local dest_file="$2"
  local title="$3"
  local out_file="${DEST_DIR}/${dest_file}.md"

  {
    echo "---"
    echo "layout: page"
    echo "title: ${title}"
    echo "permalink: /projects/opsis/docs/${dest_file}/"
    echo "---"
    echo
    echo '> Imported from `'"${src_file}"'`'
    echo
    cat "${SRC_DIR}/${src_file}"
  } > "${out_file}"

  # Rewrite internal markdown links from repo-relative paths to published docs routes.
  perl -pi -e 's#\((?:\./)?README\.md\)#(../readme/)#g' "${out_file}"
  perl -pi -e 's#\((?:\./)?ARCHITECTURE\.md\)#(../architecture/)#g' "${out_file}"
  perl -pi -e 's#\((?:\./)?SETUP_GUIDE\.md\)#(../setup-guide/)#g' "${out_file}"
  perl -pi -e 's#\((?:\./)?CHECKPOINTS\.md\)#(../checkpoints/)#g' "${out_file}"

  perl -pi -e 's#\((?:\./)?docs/generate-synthetic-pdfs\.md\)#(../generate-synthetic-pdfs/)#g' "${out_file}"
  perl -pi -e 's#\((?:\./|\.\./|\.\./\.\./)?docs/generate-synthetic-pdfs\.md\)#(../generate-synthetic-pdfs/)#g' "${out_file}"
  perl -pi -e 's#\((?:\./)?docs/pdf-indexing-explainer\.md\)#(../pdf-indexing-explainer/)#g' "${out_file}"
  perl -pi -e 's#\((?:\./|\.\./|\.\./\.\./)?docs/pdf-indexing-explainer\.md\)#(../pdf-indexing-explainer/)#g' "${out_file}"
  perl -pi -e 's#\((?:\./|\.\./|\.\./\.\./)?docs/ollama_test_api\.md\)#(../ollama-test-api/)#g' "${out_file}"
  perl -pi -e 's#\((?:\./|\.\./|\.\./\.\./)?docs/ollama-embedding-research\.md\)#(../ollama-embedding-research/)#g' "${out_file}"
  perl -pi -e 's#\((?:\./|\.\./|\.\./\.\./)?docs/ollama-models-research\.md\)#(../ollama-models-research/)#g' "${out_file}"
  perl -pi -e 's#\((?:\./|\.\./|\.\./\.\./)?docs/pinecone-local-issues\.md\)#(../pinecone-local-issues/)#g' "${out_file}"

  perl -pi -e 's#\((?:\./)?docker/webdav/README\.md\)#(../docker-webdav-filebrowser/)#g' "${out_file}"
  perl -pi -e 's#\((?:\./)?docker/jira/README\.md\)#(../docker-jira/)#g' "${out_file}"
  perl -pi -e 's#\((?:\./)?docker/pinecone/README\.md\)#(../docker-pinecone-local/)#g' "${out_file}"
  perl -pi -e 's#\((?:\./)?docker/ollama/README\.md\)#(../docker-ollama/)#g' "${out_file}"
  perl -pi -e 's#\((?:\./)?docker-compose\.yml\)#(../relevant-files/)#g' "${out_file}"
  ruby -i -pe 'begin; s = $_.encode("UTF-8", invalid: :replace, undef: :replace, replace: ""); s.gsub!(/[\p{Emoji_Presentation}\p{Extended_Pictographic}\uFE0F\u200D\uFFFD]/, ""); $_ = s; rescue; end' "${out_file}"

  echo "Imported ${src_file} -> ${out_file}"
}

copy_doc "README.md" "readme" "Opsis MVP README"
copy_doc "ARCHITECTURE.md" "architecture" "Opsis Architecture"
copy_doc "SETUP_GUIDE.md" "setup-guide" "Opsis Setup Guide"
copy_doc "CHECKPOINTS.md" "checkpoints" "Opsis Checkpoints"
copy_doc "docs/pdf-indexing-explainer.md" "pdf-indexing-explainer" "PDF Indexing Explainer"
copy_doc "docs/generate-synthetic-pdfs.md" "generate-synthetic-pdfs" "Generate Synthetic PDFs"
copy_doc "docs/ollama_test_api.md" "ollama-test-api" "Ollama API Test Commands"
copy_doc "docs/ollama-embedding-research.md" "ollama-embedding-research" "Ollama Embedding Research"
copy_doc "docs/ollama-models-research.md" "ollama-models-research" "Ollama Model Research"
copy_doc "docs/pinecone-local-issues.md" "pinecone-local-issues" "Pinecone Local Issues"
copy_doc "docker/webdav/README.md" "docker-webdav-filebrowser" "WebDAV and FileBrowser Setup"
copy_doc "docker/jira/README.md" "docker-jira" "Jira Docker Setup"
copy_doc "docker/pinecone/README.md" "docker-pinecone-local" "Pinecone Local Docker Setup"
copy_doc "docker/ollama/README.md" "docker-ollama" "Ollama Setup Notes"

echo "Done."

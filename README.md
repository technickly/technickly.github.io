# Technickly Labs (Jekyll)

Jekyll static site for project documentation and showcase pages.

Current structure:
- `Opsis` (active, docs imported from `~/mvp-opsis`)
- `RoleSmith` (placeholder page)

## Local preview

```bash
cd /Users/nickanderson/technicklyai/technickly-labs
bundle install
bundle exec jekyll serve
```

Open: http://localhost:4000

## Import Opsis markdown docs

This copies selected markdown files from `~/mvp-opsis` into site pages under `/projects/opsis/docs/`.

```bash
cd /Users/nickanderson/technicklyai/technickly-labs
./scripts/import_mvp_opsis_docs.sh
```

Optional custom source path:

```bash
./scripts/import_mvp_opsis_docs.sh /path/to/other/mvp-opsis
```

## GitHub Pages deployment

A workflow is included at:
- `/Users/nickanderson/technicklyai/.github/workflows/deploy-technickly-labs-site.yml`

What it does:
- builds Jekyll from `technickly-labs/`
- deploys to GitHub Pages on push to `main`

## Key paths

- Project list: `technickly-labs/projects.md`
- Opsis page: `technickly-labs/_projects/opsis.md`
- RoleSmith page: `technickly-labs/_projects/rolesmith.md`
- Opsis docs hub: `technickly-labs/projects/opsis/docs/index.md`
- Import script: `technickly-labs/scripts/import_mvp_opsis_docs.sh`

# Progress

Date: 2026-07-04

## Website Redesign

- Replaced the old heavy HTML5 UP purple styling on the main pages with a lighter custom theme.
- Added the new stylesheet at `assets/site/styles.css`.
- Regenerated the main public pages:
  - `index.html`
  - `blogCollection.html`
  - `projects.html`
  - `readings.html`

## Content Workflow

- Added structured site content in `content/site.json`.
- Added a dependency-free Ruby static generator at `scripts/build.rb`.
- Added `package.json` script shortcuts for machines with npm available.
- Updated `README.txt` with the new editing, build, WeChat import, composer, and comments workflows.

## Blog Post System

- Added Markdown-based post folders under `content/posts/`.
- Migrated the existing `improve_text_viz` article into:
  - `content/posts/improve-text-viz/index.md`
- Downloaded and localized the article images into:
  - `content/posts/improve-text-viz/images/`
- Generated the canonical post page:
  - `posts/improve-text-viz/index.html`
- Preserved the old public URL with the refreshed style:
  - `improve_text_viz/index.html`

## Local Authoring

- Added a local-only browser composer at `scripts/admin_server.rb`.
- The composer writes new posts and images into `content/posts/<slug>/` and rebuilds the static site.
- Usage:

```sh
ruby scripts/admin_server.rb
```

Then open:

```text
http://127.0.0.1:4567/
```

## WeChat Import

- Updated `scripts/import_wechat.rb` so exported WeChat HTML drafts are placed under `content/posts/<slug>/`.
- The importer extracts basic text and lists image URLs for manual cleanup.

## Comments

- Added Firebase-backed comment widget scaffolding:
  - `assets/site/comments.js`
  - `assets/site/comments-config.js`
  - `firebase/firestore.rules`
- Generated post pages now include the comments section.
- Comments are disabled until Firebase config is added and `enabled` is set to `true`.
- Planned Firebase setup:
  - Enable Google sign-in.
  - Enable Firestore.
  - Add the Firebase web config.
  - Deploy the Firestore rules.
  - Add the site owner's Firebase Auth UID for moderation.

## Verification

- `ruby scripts/build.rb` succeeds.
- Ruby syntax checks passed for:
  - `scripts/build.rb`
  - `scripts/import_wechat.rb`
  - `scripts/admin_server.rb`
- Local server checks returned `200 OK` for:
  - `/posts/improve-text-viz/`
  - `/improve_text_viz/`
  - a migrated article image
- Local composer check returned `200 OK`.

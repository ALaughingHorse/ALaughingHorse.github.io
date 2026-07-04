ALaughingHorse
===============

This is a lightweight static personal site. GitHub Pages serves the generated
HTML files directly, so there is no runtime backend.

Editing content
---------------

Homepage, project, and reading content lives in:

  content/site.json

Blog posts live in folders under:

  content/posts/

Each post has an index.md file and can keep images beside it:

  content/posts/my-post/
    index.md
    images/
      chart.png

Use Markdown image syntax inside a post:

  ![Chart caption](images/chart.png)

Then regenerate the public HTML files:

  ruby scripts/build.rb

If npm is available, this also works:

  npm run build

Local composer
--------------

To compose posts in a browser on your own machine:

  ruby scripts/admin_server.rb

Then open:

  http://127.0.0.1:4567/

The composer is local-only. It is not part of the published website and does not
provide public login. It writes:

  content/posts/<slug>/index.md
  content/posts/<slug>/images/

and then runs:

  ruby scripts/build.rb

After reviewing the generated page, commit and push the changed files to publish.

The generated pages are:

  index.html
  blogCollection.html
  projects.html
  readings.html
  posts/<slug>/index.html

Some posts can also define a legacy_path in frontmatter. For example,
legacy_path: "improve_text_viz" generates:

  improve_text_viz/index.html

WeChat drafts
-------------

For a saved/exported WeChat article HTML file, run:

  ruby scripts/import_wechat.rb path/to/wechat-export.html optional-slug

This creates a draft Markdown file under:

  content/posts/

The helper extracts basic paragraphs and lists image URLs it finds. WeChat image
handling is inconsistent, so treat the output as a draft: download or replace
images, clean the text, then run ruby scripts/build.rb.

Comments
--------

Post pages include a Firebase-powered comment widget. It is disabled until you
configure:

  assets/site/comments-config.js

Create a Firebase project, then enable:

  Authentication -> Sign-in method -> Google
  Firestore Database

Add your published domains to Firebase Authentication authorized domains:

  alaughinghorse.github.io
  localhost
  127.0.0.1

Paste the Firebase web app config into assets/site/comments-config.js and set:

  enabled: true

Deploy the Firestore rules in:

  firebase/firestore.rules

After your first Google sign-in, copy your Firebase Auth UID and replace
YOUR_FIREBASE_AUTH_UID in firebase/firestore.rules. Also add that UID to
adminUids in assets/site/comments-config.js if you want delete buttons for your
admin account in the browser.

The Firebase web config is public by design. Security depends on Firestore rules,
not on hiding the config file.

Design
------

The custom lightweight theme is in:

  assets/site/styles.css

The older HTML5 UP template assets are still present under assets/css,
assets/js, assets/sass, and assets/fonts for reference, but the current pages use
only assets/site/styles.css.

Credits
-------

The previous version used Hyperspace by HTML5 UP:

  html5up.net | @ajlkn

Original template license text is preserved in LICENSE.txt.

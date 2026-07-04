require "cgi"
require "date"
require "fileutils"
require "pathname"
require "securerandom"
require "webrick"

ROOT = Pathname.new(__dir__).parent
POSTS_DIR = ROOT.join("content/posts")

def h(value)
  CGI.escapeHTML(value.to_s)
end

def slugify(value)
  slug = value.to_s.downcase
    .gsub(/[^a-z0-9\u4e00-\u9fa5]+/, "-")
    .gsub(/\A-|-+\z/, "")
  slug.empty? ? "post-#{SecureRandom.hex(3)}" : slug[0, 80]
end

def safe_filename(value)
  name = File.basename(value.to_s)
  name = name.downcase.gsub(/[^a-z0-9._-]+/, "-").gsub(/\A-+|-+\z/, "")
  name.empty? ? "image-#{SecureRandom.hex(3)}.png" : name
end

def param(req, key)
  value = req.query[key]
  value.respond_to?(:first) ? value.first : value
end

def admin_page(message: nil)
  today = Date.today.iso8601
  <<~HTML
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Compose | ALaughingHorse</title>
        <style>
          :root { color-scheme: light; --bg: #f7f5ef; --surface: #fff; --text: #222426; --muted: #66706b; --border: #ded9ce; --accent: #2f6f73; }
          * { box-sizing: border-box; }
          body { margin: 0; background: var(--bg); color: var(--text); font: 16px/1.55 -apple-system, BlinkMacSystemFont, "Segoe UI", Arial, sans-serif; }
          main { max-width: 1120px; margin: 0 auto; padding: 2rem 1rem 4rem; }
          h1 { font-size: clamp(2rem, 5vw, 4rem); line-height: 1; margin: 0 0 1rem; }
          p { color: var(--muted); }
          form { display: grid; gap: 1rem; }
          label { display: grid; gap: .35rem; font-weight: 700; }
          input, textarea { border: 1px solid var(--border); border-radius: 10px; font: inherit; padding: .75rem .85rem; width: 100%; }
          textarea { min-height: 460px; resize: vertical; }
          .grid { display: grid; gap: 1rem; grid-template-columns: repeat(2, minmax(0, 1fr)); }
          .panel { background: var(--surface); border: 1px solid var(--border); border-radius: 14px; padding: 1rem; }
          .actions { display: flex; flex-wrap: wrap; gap: .75rem; }
          button, .button { background: var(--text); border: 0; border-radius: 999px; color: white; cursor: pointer; font: inherit; font-weight: 800; padding: .7rem 1rem; text-decoration: none; }
          .secondary { background: transparent; border: 1px solid var(--text); color: var(--text); }
          .message { background: #dcebec; border: 1px solid #bdd7d9; border-radius: 12px; color: #1f5558; padding: .8rem 1rem; }
          .help { font-size: .92rem; margin: .25rem 0 0; }
          @media (max-width: 760px) { .grid { grid-template-columns: 1fr; } }
        </style>
      </head>
      <body>
        <main>
          <h1>Compose a Post</h1>
          <p>This local-only tool writes Markdown and images into <code>content/posts/</code>, then rebuilds the static site. It is not published to GitHub Pages.</p>
          #{message ? %(<div class="message">#{message}</div>) : ""}
          <form method="post" action="/create" enctype="multipart/form-data">
            <div class="grid">
              <label>Title
                <input id="title" name="title" required>
              </label>
              <label>Slug
                <input id="slug" name="slug" placeholder="auto-from-title">
              </label>
              <label>Date
                <input name="date" value="#{today}">
              </label>
              <label>Tags
                <input name="tags" placeholder="NLP, Data Science, Life">
              </label>
              <label>Source
                <input name="source" value="Personal site">
              </label>
              <label>Cover image path
                <input name="cover" placeholder="images/cover.png">
              </label>
            </div>
            <label>Description
              <input name="description" placeholder="Short summary shown on the archive page">
            </label>
            <div class="panel">
              <label>Images
                <input id="images" name="images" type="file" multiple accept="image/*">
              </label>
              <p class="help">When you choose images, Markdown snippets are inserted at the cursor. Files are saved into the post's <code>images/</code> folder.</p>
            </div>
            <label>Body Markdown
              <textarea id="body" name="body" required placeholder="Write Markdown here. Use ## headings and ![caption](images/file.png) for images."></textarea>
            </label>
            <div class="actions">
              <button type="submit">Create post and rebuild</button>
              <a class="button secondary" href="http://127.0.0.1:8001/" target="_blank" rel="noreferrer">Open site preview</a>
            </div>
          </form>
        </main>
        <script>
          const title = document.querySelector("#title");
          const slug = document.querySelector("#slug");
          const body = document.querySelector("#body");
          const images = document.querySelector("#images");
          const slugify = value => value.toLowerCase().replace(/[^a-z0-9\\u4e00-\\u9fa5]+/g, "-").replace(/^-|-$/g, "").slice(0, 80);
          title.addEventListener("input", () => { if (!slug.dataset.edited) slug.value = slugify(title.value); });
          slug.addEventListener("input", () => { slug.dataset.edited = "true"; });
          images.addEventListener("change", () => {
            const snippets = [...images.files].map(file => {
              const name = file.name.toLowerCase().replace(/[^a-z0-9._-]+/g, "-").replace(/^-|-$/g, "");
              return `\\n![${file.name.replace(/\\.[^.]+$/, "")}](images/${name})\\n`;
            }).join("");
            const start = body.selectionStart;
            body.setRangeText(snippets, start, body.selectionEnd, "end");
            body.focus();
          });
        </script>
      </body>
    </html>
  HTML
end

def create_post(req)
  title = param(req, "title").to_s.strip
  raise "Title is required" if title.empty?

  slug = slugify(param(req, "slug").to_s.strip.empty? ? title : param(req, "slug"))
  post_dir = POSTS_DIR.join(slug)
  raise "Post already exists: #{slug}" if post_dir.exist?

  images_dir = post_dir.join("images")
  FileUtils.mkdir_p(images_dir)

  Array(req.query["images"]).each do |upload|
    next unless upload.respond_to?(:filename) && upload.filename && !upload.filename.empty?
    bytes = upload.respond_to?(:read) ? upload.read : upload.to_s
    File.binwrite(images_dir.join(safe_filename(upload.filename)), bytes)
  end

  tags = param(req, "tags").to_s.split(",").map { |tag| tag.strip }.reject(&:empty?)
  frontmatter = {
    "title" => title,
    "date" => param(req, "date").to_s.strip,
    "source" => param(req, "source").to_s.strip,
    "tags" => tags,
    "description" => param(req, "description").to_s.strip,
    "cover" => param(req, "cover").to_s.strip
  }

  markdown = +"---\n"
  frontmatter.each do |key, value|
    if value.is_a?(Array)
      markdown << "#{key}: [#{value.map { |item| %("#{item.gsub('"', '\"')}") }.join(", ")}]\n"
    else
      markdown << "#{key}: \"#{value.gsub('"', '\"')}\"\n"
    end
  end
  markdown << "---\n\n"
  markdown << param(req, "body").to_s.strip
  markdown << "\n"

  File.write(post_dir.join("index.md"), markdown)
  system("ruby", ROOT.join("scripts/build.rb").to_s, chdir: ROOT.to_s) || raise("Build failed")
  slug
end

server = WEBrick::HTTPServer.new(
  BindAddress: "127.0.0.1",
  Port: Integer(ENV.fetch("PORT", "4567")),
  DocumentRoot: ROOT.to_s,
  AccessLog: [],
  Logger: WEBrick::Log.new($stderr, WEBrick::Log::INFO)
)

server.mount_proc("/") do |_req, res|
  res["Content-Type"] = "text/html; charset=utf-8"
  res.body = admin_page
end

server.mount_proc("/create") do |req, res|
  begin
    slug = create_post(req)
    res["Content-Type"] = "text/html; charset=utf-8"
    res.body = admin_page(message: %(Created <code>#{h(slug)}</code>. Preview at <a href="/posts/#{h(slug)}/">/posts/#{h(slug)}/</a>.))
  rescue StandardError => e
    res.status = 400
    res["Content-Type"] = "text/html; charset=utf-8"
    res.body = admin_page(message: "Error: #{h(e.message)}")
  end
end

trap("INT") { server.shutdown }
puts "Authoring server: http://127.0.0.1:#{server.config[:Port]}/"
server.start

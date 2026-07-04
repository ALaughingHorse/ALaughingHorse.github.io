require "cgi"
require "fileutils"
require "json"
require "pathname"
require "time"

ROOT = Pathname.new(__dir__).parent
DATA = JSON.parse(File.read(ROOT.join("content/site.json")))

def h(value)
  CGI.escapeHTML(value.to_s)
end

NAV_ITEMS = [
  ["Home", "index.html"],
  ["Writing", "blogCollection.html"],
  ["Projects", "projects.html"],
  ["Reading", "readings.html"]
]

def page_shell(title:, active:, body:, description: DATA["site"]["description"], base: "")
  nav = NAV_ITEMS.map do |label, href|
    current = active == label ? ' aria-current="page"' : ""
    %(<a href="#{base}#{href}"#{current}>#{h(label)}</a>)
  end.join("\n        ")

  <<~HTML
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="description" content="#{h(description)}">
        <title>#{h(title)} | #{h(DATA["site"]["title"])}</title>
        <link rel="stylesheet" href="#{base}assets/site/styles.css">
      </head>
      <body>
        <header class="site-header">
          <a class="brand" href="#{base}index.html">#{h(DATA["site"]["title"])}</a>
          <nav class="site-nav" aria-label="Primary navigation">
            #{nav}
          </nav>
        </header>
        <main>
          #{body}
        </main>
        <footer class="site-footer">
          <p>Built as a lightweight static site. Content lives in <code>content/site.json</code>.</p>
          <p>Original visual template: <a href="https://html5up.net">HTML5 UP</a>. Icons by Flaticon contributors.</p>
        </footer>
      </body>
    </html>
  HTML
end

def comments_block(post, base:)
  <<~HTML
    <section class="comments" data-comments-root data-post-id="#{h(post["slug"])}">
      <div class="comments-header">
        <div>
          <p class="eyebrow">Discussion</p>
          <h2>Comments</h2>
        </div>
        <div class="comments-auth">
          <span data-comments-user>Sign in with Google to comment.</span>
          <button type="button" data-comments-sign-in>Sign in</button>
          <button type="button" data-comments-sign-out hidden>Sign out</button>
        </div>
      </div>
      <p class="comments-status" data-comments-status>Loading comments...</p>
      <div class="comments-list" data-comments-list></div>
      <form class="comments-form" data-comments-form hidden>
        <label for="comment-text">Comment</label>
        <textarea id="comment-text" data-comments-text maxlength="3000" required></textarea>
        <button type="submit">Post comment</button>
      </form>
    </section>
    <script src="#{base}assets/site/comments-config.js"></script>
    <script src="#{base}assets/site/comments.js"></script>
  HTML
end

def tags(items)
  return "" unless items && !items.empty?

  list = items.map { |tag| "<li>#{h(tag)}</li>" }.join
  %(<ul class="tags">#{list}</ul>)
end

def parse_scalar(value)
  value = value.to_s.strip
  if value.start_with?("[") && value.end_with?("]")
    return value[1..-2].split(",").map { |item| item.strip.gsub(/\A["']|["']\z/, "") }.reject(&:empty?)
  end

  value.gsub(/\A["']|["']\z/, "")
end

def parse_post(path)
  raw = File.read(path)
  meta = {}
  body = raw

  if raw.start_with?("---\n")
    _, frontmatter, body = raw.split(/^---\s*$/, 3)
    frontmatter.to_s.each_line do |line|
      key, value = line.split(":", 2)
      next unless key && value
      meta[key.strip] = parse_scalar(value)
    end
  end

  slug = Pathname.new(path).parent.basename.to_s
  meta["slug"] = slug
  meta["url"] = "posts/#{slug}/"
  meta["body"] = body.to_s.strip
  meta
end

def local_posts
  Dir[ROOT.join("content/posts/*/index.md")]
    .map { |path| parse_post(path) }
    .sort_by { |post| post["date"].to_s }
    .reverse
end

def render_inline(text)
  value = +""
  cursor = 0

  text.to_s.to_enum(:scan, /\[([^\]]+)\]\(([^)]+)\)/).each do
    match = Regexp.last_match
    value << h(text[cursor...match.begin(0)])
    value << %(<a href="#{h(match[2])}">#{h(match[1])}</a>)
    cursor = match.end(0)
  end
  value << h(text.to_s[cursor..])

  value = value.gsub(/\*\*([^*]+)\*\*/, "<strong>\\1</strong>")
  value
end

def render_markdown(markdown)
  lines = markdown.lines.map(&:rstrip)
  html = []
  i = 0

  while i < lines.length
    line = lines[i].strip

    if line.empty?
      i += 1
      next
    end

    if line.start_with?("### ")
      html << "<h3>#{render_inline(line.sub(/^###\s+/, ""))}</h3>"
      i += 1
      next
    end

    if line.start_with?("## ")
      html << "<h2>#{render_inline(line.sub(/^##\s+/, ""))}</h2>"
      i += 1
      next
    end

    if line.start_with?("# ")
      html << "<h2>#{render_inline(line.sub(/^#\s+/, ""))}</h2>"
      i += 1
      next
    end

    if line =~ /\A!\[([^\]]*)\]\(([^)]+)\)\z/
      alt = $1
      src = $2
      caption = nil
      if lines[i + 1].to_s.strip =~ /\A_([^_]+)_\z/
        caption = $1
        i += 1
      end
      html << %(<figure class="article-figure"><img src="#{h(src)}" alt="#{h(alt)}">#{caption ? "<figcaption>#{render_inline(caption)}</figcaption>" : ""}</figure>)
      i += 1
      next
    end

    if line =~ /\A\d+\.\s+/
      items = []
      while i < lines.length && lines[i].strip =~ /\A\d+\.\s+(.*)/
        items << "<li>#{render_inline($1)}</li>"
        i += 1
      end
      html << "<ol>#{items.join}</ol>"
      next
    end

    paragraph = [line]
    i += 1
    while i < lines.length
      next_line = lines[i].strip
      break if next_line.empty?
      break if next_line.start_with?("#", "!", "### ", "## ")
      break if next_line =~ /\A\d+\.\s+/
      paragraph << next_line
      i += 1
    end
    html << "<p>#{render_inline(paragraph.join(" "))}</p>"
  end

  html.join("\n")
end

def link_card(item)
  meta = item["source"] || item["meta"] || ""
  <<~HTML
    <article class="card">
      <div class="card-meta">#{h(meta)}</div>
      <h2><a href="#{h(item["url"])}">#{h(item["title"])}</a></h2>
      <p>#{h(item["description"])}</p>
      #{tags(item["tags"])}
    </article>
  HTML
end

def post_card(post)
  link_card({
    "source" => post["source"],
    "url" => post["url"],
    "title" => post["title"],
    "description" => post["description"],
    "tags" => post["tags"]
  })
end

def home_page
  intro = DATA["site"]["intro"].map { |text| "<p>#{h(text)}</p>" }.join("\n        ")
  actions = DATA["site"]["links"].map { |link| %(<a class="button" href="#{h(link["href"])}">#{h(link["label"])}</a>) }.join

  body = <<~HTML
    <section class="hero">
      <div class="hero-copy">
        <p class="eyebrow">Data science, writing, and reading notes</p>
        <h1>#{h(DATA["site"]["name"])}</h1>
        #{intro}
        <div class="hero-actions">
          #{actions}
        </div>
      </div>
      <figure class="portrait">
        <img src="images/self.JPG" alt="#{h(DATA["site"]["name"])}">
      </figure>
    </section>
    <section class="section">
      <div class="section-heading">
        <p class="eyebrow">Latest writing</p>
        <h2>Essays and technical notes</h2>
      </div>
      <div class="grid three">
        #{(local_posts.map { |post| post_card(post) } + DATA["posts"].map { |post| link_card(post) }).first(3).join}
      </div>
    </section>
    <section class="section split">
      <div>
        <p class="eyebrow">Projects</p>
        <h2>Small tools for text analysis</h2>
      </div>
      <div class="stack">
        #{DATA["projects"].map { |project| link_card(project) }.join}
      </div>
    </section>
  HTML

  page_shell(title: "Home", active: "Home", body: body)
end

def writing_page
  all_cards = local_posts.map { |post| post_card(post) } + DATA["posts"].map { |post| link_card(post) }
  body = <<~HTML
    <section class="page-title">
      <p class="eyebrow">Writing archive</p>
      <h1>Blogs</h1>
      <p>Posts can come from this site, Medium, or WeChat. Add new entries in <code>content/site.json</code>, or use the WeChat import helper to create a draft.</p>
    </section>
    <section class="grid two">
      #{all_cards.join}
    </section>
  HTML

  page_shell(title: "Writing", active: "Writing", body: body)
end

def post_page(post, base: "../../")
  date = post["date"].to_s.empty? ? "" : Time.parse(post["date"]).strftime("%B %-d, %Y")
  meta = [date, post["source"]].compact.reject(&:empty?).join(" · ")
  body = <<~HTML
    <article class="article">
      <header class="article-header">
        <p class="eyebrow">#{h(post["source"] || "Writing")}</p>
        <h1>#{h(post["title"])}</h1>
        <p class="article-meta">#{h(meta)}</p>
        #{tags(post["tags"])}
      </header>
      <div class="article-body">
        #{render_markdown(post["body"])}
      </div>
    </article>
    #{comments_block(post, base: base)}
  HTML

  page_shell(title: post["title"], active: "Writing", body: body, description: post["description"], base: base)
end

def copy_post_assets(post, output_dir)
  source_dir = ROOT.join("content/posts", post["slug"], "images")
  return unless source_dir.directory?

  target_dir = ROOT.join(output_dir, "images")
  FileUtils.rm_rf(target_dir)
  FileUtils.mkdir_p(target_dir)
  FileUtils.cp_r(Dir[source_dir.join("*")], target_dir)
end

def projects_page
  body = <<~HTML
    <section class="page-title">
      <p class="eyebrow">Code</p>
      <h1>Projects</h1>
      <p>Programming packages and small tools.</p>
    </section>
    <section class="grid two">
      #{DATA["projects"].map { |project| link_card(project) }.join}
    </section>
  HTML

  page_shell(title: "Projects", active: "Projects", body: body)
end

def readings_page
  items = DATA["readings"].map do |book|
    notes = book["notes"].map { |note| "<p>#{h(note)}</p>" }.join
    <<~HTML
      <article class="reading">
        <div>
          <p class="card-meta">#{h(book["period"])}</p>
          <h2>#{h(book["title"])}</h2>
          <p class="byline">#{h(book["author"])}</p>
        </div>
        <div class="notes">
          #{notes}
        </div>
      </article>
    HTML
  end.join

  body = <<~HTML
    <section class="page-title">
      <p class="eyebrow">Books</p>
      <h1>Reading notes</h1>
      <p>Short reflections, not formal reviews.</p>
    </section>
    <section class="reading-list">
      #{items}
    </section>
  HTML

  page_shell(title: "Reading", active: "Reading", body: body)
end

outputs = {
  "index.html" => home_page,
  "blogCollection.html" => writing_page,
  "projects.html" => projects_page,
  "readings.html" => readings_page
}

local_posts.each do |post|
  post_dir = "posts/#{post["slug"]}"
  outputs["#{post_dir}/index.html"] = post_page(post)
  copy_post_assets(post, post_dir)

  next unless post["legacy_path"] && !post["legacy_path"].empty?

  legacy_dir = post["legacy_path"]
  outputs["#{legacy_dir}/index.html"] = post_page(post, base: "../")
  copy_post_assets(post, legacy_dir)
end

outputs.each do |file, html|
  FileUtils.mkdir_p(ROOT.join(file).parent)
  File.write(ROOT.join(file), html)
end

puts "Generated #{outputs.length} pages."

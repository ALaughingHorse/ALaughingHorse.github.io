require "fileutils"
require "pathname"

input_path = ARGV[0]
slug_arg = ARGV[1]

unless input_path
  warn "Usage: ruby scripts/import_wechat.rb path/to/wechat-export.html optional-slug"
  exit 1
end

root = Pathname.new(__dir__).parent
html = File.read(File.expand_path(input_path))

def plain_text(value)
  value.to_s
    .gsub(/<script[\s\S]*?<\/script>/i, "")
    .gsub(/<style[\s\S]*?<\/style>/i, "")
    .gsub(/<[^>]+>/, "")
    .gsub("&nbsp;", " ")
    .gsub("&amp;", "&")
    .gsub("&lt;", "<")
    .gsub("&gt;", ">")
    .gsub(/\s+/, " ")
    .strip
end

title = plain_text(html[/<h1[^>]*>([\s\S]*?)<\/h1>/i, 1])
title = plain_text(html[/<title[^>]*>([\s\S]*?)<\/title>/i, 1]) if title.empty?
title = "Untitled WeChat Post" if title.empty?

slug = (slug_arg || title)
  .downcase
  .gsub(/[^a-z0-9\u4e00-\u9fa5]+/, "-")
  .gsub(/^-|-$/, "")[0, 80]
slug = "wechat-post" if slug.empty?

paragraphs = html.scan(/<p[^>]*>([\s\S]*?)<\/p>/i)
  .map { |match| plain_text(match.first) }
  .reject(&:empty?)

images = html.scan(/<img[^>]+(?:data-src|src)=["']([^"']+)["'][^>]*>/i)
  .map(&:first)
  .reject(&:empty?)

out_dir = root.join("content/posts", slug)
FileUtils.mkdir_p(out_dir)

image_comment = if images.empty?
  ""
else
  "\n\n<!-- Image URLs found in the export. Download or replace them before publishing.\n#{images.map { |src| "- #{src}" }.join("\n")}\n-->\n"
end

markdown = <<~MD
  ---
  title: "#{title.gsub('"', '\"')}"
  source: "WeChat"
  date: ""
  tags: []
  description: ""
  cover: ""
  canonical: ""
  ---

  #{paragraphs.join("\n\n")}
  #{image_comment}
MD

File.write(out_dir.join("index.md"), markdown)
puts "Created #{out_dir.join("index.md").relative_path_from(root)}"

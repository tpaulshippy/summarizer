module ApplicationHelper
  include Pagy::Frontend

  def markdown(text)
    return "" if text.blank?

    renderer = Redcarpet::Render::HTML.new(
      filter_html: true,
      no_links: false,
      hard_wrap: true
    )

    markdown_processor = Redcarpet::Markdown.new(renderer,
      autolink: true,
      fenced_code_blocks: true,
      strikethrough: true,
      superscript: true,
      no_intra_emphasis: true,
      tables: true
    )

    markdown_processor.render(text).html_safe
  end
end

local document = require("image/utils/document")

return document.create_document_integration({
  name = "markdown",
  -- debug = true,
  default_options = {
    clear_in_insert_mode = false,
    download_remote_images = true,
    only_render_image_at_cursor = false,
    filetypes = { "markdown", "vimwiki" },
  },
  query_buffer_images = function(buffer)
    local buf = buffer or vim.api.nvim_get_current_buf()

    local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype) or vim.bo[buf].filetype
    local parser = vim.treesitter.get_parser(buf, lang)
    parser:parse(true)
    local inline_lang = "markdown_inline"
    local inlines = parser:children()[inline_lang]
    local inline_query = vim.treesitter.query.parse(inline_lang, "(image (link_destination) @url) @image")

    if not inlines then return {} end

    local images = {}
    local function get_inline_images(tree)
      local root = tree:root()
      local current_image = nil

      ---@diagnostic disable-next-line: missing-parameter
      for id, node in inline_query:iter_captures(root, 0) do
        local key = inline_query.captures[id]
        local value = vim.treesitter.get_node_text(node, buf)

        -- TODO: fix node:range() taking into account the extmarks for SOME FKING REASON
        if key == "image" then
          local start_row, start_col, end_row, end_col = node:range()
          current_image = {
            node = node,
            range = { start_row = start_row, start_col = start_col, end_row = end_row, end_col = end_col },
          }
        elseif current_image and key == "url" then
          current_image.url = value
          table.insert(images, current_image)
          current_image = nil
        end
      end
    end

    inlines:for_each_tree(get_inline_images)

    return images
  end,
})

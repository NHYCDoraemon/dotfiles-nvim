-- Javadoc visual upgrade for Java buffers.
--
-- Two features:
--   1. Chip background for {@code XXX} bodies.
--   2. Rendered Doc Comments — IDEA-style preview of /** ... */ blocks
--      via extmark conceals. Hides /** */ leading * / lightweight HTML.
--
-- concealcursor="nc" keeps comments rendered under cursor in normal mode
-- but reveals raw text on insert mode, so editing is unaffected.
-- Toggle the renderer with <leader>jd.

-- =========================================================================
-- Part 1 — Chip background for {@code XXX}
-- =========================================================================

local function attrs_of(name)
  local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  return (ok and h) or {}
end

local function shift_for_contrast(rgb, delta)
  local r = math.floor(rgb / 65536) % 256
  local g = math.floor(rgb / 256) % 256
  local b = rgb % 256
  local lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255
  local sign = (lum > 0.5) and -1 or 1
  r = math.max(0, math.min(255, r + sign * delta))
  g = math.max(0, math.min(255, g + sign * delta))
  b = math.max(0, math.min(255, b + sign * delta))
  return r * 65536 + g * 256 + b
end

local function apply_javadoc_chip()
  local special = attrs_of("Special")
  local normal  = attrs_of("Normal")
  if not normal.bg then return end
  local chip_bg = shift_for_contrast(normal.bg, 20)
  vim.api.nvim_set_hl(0, "@markup.raw.javadoc", {
    bg     = chip_bg,
    fg     = special.fg,
    bold   = special.bold,
    italic = special.italic,
  })
end

local chip_grp = vim.api.nvim_create_augroup("javadoc-chips", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", { group = chip_grp, callback = apply_javadoc_chip })
vim.schedule(apply_javadoc_chip)


-- =========================================================================
-- Part 2 — Rendered Doc Comments
-- =========================================================================

local ns = vim.api.nvim_create_namespace("javadoc-render")
local cursor_in_javadoc

local function hover_contents(result)
  if not result or not result.contents then return nil end
  local lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
  lines = vim.split(table.concat(lines, "\n"), "\n", { trimempty = true })
  if vim.tbl_isempty(lines) then return nil end
  return lines
end

local function show_hover(lines)
  vim.lsp.util.open_floating_preview(lines, "markdown", {
    border = "rounded",
    max_width = 100,
  })
end

local function client_position_params(buf, client, uri, position)
  return {
    textDocument = { uri = uri or vim.uri_from_bufnr(buf) },
    position = position or vim.lsp.util.make_position_params(0, client.offset_encoding or "utf-16").position,
  }
end

local function is_probable_java_ref(ref)
  if not ref or ref == "" then return false end
  if ref:find("://", 1, true) or ref:find("/") or ref:find(":") then return false end
  if ref:find("[^%w%._#$%(%)%[%], ]") then return false end
  local first = ref:match("^%s*([^%s]+)")
  if not first then return false end
  first = first:gsub("%b()", "")
  first = first:gsub("%b[]", "")
  if first:match("^#") then return true end
  local class_part, member_part = first:match("^([^#]+)#(.+)$")
  if member_part and not member_part:match("^[_%a$][_%w$]*$") then return false end
  class_part = class_part or first
  for segment in class_part:gmatch("[^%.]+") do
    if not segment:match("^[_%a$][_%w$]*$") then return false end
  end
  return true
end

local function javadoc_ref_at_cursor(buf)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
  local cursor_col = col

  local function ref_from(start_col, ref)
    if not is_probable_java_ref(ref) then return nil end
    local offset = ref:match("^%s*()") or 1
    local token = ref:match("^%s*([^%s]+)") or ref
    local target_offset = offset - 1
    local member_col = token:find("#[_%a$][_%w$]*$")
    if member_col then
      target_offset = target_offset + member_col
    else
      local simple_col = token:match("^.*()%.")
      if simple_col then
        target_offset = target_offset + simple_col
      end
    end
    return {
      ref = token,
      position = {
        line = row - 1,
        character = start_col + target_offset,
      },
    }
  end

  local search = 1
  while true do
    local tag_s, tag_e, tag, body = line:find("{@([%a]+)%s+([^}]*)}", search)
    if not tag_s then break end
    if cursor_col >= tag_s - 1 and cursor_col <= tag_e then
      local body_start = tag_s + 3 + #tag
      local target = body
      if tag == "link" or tag == "linkplain" or tag == "see" or tag == "value" then
        target = body:match("^%s*([^%s]+)")
      elseif tag ~= "code" and tag ~= "literal" then
        target = nil
      end
      return ref_from(body_start - 1, target)
    end
    search = tag_e + 1
  end

  for _, block_tag in ipairs({ "see", "throws", "exception" }) do
    local block_s, block_e, body = line:find("@" .. block_tag .. "%s+(.+)")
    if block_s and cursor_col >= block_s - 1 then
      local target = body:match("^%s*([^%s]+)")
      if target and not target:match("^<") then
        return ref_from(block_e - #body, target)
      end
    end
  end

  return nil
end

local function definition_is_empty(result)
  if not result then return true end
  if vim.tbl_islist(result) then return #result == 0 end
  return false
end

local function import_position_for_ref(buf, ref)
  if not ref then return nil end

  local class_ref = ref:gsub("#.*$", "")
  local simple = class_ref:match("([_%a$][_%w$]*)$") or class_ref
  if simple == "" then return nil end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, math.min(vim.api.nvim_buf_line_count(buf), 200), false)
  for i, line in ipairs(lines) do
    local imported = line:match("^%s*import%s+([^;]+);")
    if imported then
      if imported == class_ref or imported:match("%." .. vim.pesc(simple) .. "$") then
        local col = line:find(simple, 1, true)
        if col then
          return { line = i - 1, character = col - 1 }
        end
      end
    end
  end

  return nil
end

local function workspace_source_location_for_ref(buf, ref)
  if not ref or not ref:find(".", 1, true) then return nil end
  local class_ref = ref:gsub("#.*$", "")
  local rel = class_ref:gsub("%.", "/") .. ".java"
  local name = rel:match("[^/]+$")
  if not name then return nil end

  local current = vim.api.nvim_buf_get_name(buf)
  local root = vim.fs.root(current ~= "" and current or 0, { "pom.xml", "build.gradle", "settings.gradle", ".git" })
  if not root then return nil end

  local matches = vim.fs.find(name, {
    path = root,
    type = "file",
    limit = 20,
  })
  for _, path in ipairs(matches) do
    if path:sub(-#rel) == rel then
      return {
        uri = vim.uri_from_fname(path),
        range = {
          start = { line = 0, character = 0 },
          ["end"] = { line = 0, character = 0 },
        },
      }
    end
  end

  return nil
end

local function request_definition(buf, client, position, ref, callback)
  client:request("textDocument/definition", client_position_params(buf, client, nil, position), function(err, result)
    if err or not definition_is_empty(result) then
      callback(err, result)
      return
    end

    local import_position = import_position_for_ref(buf, ref)
    if import_position then
      client:request("textDocument/definition", client_position_params(buf, client, nil, import_position), callback, buf)
      return
    end

    local source_location = workspace_source_location_for_ref(buf, ref)
    if source_location then
      callback(nil, source_location)
      return
    end

    callback(err, result)
  end, buf)
end

local function first_definition(result)
  if not result then return nil end
  if vim.tbl_islist(result) then
    return result[1]
  end
  return result
end

local function definition_uri_and_position(location)
  if not location then return nil, nil end
  local uri = location.targetUri or location.uri
  local range = location.targetSelectionRange or location.targetRange or location.range
  if not uri or not range then return nil, nil end
  return uri, range.start
end

local function preview_definition(location, client)
  pcall(vim.lsp.util.preview_location, location, {
    border = "rounded",
    max_width = 100,
    focusable = true,
  }, client and client.offset_encoding or "utf-16")
end

local function load_uri(uri)
  if not uri then return nil end
  local ok, target_buf = pcall(vim.uri_to_bufnr, uri)
  if not ok or not target_buf then return nil end
  pcall(vim.fn.bufload, target_buf)
  return target_buf
end

local function clean_doc_line(line)
  line = line:gsub("^%s*/%*%*%s?", "")
  line = line:gsub("^%s*%*/%s?", "")
  line = line:gsub("^%s*%*%s?", "")
  line = line:gsub("{@code%s+([^}]+)}", "`%1`")
  line = line:gsub("{@literal%s+([^}]+)}", "`%1`")
  line = line:gsub("{@link%s+([^}%s]+)%s+([^}]+)}", "%2")
  line = line:gsub("{@link%s+([^}]+)}", "%1")
  line = line:gsub("{@linkplain%s+([^}%s]+)%s+([^}]+)}", "%2")
  line = line:gsub("{@linkplain%s+([^}]+)}", "%1")
  line = line:gsub("<p>", "")
  line = line:gsub("</p>", "")
  line = line:gsub("<ul>", "")
  line = line:gsub("</ul>", "")
  line = line:gsub("<li>", "- ")
  line = line:gsub("</li>", "")
  line = line:gsub("<br%s*/?>", "  ")
  return line
end

local function definition_javadoc_lines(target_buf, position)
  if not target_buf or not vim.api.nvim_buf_is_loaded(target_buf) or not position then return nil end

  local search_from = math.max(0, position.line)
  for lnum = search_from, math.max(0, search_from - 120), -1 do
    local line = vim.api.nvim_buf_get_lines(target_buf, lnum, lnum + 1, false)[1] or ""
    if line:find("%*/") then
      local close_lnum = lnum
      for start_lnum = close_lnum, math.max(0, close_lnum - 120), -1 do
        local start_line = vim.api.nvim_buf_get_lines(target_buf, start_lnum, start_lnum + 1, false)[1] or ""
        if start_line:find("/%*%*") then
          local raw = vim.api.nvim_buf_get_lines(target_buf, start_lnum, close_lnum + 1, false)
          local lines = {}
          for _, doc_line in ipairs(raw) do
            table.insert(lines, clean_doc_line(doc_line))
          end
          while #lines > 0 and lines[1]:match("^%s*$") do
            table.remove(lines, 1)
          end
          while #lines > 0 and lines[#lines]:match("^%s*$") do
            table.remove(lines)
          end
          return vim.tbl_isempty(lines) and nil or lines
        end
      end
      return nil
    end

    if line:match("%S") and not line:match("^%s*@") and lnum < search_from then
      return nil
    end
  end

  return nil
end

local function fallback_definition_hover(buf, done, ref_info)
  local definition_clients = vim.lsp.get_clients({ bufnr = buf, method = "textDocument/definition" })
  if vim.tbl_isempty(definition_clients) then return end

  local definition_client = definition_clients[1]
  request_definition(buf, definition_client, ref_info and ref_info.position, ref_info and ref_info.ref, function(_, def_result)
    if done(true) then return end

    local location = first_definition(def_result)
    local uri, position = definition_uri_and_position(location)
    if not uri or not position then return end

    local target_buf = load_uri(uri) or buf
    definition_client:request("textDocument/hover", client_position_params(target_buf, definition_client, uri, position), function(_, target_result)
      if done() then return end

      local target_lines = hover_contents(target_result)
      if target_lines then
        show_hover(target_lines)
      else
        local doc_lines = definition_javadoc_lines(target_buf, position)
        if doc_lines then
          show_hover(doc_lines)
        else
          preview_definition(location, definition_client)
        end
      end
    end, target_buf)
  end)
end

function cursor_in_javadoc(buf)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local start_row

  for lnum = row, math.max(1, row - 200), -1 do
    local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1] or ""
    if line:find("%*/") and lnum ~= row then
      return false
    end
    if line:find("/%*%*") then
      start_row = lnum
      break
    end
  end

  if not start_row then return false end

  for lnum = start_row, math.min(vim.api.nvim_buf_line_count(buf), start_row + 300) do
    local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1] or ""
    if line:find("%*/") then
      return row <= lnum
    end
  end

  return true
end

local function javadoc_hover()
  local buf = vim.api.nvim_get_current_buf()
  if not cursor_in_javadoc(buf) then
    vim.lsp.buf.hover()
    return
  end

  local hover_clients = vim.lsp.get_clients({ bufnr = buf, method = "textDocument/hover" })
  if vim.tbl_isempty(hover_clients) then
    vim.lsp.buf.hover()
    return
  end

  local client = hover_clients[1]
  local ref_info = javadoc_ref_at_cursor(buf)
  local finished = false
  local fallback_started = false
  local function done(check_only)
    if finished then return true end
    if check_only then return false end
    finished = true
    return false
  end
  local function start_fallback()
    if finished or fallback_started then return end
    fallback_started = true
    fallback_definition_hover(buf, done, ref_info)
  end

  vim.defer_fn(start_fallback, 250)

  client:request("textDocument/hover", client_position_params(buf, client, nil, ref_info and ref_info.position), function(_, result)
    if finished then return end
    local lines = hover_contents(result)
    if lines then
      done()
      show_hover(lines)
    else
      start_fallback()
    end
  end, buf)
end

local function javadoc_definition()
  local buf = vim.api.nvim_get_current_buf()
  local ref_info = javadoc_ref_at_cursor(buf)
  if not ref_info then
    vim.lsp.buf.definition()
    return
  end

  local clients = vim.lsp.get_clients({ bufnr = buf, method = "textDocument/definition" })
  if vim.tbl_isempty(clients) then
    vim.lsp.buf.definition()
    return
  end

  local client = clients[1]
  request_definition(buf, client, ref_info.position, ref_info.ref, function(err, result)
    if err or not result then
      vim.notify("No Javadoc definition found", vim.log.levels.INFO)
      return
    end

    local location = first_definition(result)
    if not location then
      vim.notify("No Javadoc definition found", vim.log.levels.INFO)
      return
    end

    vim.schedule(function()
      vim.lsp.util.jump_to_location(location, client.offset_encoding or "utf-16")
    end)
  end)
end

local function hide(buf, lnum, col_s, col_e, replacement)
  if col_e <= col_s then return end
  pcall(vim.api.nvim_buf_set_extmark, buf, ns, lnum, col_s, {
    end_col = col_e,
    conceal = replacement or "",
  })
end

local function hide_all(buf, lnum, line)
  hide(buf, lnum, 0, #line)
end

local function hide_literal(buf, lnum, line, literal, replacement)
  local pos = 1
  while true do
    local s = line:find(literal, pos, true)
    if not s then return end
    hide(buf, lnum, s - 1, s - 1 + #literal, replacement)
    pos = s + #literal
  end
end

local function render_javadoc_line(buf, lnum, line)
  local open_s = line:find("/%*%*")
  local close_s = line:find("%*/")

  if open_s and line:sub(1, open_s - 1):match("^%s*$") and line:sub(open_s + 3):match("^%s*$") then
    hide_all(buf, lnum, line)
    return
  end

  if close_s and line:sub(1, close_s - 1):match("^%s*%*?%s*$") and line:sub(close_s + 2):match("^%s*$") then
    hide_all(buf, lnum, line)
    return
  end

  if open_s then
    hide(buf, lnum, open_s - 1, open_s + 2)
  end

  if close_s then
    hide(buf, lnum, close_s - 1, close_s + 1)
  end

  local _, indent_end = line:find("^%s*")
  if indent_end and line:sub(indent_end + 1, indent_end + 1) == "*" then
    local content_s = indent_end + 2
    if line:sub(content_s, content_s) == " " then
      content_s = content_s + 1
    end
    hide(buf, lnum, indent_end, content_s - 1)
  end

  for _, tag in ipairs({ "<p>", "</p>", "<ul>", "</ul>", "</li>", "<pre>", "</pre>" }) do
    hide_literal(buf, lnum, line, tag)
  end

  hide_literal(buf, lnum, line, "<li>", "•")
  hide_literal(buf, lnum, line, "<br>", " ")
  hide_literal(buf, lnum, line, "<br/>", " ")
  hide_literal(buf, lnum, line, "<br />", " ")
end

local function render_buffer(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_loaded(buf) then return end
  if vim.bo[buf].filetype ~= "java" then return end
  if vim.b[buf].javadoc_render_off then return end

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local in_javadoc = false
  for lnum, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    if not in_javadoc then
      if line:find("/%*%*") then
        in_javadoc = true
        render_javadoc_line(buf, lnum - 1, line)
        if line:find("%*/") then
          in_javadoc = false
        end
      end
    else
      render_javadoc_line(buf, lnum - 1, line)
      if line:find("%*/") then
        in_javadoc = false
      end
    end
  end
end

local render_grp = vim.api.nvim_create_augroup("javadoc-render", { clear = true })

local function setup_window()
  vim.wo.conceallevel = 2
  vim.wo.concealcursor = "nc"
end

vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
  group = render_grp,
  pattern = { "java", "*.java" },
  callback = function(args)
    if vim.bo[args.buf].filetype ~= "java" then return end
    setup_window()
    render_buffer(args.buf)
  end,
})

local pending = {}
vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufReadPost", "BufWritePost" }, {
  group = render_grp,
  pattern = "*.java",
  callback = function(args)
    local buf = args.buf
    if pending[buf] then pending[buf]:stop() end
    pending[buf] = vim.defer_fn(function()
      pending[buf] = nil
      render_buffer(buf)
    end, 100)
  end,
})

vim.keymap.set("n", "<leader>jd", function()
  local buf = vim.api.nvim_get_current_buf()
  if vim.b[buf].javadoc_render_off then
    vim.b[buf].javadoc_render_off = false
    render_buffer(buf)
    vim.notify("Javadoc rendering: ON", vim.log.levels.INFO)
  else
    vim.b[buf].javadoc_render_off = true
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    vim.notify("Javadoc rendering: OFF (raw source)", vim.log.levels.INFO)
  end
end, { desc = "Java: toggle rendered javadoc comments" })

local function set_javadoc_keymaps(buf)
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].filetype ~= "java" then return end
  vim.keymap.set("n", "K", javadoc_hover, {
    buffer = buf,
    desc = "Java: hover with javadoc reference fallback",
  })
  vim.keymap.set("n", "gd", javadoc_definition, {
    buffer = buf,
    desc = "Java: definition with javadoc reference fallback",
  })
  vim.keymap.set("n", "<D-b>", javadoc_definition, {
    buffer = buf,
    desc = "Java: definition with javadoc reference fallback",
  })
end

local function schedule_javadoc_keymaps(buf)
  set_javadoc_keymaps(buf)
  vim.schedule(function()
    set_javadoc_keymaps(buf)
  end)
  vim.defer_fn(function()
    set_javadoc_keymaps(buf)
  end, 250)
  vim.defer_fn(function()
    set_javadoc_keymaps(buf)
  end, 1000)
end

vim.api.nvim_create_autocmd("FileType", {
  group = render_grp,
  pattern = "java",
  callback = function(args)
    schedule_javadoc_keymaps(args.buf)
  end,
})

vim.api.nvim_create_autocmd("BufEnter", {
  group = render_grp,
  pattern = "*.java",
  callback = function(args)
    schedule_javadoc_keymaps(args.buf)
  end,
})

vim.api.nvim_create_autocmd("LspAttach", {
  group = render_grp,
  callback = function(args)
    if vim.bo[args.buf].filetype ~= "java" then return end
    schedule_javadoc_keymaps(args.buf)
  end,
})

return {}

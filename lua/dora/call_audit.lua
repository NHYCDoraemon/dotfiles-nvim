local M = {}

M.defaults = {
  provider = "claude",
  snippet_radius = 8,
  panel_ratio = 0.48,
  toc_width = 24,
  evidence_width = 34,
}

local sections = {
  { key = "summary", label = "链路结论", hint = "这条链路到底做什么" },
  { key = "architecture", label = "架构视角", hint = "职责边界是否合理" },
  { key = "breakdown", label = "功能拆解", hint = "每一步输入/输出/状态" },
  { key = "dataflow", label = "数据流", hint = "关键值如何传递" },
  { key = "risks", label = "异常与风险", hint = "事务、幂等、权限、锁" },
  { key = "suggestions", label = "改进建议", hint = "只建议，不自动修改" },
}

local function merge_opts(opts)
  local merged = vim.tbl_extend("force", M.defaults, opts or {})
  merged.provider = merged.provider or vim.g.call_audit_provider or M.defaults.provider
  return merged
end

local function executable(path)
  return path and path ~= "" and vim.fn.executable(path) == 1
end

function M.resolve_executable(name, candidates)
  if not name or name == "" then return nil end
  if name:find("/", 1, true) then
    return executable(name) and name or nil
  end

  local from_path = vim.fn.exepath(name)
  if executable(from_path) then return from_path end

  local paths = {}
  if candidates then vim.list_extend(paths, candidates) end
  local home = vim.env.HOME or vim.fn.expand("~")
  vim.list_extend(paths, {
    home .. "/.local/bin/" .. name,
    home .. "/bin/" .. name,
    "/opt/homebrew/bin/" .. name,
    "/usr/local/bin/" .. name,
    "/usr/bin/" .. name,
  })

  for _, path in ipairs(paths) do
    if executable(path) then return path end
  end
  return nil
end

local function uri_to_path(uri)
  if not uri or uri == "" then return "" end
  if uri:match("^file://") then
    local ok, path = pcall(vim.uri_to_fname, uri)
    if ok then return path end
  end
  return uri
end

local function basename(path)
  return vim.fn.fnamemodify(path, ":t")
end

local function item_line(item)
  local range = item and (item.selectionRange or item.range)
  local start = range and range.start
  return start and ((start.line or 0) + 1) or 1
end

local function walk_nodes(root, visit)
  local seen = {}

  local function walk(node)
    if not node or not node.item then return end
    local key = table.concat({
      node.item.uri or "",
      node.item.name or "",
      tostring(item_line(node.item)),
    }, ":")
    if seen[key] then return end
    seen[key] = true
    visit(node)
    for _, child in ipairs(node.children or {}) do
      walk(child)
    end
  end

  walk(root)
end

local function source_snippet(path, center, radius)
  if path == "" or vim.fn.filereadable(path) ~= 1 then return {} end
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or not lines then return {} end

  local first = math.max(1, center - radius)
  local last = math.min(#lines, center + radius)
  local out = {}
  for lnum = first, last do
    table.insert(out, ("%4d | %s"):format(lnum, lines[lnum] or ""))
  end
  return out
end

local function summary_text(summary)
  local lines = {}
  if summary.actions and #summary.actions > 0 then
    table.insert(lines, "动作: " .. table.concat(summary.actions, " -> "))
  end
  if summary.properties and #summary.properties > 0 then
    table.insert(lines, "输入: " .. table.concat(summary.properties, ", "))
  end
  if summary.outputs and #summary.outputs > 0 then
    table.insert(lines, "输出: " .. table.concat(summary.outputs, ", "))
  end
  if summary.exceptions and #summary.exceptions > 0 then
    table.insert(lines, "异常: " .. table.concat(summary.exceptions, ", "))
  end
  return lines
end

local function build_prompt(context)
  local lines = {
    "你是一个资深代码审计解释器。请基于下面提供的调用图和源码片段做只读代码审计。",
    "",
    "硬性边界:",
    "- 只解释和审计，不修改文件。",
    "- 不执行 shell、构建、测试或 git 命令。",
    "- 只使用我提供的代码片段和文件行号作为证据。",
    "- 如果某个结论只是推断，必须明确标记为推断。",
    "",
    "输出格式必须稳定，使用这些中文小节:",
    "## 链路结论",
    "## 架构视角",
    "## 功能拆解",
    "## 数据流",
    "## 异常与风险",
    "## 改进建议",
    "",
    "调用图:",
    "```text",
  }

  vim.list_extend(lines, context.diagram_lines or {})
  vim.list_extend(lines, {
    "```",
    "",
    "证据与源码片段:",
  })

  for index, evidence in ipairs(context.evidence or {}) do
    table.insert(lines, ("### [%d] %s"):format(index, evidence.label))
    table.insert(lines, ("位置: %s:%d"):format(evidence.file, evidence.line))
    if evidence.role and evidence.role ~= "" then
      table.insert(lines, "角色: " .. evidence.role)
    end
    if evidence.summary and #evidence.summary > 0 then
      table.insert(lines, "摘要:")
      vim.list_extend(lines, evidence.summary)
    end
    if evidence.snippet and #evidence.snippet > 0 then
      table.insert(lines, "源码:")
      table.insert(lines, "```java")
      vim.list_extend(lines, evidence.snippet)
      table.insert(lines, "```")
    end
    table.insert(lines, "")
  end

  return table.concat(lines, "\n")
end

function M.build_context(root, opts)
  opts = merge_opts(opts)
  local graph = opts.graph or require("dora.call_hierarchy")
  local context = {
    root = root,
    opts = opts,
    title = opts.title or "AI Call Audit",
    diagram_lines = opts.diagram_lines or {},
    evidence = {},
  }

  walk_nodes(root, function(node)
    local item = node.item
    local path = uri_to_path(item.uri)
    local line = item_line(item)
    local summary = graph.method_summary and graph.method_summary(item, opts) or {}
    local summary_lines = summary_text(summary)
    local label = graph.label and graph.label(item) or (item.name or "(unknown)")
    local role = graph.node_role and graph.node_role(item) or ""

    table.insert(context.evidence, {
      id = #context.evidence + 1,
      item = item,
      label = label,
      role = role,
      uri = item.uri,
      path = path,
      file = basename(path),
      line = line,
      summary = summary_lines,
      snippet = source_snippet(path, line, opts.snippet_radius or 8),
    })
  end)

  context.prompt = build_prompt(context)
  return context
end

function M.initial_report_lines(opts)
  opts = merge_opts(opts)
  local lines = {
    "# AI 审计报告",
    "",
    ("状态: %s  Provider: %s"):format(opts.status or "idle", opts.provider or M.defaults.provider),
    "",
  }
  for _, section in ipairs(sections) do
    table.insert(lines, "## " .. section.label)
    table.insert(lines, "> " .. section.hint)
    table.insert(lines, "")
  end
  return lines
end

local function trim(text)
  local stripped = (text or ""):gsub("^%s+", "")
  stripped = stripped:gsub("%s+$", "")
  return stripped
end

local function strip_inline_markdown(text)
  text = text or ""
  text = text:gsub("%*%*(.-)%*%*", "%1")
  text = text:gsub("__(.-)__", "%1")
  text = text:gsub("%*(.-)%*", "%1")
  text = text:gsub("_(.-)_", "%1")
  text = text:gsub("`([^`]+)`", "%1")
  text = text:gsub("%[([^%]]+)%]%([^%)]+%)", "%1")
  return text
end

local function display_width(text)
  return vim.fn.strdisplaywidth(text or "")
end

local function display_pad(text, width)
  return (text or "") .. string.rep(" ", math.max(0, width - display_width(text)))
end

local function wrap_display(text, width)
  text = trim(strip_inline_markdown(text or ""))
  if text == "" then return { "" } end

  local lines = {}
  local current = ""
  local current_width = 0
  local chars = vim.fn.strchars(text)
  for index = 0, chars - 1 do
    local char = vim.fn.strcharpart(text, index, 1)
    local char_width = display_width(char)
    if current ~= "" and current_width + char_width > width then
      table.insert(lines, current)
      current = char
      current_width = char_width
    else
      current = current .. char
      current_width = current_width + char_width
    end
  end
  if current ~= "" then table.insert(lines, current) end
  return lines
end

local function is_table_line(line)
  local trimmed = trim(line)
  return trimmed:match("^|.+|$") ~= nil
end

local function parse_table_cells(line)
  local trimmed = trim(line):gsub("^|", ""):gsub("|$", "")
  local cells = {}
  for cell in (trimmed .. "|"):gmatch("(.-)|") do
    table.insert(cells, trim(strip_inline_markdown(cell)))
  end
  return cells
end

local function is_table_separator(cells)
  if not cells or #cells == 0 then return false end
  for _, cell in ipairs(cells) do
    if not trim(cell):match("^:?-+:?$") then return false end
  end
  return true
end

local function table_border(left, middle, right, widths)
  local parts = {}
  for _, width in ipairs(widths) do
    table.insert(parts, string.rep("─", width + 2))
  end
  return left .. table.concat(parts, middle) .. right
end

local function render_table_rows(out, rows, widths)
  for _, row in ipairs(rows) do
    local wrapped = {}
    local height = 1
    for index, width in ipairs(widths) do
      wrapped[index] = wrap_display(row[index] or "", width)
      height = math.max(height, #wrapped[index])
    end

    for line_index = 1, height do
      local cells = {}
      for index, width in ipairs(widths) do
        table.insert(cells, " " .. display_pad(wrapped[index][line_index] or "", width) .. " ")
      end
      table.insert(out, "│" .. table.concat(cells, "│") .. "│")
    end
  end
end

local function render_table(table_lines, opts)
  local rows = {}
  local column_count = 0
  for _, line in ipairs(table_lines) do
    local cells = parse_table_cells(line)
    if not is_table_separator(cells) then
      column_count = math.max(column_count, #cells)
      table.insert(rows, cells)
    end
  end
  if #rows == 0 or column_count == 0 then return table_lines end

  for _, row in ipairs(rows) do
    for index = 1, column_count do
      row[index] = row[index] or ""
    end
  end

  local widths = {}
  for column = 1, column_count do
    local width = 4
    for _, row in ipairs(rows) do
      width = math.max(width, display_width(row[column] or ""))
    end
    widths[column] = width
  end

  local max_width = math.max(40, (opts and (opts.table_width or opts.width)) or 120)
  local available = math.max(column_count * 6, max_width - (column_count * 3 + 1))
  local min_widths = {}
  for column = 1, column_count do
    min_widths[column] = math.max(4, math.min(widths[column], display_width(rows[1][column] or ""), 12))
  end

  local function total_width()
    local total = 0
    for _, width in ipairs(widths) do total = total + width end
    return total
  end

  while total_width() > available do
    local largest = nil
    for index, width in ipairs(widths) do
      if width > min_widths[index] and (not largest or width > widths[largest]) then
        largest = index
      end
    end
    if not largest then break end
    widths[largest] = widths[largest] - 1
  end

  local out = {}
  table.insert(out, table_border("┌", "┬", "┐", widths))
  render_table_rows(out, { rows[1] }, widths)
  table.insert(out, table_border("├", "┼", "┤", widths))
  local body = {}
  for index = 2, #rows do table.insert(body, rows[index]) end
  render_table_rows(out, body, widths)
  table.insert(out, table_border("└", "┴", "┘", widths))
  return out
end

function M.render_markdown_view(raw_lines, opts)
  local lines = {}
  local in_code = false
  local index = 1

  while index <= #(raw_lines or {}) do
    local raw = raw_lines[index]
    local line = raw or ""
    if not in_code and is_table_line(line) then
      local table_lines = {}
      while index <= #(raw_lines or {}) and is_table_line(raw_lines[index] or "") do
        table.insert(table_lines, raw_lines[index] or "")
        index = index + 1
      end
      vim.list_extend(lines, render_table(table_lines, opts or {}))
    elseif line:match("^%s*```") then
      in_code = not in_code
      if in_code then table.insert(lines, "代码") end
      index = index + 1
    elseif in_code then
      table.insert(lines, "  " .. line)
      index = index + 1
    else
      local heading = line:match("^%s*#+%s*(.-)%s*$")
      if heading then
        table.insert(lines, strip_inline_markdown(heading))
      else
        line = line:gsub("^%s*>%s?", "  ")
        line = line:gsub("^%s*[-*+]%s+", "• ")
        table.insert(lines, strip_inline_markdown(line))
      end
      index = index + 1
    end
  end

  return lines
end

function M.report_section_positions(lines)
  local positions = {}
  for lnum, line in ipairs(lines or {}) do
    local normalized = trim(line)
    for index, section in ipairs(sections) do
      if normalized == section.label and not positions[index] then
        positions[index] = lnum
      end
    end
  end
  return positions
end

local function decode_json(line)
  local ok, decoded = pcall(vim.json.decode, line)
  if ok then return decoded end
  return nil
end

function M.parse_claude_stream_json(line)
  local event = decode_json(line)
  if not event then return nil end
  if event.type == "stream_event" and type(event.event) == "table" then
    event = event.event
  end

  if event.type == "content_block_delta" and event.delta then
    if event.delta.type == "text_delta" and event.delta.text then
      return { text = event.delta.text }
    end
    return nil
  end

  local message = event.message
  if message and type(message.content) == "table" then
    local chunks = {}
    for _, part in ipairs(message.content) do
      if type(part) == "table" and part.type == "text" and part.text then
        table.insert(chunks, part.text)
      end
    end
    if #chunks > 0 then return { text = table.concat(chunks, "") } end
  end

  if event.type == "result" then
    return { done = true }
  end
  return nil
end

function M.parse_codex_event_json(line)
  local event = decode_json(line)
  if not event then return nil end

  if event.delta then
    return { text = event.delta }
  end
  if event.message and type(event.message) == "string" then
    return { text = event.message }
  end
  if event.type == "agent_message" and event.text then
    return { text = event.text }
  end
  if event.type == "task_complete" then
    return { done = true }
  end
  return nil
end

function M.provider_stdin(provider, prompt)
  if provider == "claude" then return prompt or "" end
  return nil
end

function M.provider_command(provider, cwd, prompt)
  provider = provider or M.defaults.provider
  cwd = cwd or vim.fn.getcwd()

  if provider == "claude" then
    return {
      M.resolve_executable("claude") or "claude",
      "-p",
      "--output-format",
      "stream-json",
      "--verbose",
      "--include-partial-messages",
      "--no-session-persistence",
      "--permission-mode",
      "dontAsk",
      "--add-dir",
      cwd,
    }
  end

  if provider == "codex" then
    return {
      M.resolve_executable("codex") or "codex",
      "exec",
      "--json",
      "--sandbox",
      "read-only",
      "-a",
      "never",
      "-C",
      cwd,
      prompt,
    }
  end

  return nil, "Unsupported provider: " .. tostring(provider)
end

local state = {
  job = nil,
  report_text = "",
  status = "idle",
  provider = M.defaults.provider,
  evidence_index = 1,
}

local ns = vim.api.nvim_create_namespace("dora-call-audit")

local audit_highlights = {
  DoraCallAuditTitle = { fg = "#286983", bold = true },
  DoraCallAuditStreaming = { fg = "#d7827e", bold = true },
  DoraCallAuditEvidence = { fg = "#56949f", bold = true },
  DoraCallAuditRisk = { fg = "#b4637a", bold = true },
  DoraCallAuditMuted = { fg = "#9893a5" },
  DoraCallAuditBorder = { fg = "#dfdad9" },
  DoraCallAuditSection = { fg = "#907aa9", bold = true },
  DoraCallAuditNormal = { bg = "#fffaf3" },
  DoraCallAuditCursorLine = { bg = "#f2e9e1" },
  DoraCallAuditStatus = { fg = "#286983", bg = "#f4ede8", bold = true },
}

local function setup_highlights()
  for group, spec in pairs(audit_highlights) do
    vim.api.nvim_set_hl(0, group, spec)
  end
end

local function set_buf_lines(buf, lines)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

local function make_buf(name, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buflisted = false
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = filetype or "call_audit"
  vim.bo[buf].modifiable = false
  if name then
    M._buf_counter = (M._buf_counter or 0) + 1
    pcall(vim.api.nvim_buf_set_name, buf, name .. " " .. M._buf_counter)
  end
  return buf
end

local function apply_report_highlights(buf, lines)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  setup_highlights()
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for lnum, line in ipairs(lines) do
    if lnum == 1 or line:match("^#") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DoraCallAuditTitle", lnum - 1, 0, -1)
    elseif line:match("^##") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DoraCallAuditSection", lnum - 1, 0, -1)
    elseif line:match("异常") or line:match("风险") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DoraCallAuditRisk", lnum - 1, 0, -1)
    elseif line:match("^状态:") or line:match("^>") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DoraCallAuditMuted", lnum - 1, 0, -1)
    end
  end
end

local function render_toc_lines()
  local lines = {
    "AI Call Audit",
    "Downstream Call Hierarchy",
    ("状态: %s"):format(state.status or "idle"),
    ("Provider: %s"):format(state.provider or M.defaults.provider),
    "",
    "审计目录",
    "",
  }
  for index, section in ipairs(sections) do
    local marker = state.active_section == index and ">" or " "
    table.insert(lines, ("%s %d. %s"):format(marker, index, section.label))
  end
  table.insert(lines, "")
  table.insert(lines, "操作")
  table.insert(lines, "1-5 跳转讲解")
  table.insert(lines, "6 改进建议")
  table.insert(lines, "E 重新审计")
  table.insert(lines, "S 停止流式")
  table.insert(lines, "C 复制报告")
  table.insert(lines, "q 关闭面板")
  return lines
end

local function render_report_lines()
  local lines
  if state.report_text and state.report_text ~= "" then
    lines = vim.split(state.report_text, "\n", { plain = true })
    table.insert(lines, 1, ("状态: %s  Provider: %s"):format(state.status or "idle", state.provider or M.defaults.provider))
    table.insert(lines, 1, "# AI 审计报告")
  else
    lines = M.initial_report_lines({ status = state.status, provider = state.provider })
  end
  local table_width = state.layout and state.layout.report_width or nil
  if state.wins and state.wins.report and vim.api.nvim_win_is_valid(state.wins.report) then
    table_width = math.max(40, vim.api.nvim_win_get_width(state.wins.report) - 2)
  end
  local rendered = M.render_markdown_view(lines, { table_width = table_width })
  state.report_section_lines = M.report_section_positions(rendered)
  return rendered
end

local function render_evidence_lines()
  local lines = {
    "证据与操作",
    "<CR> 跳转证据",
    "[/] 切换证据",
    "C 复制报告",
    "",
  }
  local by_line = {}
  for index, evidence in ipairs((state.context and state.context.evidence) or {}) do
    local marker = index == state.evidence_index and ">" or " "
    table.insert(lines, ("%s [%d] %s"):format(marker, index, evidence.label))
    by_line[#lines] = evidence
    table.insert(lines, ("    %s:%d"):format(evidence.file, evidence.line))
    by_line[#lines] = evidence
    if evidence.summary and #evidence.summary > 0 then
      table.insert(lines, "    " .. evidence.summary[1])
      by_line[#lines] = evidence
    end
    table.insert(lines, "")
  end
  state.evidence_by_line = by_line
  return lines
end

local function refresh_panel()
  if not state.bufs then return end
  local toc = render_toc_lines()
  local report = render_report_lines()
  local evidence = render_evidence_lines()

  set_buf_lines(state.bufs.toc, toc)
  set_buf_lines(state.bufs.report, report)
  set_buf_lines(state.bufs.evidence, evidence)
  apply_report_highlights(state.bufs.toc, toc)
  apply_report_highlights(state.bufs.report, report)
  apply_report_highlights(state.bufs.evidence, evidence)
end

local function jump_to_evidence(evidence)
  if not evidence or not evidence.uri then return end
  vim.lsp.util.show_document({
    uri = evidence.uri,
    range = evidence.item and (evidence.item.selectionRange or evidence.item.range),
  }, "utf-16", { focus = true })
end

local function selected_evidence()
  if not state.context then return nil end
  local buf = vim.api.nvim_get_current_buf()
  if buf == state.bufs.evidence then
    local line = vim.api.nvim_win_get_cursor(0)[1]
    return state.evidence_by_line and state.evidence_by_line[line]
  end
  return state.context.evidence and state.context.evidence[state.evidence_index]
end

local function move_evidence(delta)
  if not state.context or not state.context.evidence or #state.context.evidence == 0 then return end
  state.evidence_index = ((state.evidence_index - 1 + delta) % #state.context.evidence) + 1
  refresh_panel()
end

local function jump_report_section(index)
  if not state.wins or not vim.api.nvim_win_is_valid(state.wins.report) then return end
  if not state.report_section_lines then refresh_panel() end
  local line = state.report_section_lines and state.report_section_lines[index]
  if not line then return end

  state.active_section = index
  refresh_panel()
  vim.api.nvim_set_current_win(state.wins.report)
  pcall(vim.api.nvim_win_set_cursor, state.wins.report, { line, 0 })
  pcall(vim.cmd, "normal! zz")
end

local function set_panel_keymaps(buf)
  local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, silent = true, desc = desc })
  end

  for index = 1, #sections do
    map(tostring(index), function()
      jump_report_section(index)
    end, ("Call audit: section %d"):format(index))
  end

  map("E", function()
    if state.context then M.open(state.context.root, state.context.opts) end
  end, "Call audit: refresh")

  map("S", function()
    M.stop()
  end, "Call audit: stop")

  map("C", function()
    M.copy_report()
  end, "Call audit: copy report")

  map("<CR>", function()
    jump_to_evidence(selected_evidence())
  end, "Call audit: jump evidence")

  map("]", function()
    move_evidence(1)
  end, "Call audit: next evidence")

  map("[", function()
    move_evidence(-1)
  end, "Call audit: previous evidence")

  map("q", function()
    M.close()
  end, "Call audit: close")

  map("Q", function()
    local ok, graph = pcall(require, "dora.call_hierarchy")
    if ok and graph and graph.close_all then
      graph.close_all()
    else
      M.close()
    end
  end, "Call audit: close all hierarchy/audit panels")

  local function locked()
    vim.notify("AI audit panel is locked; close it with q before switching buffers.", vim.log.levels.INFO)
  end
  for _, lhs in ipairs({ "]b", "[b", "<S-l>", "<S-h>", "<leader>bn", "<leader>bp" }) do
    map(lhs, locked, "Call audit: locked buffer")
  end
end

function M.panel_layout(columns, lines, opts)
  opts = vim.tbl_extend("force", M.defaults, opts or {})
  local total_width = math.max(80, tonumber(columns) or vim.o.columns)
  local screen_lines = math.max(20, tonumber(lines) or vim.o.lines)
  local height = math.floor(screen_lines * (opts.panel_ratio or M.defaults.panel_ratio))
  height = math.max(12, math.min(height, screen_lines - 4))

  local toc_width = math.min(opts.toc_width or M.defaults.toc_width, math.floor(total_width * 0.22))
  local evidence_width = math.min(opts.evidence_width or M.defaults.evidence_width, math.floor(total_width * 0.32))
  toc_width = math.max(18, toc_width)
  evidence_width = math.max(30, evidence_width)

  local min_report = math.min(64, math.floor(total_width * 0.45))
  local report_width = total_width - toc_width - evidence_width
  if report_width < min_report then
    local shortage = min_report - report_width
    local evidence_reduce = math.min(shortage, math.max(0, evidence_width - 30))
    evidence_width = evidence_width - evidence_reduce
    shortage = shortage - evidence_reduce
    if shortage > 0 then
      local toc_reduce = math.min(shortage, math.max(0, toc_width - 18))
      toc_width = toc_width - toc_reduce
    end
    report_width = total_width - toc_width - evidence_width
  end

  return {
    total_width = total_width,
    height = height,
    toc_width = toc_width,
    report_width = report_width,
    evidence_width = evidence_width,
  }
end

local function focus_normal_window()
  local current = vim.api.nvim_get_current_win()
  local ok, config = pcall(vim.api.nvim_win_get_config, current)
  if ok and config and config.relative == "" then return current end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local win_ok, win_config = pcall(vim.api.nvim_win_get_config, win)
    if win_ok and win_config and win_config.relative == "" and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_set_current_win(win)
      return win
    end
  end
  return current
end

local function open_panel()
  if state.wins then
    for _, win in pairs(state.wins) do
      if vim.api.nvim_win_is_valid(win) then pcall(vim.api.nvim_win_close, win, true) end
    end
  end

  local original_win = focus_normal_window()
  local layout = M.panel_layout(vim.o.columns, vim.o.lines, state.opts)
  state.layout = layout
  state.bufs = {
    toc = make_buf("Call Audit TOC", "call_audit"),
    report = make_buf("Call Audit Report", "markdown"),
    evidence = make_buf("Call Audit Evidence", "call_audit"),
  }

  vim.cmd(("botright %dnew"):format(layout.height))
  state.wins = { toc = vim.api.nvim_get_current_win() }
  vim.api.nvim_win_set_buf(state.wins.toc, state.bufs.toc)

  vim.cmd("rightbelow vsplit")
  state.wins.report = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.wins.report, state.bufs.report)

  vim.cmd("rightbelow vsplit")
  state.wins.evidence = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.wins.evidence, state.bufs.evidence)

  if vim.api.nvim_win_is_valid(state.wins.toc) then
    vim.api.nvim_set_current_win(state.wins.toc)
    pcall(vim.cmd, ("vertical resize %d"):format(layout.toc_width))
  end
  if vim.api.nvim_win_is_valid(state.wins.evidence) then
    vim.api.nvim_set_current_win(state.wins.evidence)
    pcall(vim.cmd, ("vertical resize %d"):format(layout.evidence_width))
  end

  local winbars = {
    toc = "  审计目录",
    report = "  AI 审计报告",
    evidence = "  证据与操作",
  }
  for name, win in pairs(state.wins) do
    if vim.api.nvim_win_is_valid(win) then
      vim.wo[win].wrap = true
      vim.wo[win].number = false
      vim.wo[win].relativenumber = false
      vim.wo[win].cursorline = true
      vim.wo[win].winfixheight = true
      vim.wo[win].winfixwidth = true
      pcall(function() vim.wo[win].winfixbuf = true end)
      vim.wo[win].conceallevel = 3
      vim.wo[win].concealcursor = "nc"
      vim.wo[win].winhighlight =
        "Normal:DoraCallAuditNormal,CursorLine:DoraCallAuditCursorLine,StatusLine:DoraCallAuditStatus"
      vim.wo[win].statusline = " " .. (winbars[name] or "AI 审计")
      pcall(function() vim.wo[win].winbar = winbars[name] or "" end)
    end
  end

  for _, buf in pairs(state.bufs) do
    set_panel_keymaps(buf)
  end

  refresh_panel()
  if vim.api.nvim_win_is_valid(state.wins.report) then
    vim.api.nvim_set_current_win(state.wins.report)
  elseif vim.api.nvim_win_is_valid(original_win) then
    vim.api.nvim_set_current_win(original_win)
  end
end

local function parse_provider_line(line)
  if (state.provider or M.defaults.provider) == "codex" then
    return M.parse_codex_event_json(line)
  end
  return M.parse_claude_stream_json(line)
end

local function append_text(text)
  if not text or text == "" then return end
  state.report_text = (state.report_text or "") .. text
  refresh_panel()
end

local function start_job()
  local provider = state.provider or M.defaults.provider
  local command, err = M.provider_command(provider, state.cwd, state.context.prompt)
  local stdin = M.provider_stdin(provider, state.context.prompt)
  if not command then
    state.status = "failed"
    state.report_text = "## 启动失败\n\n" .. err
    refresh_panel()
    return
  end

  if vim.fn.executable(command[1]) ~= 1 then
    state.status = "failed"
    state.report_text = ("## 启动失败\n\nProvider executable not found: `%s`\n\n已检查 PATH、~/.local/bin、~/bin、/opt/homebrew/bin、/usr/local/bin。"):format(command[1])
    refresh_panel()
    return
  end

  state.status = "streaming"
  state.report_text = ""
  refresh_panel()

  local job_opts = {
    cwd = state.cwd,
    stdout_buffered = false,
    stderr_buffered = false,
    env = {
      CLAUDE_CODE_NON_INTERACTIVE = "1",
    },
    on_stdout = function(_, data)
      vim.schedule(function()
        for _, line in ipairs(data or {}) do
          if line ~= "" then
            local event = parse_provider_line(line)
            if event and event.text then
              append_text(event.text)
            end
          end
        end
      end)
    end,
    on_stderr = function(_, data)
      vim.schedule(function()
        local text = table.concat(vim.tbl_filter(function(line) return line ~= "" end, data or {}), "\n")
        if text ~= "" and state.report_text == "" then
          state.report_text = "## Provider 输出\n\n" .. text
          refresh_panel()
        end
      end)
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        if state.status == "stopped" then
          refresh_panel()
          return
        end
        state.job = nil
        state.status = code == 0 and "complete" or "failed"
        if state.report_text == "" then
          state.report_text = code == 0 and "## 完成\n\nProvider 没有返回可用文本。"
            or ("## Provider 失败\n\n退出码: " .. tostring(code))
        end
        refresh_panel()
      end)
    end,
  }
  if stdin then job_opts.stdin = "pipe" end

  state.job = vim.fn.jobstart(command, job_opts)

  if state.job <= 0 then
    state.status = "failed"
    state.report_text = "## 启动失败\n\n无法启动 provider job。"
    state.job = nil
    refresh_panel()
    return
  end

  if stdin then
    vim.fn.chansend(state.job, stdin)
    vim.fn.chanclose(state.job, "stdin")
  end
end

local function add_section(lines, title, body)
  table.insert(lines, "## " .. title)
  if type(body) == "table" then
    vim.list_extend(lines, body)
  elseif body and body ~= "" then
    table.insert(lines, body)
  end
  table.insert(lines, "")
end

function M.open(root, opts)
  opts = merge_opts(opts)
  local graph = opts.graph or require("dora.call_hierarchy")
  if not root then
    vim.notify("No call hierarchy graph available for audit", vim.log.levels.WARN)
    return
  end

  if state.job then M.stop() end
  local diagram_lines = opts.diagram_lines
  if not diagram_lines and graph.to_ascii_diagram then
    diagram_lines = graph.to_ascii_diagram(root, opts)
  end

  state.opts = opts
  state.cwd = opts.cwd or vim.fn.getcwd()
  state.provider = opts.provider or vim.g.call_audit_provider or M.defaults.provider
  state.status = "preparing"
  state.report_text = ""
  state.evidence_index = 1
  state.active_section = 1
  state.context = M.build_context(root, vim.tbl_extend("force", opts, {
    graph = graph,
    diagram_lines = diagram_lines or {},
  }))

  open_panel()
  if opts.start ~= false then start_job() end
end

function M.stop()
  if state.job then
    pcall(vim.fn.jobstop, state.job)
    state.job = nil
  end
  state.status = "stopped"
  refresh_panel()
end

function M.copy_report()
  local text = state.report_text
  if not text or text == "" then
    text = table.concat(render_report_lines(), "\n")
  end
  vim.fn.setreg("+", text)
  vim.notify("Call audit report copied to clipboard", vim.log.levels.INFO)
end

function M.close()
  if state.job then M.stop() end
  if state.wins then
    for _, win in pairs(state.wins) do
      if vim.api.nvim_win_is_valid(win) then pcall(vim.api.nvim_win_close, win, true) end
    end
  end
  state.wins = nil
  state.bufs = nil
end

function M.render_panel_lines(context, state)
  state = vim.tbl_deep_extend("force", {
    status = "idle",
    provider = M.defaults.provider,
    report = {},
  }, state or {})

  local lines = {
    "AI Call Audit",
    ("状态=%s  Provider=%s"):format(state.status, state.provider),
    "",
    "审计目录",
  }
  local maps = {
    evidence_lines = {},
    evidence_by_line = {},
  }

  for _, section in ipairs(sections) do
    table.insert(lines, ("  %s - %s"):format(section.label, section.hint))
  end

  table.insert(lines, "")
  table.insert(lines, "AI 审计报告")
  if state.report and #state.report > 0 then
    vim.list_extend(lines, M.render_markdown_view(state.report))
  else
    vim.list_extend(lines, M.render_markdown_view({
      "## 链路结论",
      "等待 AI 输出...",
      "",
      "## 架构视角",
      "等待 AI 输出...",
      "",
      "## 功能拆解",
      "等待 AI 输出...",
      "",
      "## 数据流",
      "等待 AI 输出...",
      "",
      "## 异常与风险",
      "等待 AI 输出...",
      "",
      "## 改进建议",
      "等待 AI 输出...",
    }))
  end

  table.insert(lines, "")
  table.insert(lines, "证据与操作")
  for _, evidence in ipairs(context.evidence or {}) do
    table.insert(lines, ("[%d] %s  %s:%d"):format(evidence.id, evidence.label, evidence.file, evidence.line))
    maps.evidence_by_line[#lines] = evidence
    table.insert(maps.evidence_lines, { line = #lines, evidence = evidence })
  end
  table.insert(lines, "")
  table.insert(lines, "E 刷新审计  S 停止  C 复制报告  <CR> 跳转证据  [/] 切换证据")

  return lines, maps
end

return M

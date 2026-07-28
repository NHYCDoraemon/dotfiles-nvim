local M = {}

M.defaults = {
  provider = "codex",
  codex_model = "gpt-5.6-sol",
  codex_reasoning_effort = "ultra",
  snippet_radius = 8,
  panel_ratio = 0.48,
  toc_width = 24,
  evidence_width = 34,
}

local sections = {
  { key = "summary", label = "调用结论", hint = "这条链路做什么，是否正确" },
  { key = "walkthrough", label = "执行过程", hint = "按实际顺序解释每一步" },
  { key = "dataflow", label = "数据与状态", hint = "输入、转换、副作用与输出" },
  { key = "correctness", label = "正确性核验", hint = "逐项说明事实、依据和成立条件" },
  { key = "boundaries", label = "上下文边界", hint = "明确未验证内容，不猜测" },
}

local section_labels = {}
for _, section in ipairs(sections) do
  section_labels[section.label] = true
end

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

local function source_snippet(path, center, radius, graph)
  if path == "" or vim.fn.filereadable(path) ~= 1 then return {} end
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or not lines then return {} end

  local first = math.max(1, center - radius)
  local last = math.min(#lines, center + radius)
  if graph and graph.collect_method_lines then
    local body = graph.collect_method_lines(lines, center, 160)
    last = math.max(last, math.min(#lines, center + #body - 1))
  end
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
  local direction = context.opts and context.opts.direction or "outgoing"
  local direction_text = direction == "incoming"
      and "上游调用者（incoming）：根节点是当前方法，子节点表示谁调用它。每条路径的执行方向是最外层调用者 → 直接调用者 → 当前方法；不同分支是不同入口路径，不是依次执行。"
    or "下游被调用者（outgoing）：从根节点出发，沿子节点查看它继续调用的方法；同级节点是否依次执行必须以方法体控制流为准。"
  local lines = {
    "你是调用链讲解员和正确性核验者。你只对「把整个调用过程讲准确，并说明其正确性」负责。",
    "请基于下面的调用图和仓库源码，给出证据充分、可复核的只读讲解。",
    "",
    "图的方向:",
    "- " .. direction_text,
    "- 必须先确认调用方向，再描述真实执行顺序；不得把上游调用者树误写成下游执行链。",
    "",
    "工作要求:",
    "- 先用只读工具（读文件/搜索）补齐与这条链路直接相关的完整方法体、调用方/被调用方、注解、配置和数据定义，再下结论。",
    "- 调用图只是导航线索，不代表完整上下文。沿可见路径补齐业务入口、当前方法及其相关后续调用，直到返回、异常或可观察副作用的边界。",
    "- 按真实控制流解释入口、参数校验、分支、逐层调用、状态变化、副作用、返回值和异常出口。",
    "- 对每个调用交接点核验：传入值从哪里来、被调用方使用什么、结果如何返回或继续传递。",
    "- 正确性结论只能依据已读取的代码和配置。每个实质性结论都必须给出证据位置（文件:行号）。",
    "- 「正确」仅表示当前证据能够证明调用关系、控制流、数据流和可见契约彼此一致；没有业务需求、外部契约或运行时数据时，不得宣称业务语义绝对正确。",
    "",
    "硬性边界:",
    "- 只读解释，不修改任何文件。",
    "- 不执行构建、测试或 git 写操作。",
    "- 不做架构设计评审、通用缺陷扫描、重构建议或改进建议，除非用户另行明确要求。",
    "- 不得猜测缺失代码、运行时行为或作者意图，也不得把「可能存在问题」包装成结论。",
    "- 上下文不足时，只能写「无法验证」，并准确列出缺少什么证据以及它影响哪一项判断。",
    "- 在未同时核对调用方、被调用方及相关契约前，不得对该调用交接点给出完整正确的判定。",
    "- 只有直接证据证明调用关系、数据传递或可见契约相互矛盾时，才能判定「不成立」。",
    "- 注意: 调用图经过业务视角过滤（框架代码、getter/setter、测试类被隐藏），不要把「图中未出现」当作「不存在」。",
    "- 分析期间不要输出计划、技能加载说明或阶段汇报。完成全部核验后，只输出一次最终讲解。",
    "",
    "输出格式必须稳定，使用这些中文小节:",
    "## 调用结论",
    "用简洁语言说明调用目标、实际起点与终点，并给出「已验证 / 部分可验证 / 无法验证」之一的总判定及适用范围。",
    "## 执行过程",
    "按真实执行顺序逐步讲解；覆盖图中每个节点。推荐表格列：步骤、调用方 → 被调用方、输入、动作、输出/状态、证据。",
    "## 数据与状态",
    "追踪关键参数、对象字段、持久化状态、外部副作用、返回值和异常如何产生、变化与传递。",
    "## 正确性核验",
    "逐项列出核验点、直接证据、结论（成立 / 不成立 / 无法验证）和成立条件。不得用猜测填充空白。",
    "## 上下文边界",
    "只列尚未读取或仓库内不存在、因而影响判断的具体证据；如果没有，明确写「未发现影响本次核验的上下文缺口」。",
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
    local source_path = evidence.path and evidence.path ~= "" and evidence.path or evidence.file
    table.insert(lines, ("位置: %s:%d"):format(source_path, evidence.line))
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
    title = opts.title or "AI Call Explanation",
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
      snippet = source_snippet(path, line, opts.snippet_radius or 8, graph),
    })
  end)

  context.prompt = build_prompt(context)
  return context
end

function M.initial_report_lines(opts)
  opts = merge_opts(opts)
  local lines = {
    "# AI 调用讲解",
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

  if event.type == "thread.started" then
    return { activity = "Codex 已启动" }
  end
  if event.type == "turn.started" then
    return { activity = "GPT-5.6 Sol · Ultra · Bypass 正在分析调用链" }
  end
  if event.type == "item.started" and type(event.item) == "table" then
    if event.item.type == "command_execution" then
      return { activity = "正在读取项目证据" }
    end
    return { activity = "正在核验调用步骤" }
  end
  if event.type == "item.completed" and type(event.item) == "table" then
    if event.item.type == "agent_message" and event.item.text then
      return {
        text = event.item.text,
        interim = true,
        activity = "已完成一阶段核验",
      }
    end
    if event.item.type == "reasoning" then
      return { activity = "已完成一轮推理", reasoning_done = true }
    end
    if event.item.type == "command_execution" then
      return { activity = "已读取项目证据", command_done = true }
    end
    return nil
  end
  if event.delta then
    return { text = event.delta, interim = true, delta = true }
  end
  if event.message and type(event.message) == "string" then
    return { text = event.message, interim = true }
  end
  if event.type == "agent_message" and event.text then
    return { text = event.text, interim = true }
  end
  if event.type == "task_complete" or event.type == "turn.completed" then
    return { done = true, activity = "讲解完成" }
  end
  return nil
end

function M.provider_stderr_text(provider, data)
  local lines = vim.tbl_filter(function(line)
    if line == "" then return false end
    return provider ~= "codex" or line ~= "Reading additional input from stdin..."
  end, data or {})
  return table.concat(lines, "\n")
end

function M.provider_stdin(provider, prompt)
  if provider == "claude" then return prompt or "" end
  return nil
end

function M.provider_command(provider, cwd, prompt, final_output_path)
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
      "--allowed-tools",
      "Read,Grep,Glob",
      "--add-dir",
      cwd,
    }
  end

  if provider == "codex" then
    local command = {
      M.resolve_executable("codex") or "codex",
      "--dangerously-bypass-approvals-and-sandbox",
      "exec",
      "-m",
      M.defaults.codex_model,
      "-c",
      ('model_reasoning_effort="%s"'):format(M.defaults.codex_reasoning_effort),
      "--json",
    }
    if final_output_path and final_output_path ~= "" then
      vim.list_extend(command, { "--output-last-message", final_output_path })
    end
    vim.list_extend(command, { "-C", cwd, prompt })
    return command
  end

  return nil, "Unsupported provider: " .. tostring(provider)
end

local state = {
  job = nil,
  report_text = "",
  status = "idle",
  provider = M.defaults.provider,
  evidence_index = 1,
  activity = "等待开始",
  commands_completed = 0,
  reasoning_rounds = 0,
  pending_message = "",
  progress_events = {},
  show_log = false,
}

local ns = vim.api.nvim_create_namespace("dora-call-audit")

local audit_highlight_links = {
  DoraCallAuditTitle = "Title",
  DoraCallAuditStreaming = "DiagnosticInfo",
  DoraCallAuditEvidence = "Identifier",
  DoraCallAuditRisk = "DiagnosticWarn",
  DoraCallAuditMuted = "Comment",
  DoraCallAuditBorder = "WinSeparator",
  DoraCallAuditSection = "Special",
}

local function setup_highlights()
  for group, target in pairs(audit_highlight_links) do
    vim.api.nvim_set_hl(0, group, { link = target })
  end
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("dora_call_explanation_highlights", { clear = true }),
  callback = vim.schedule_wrap(setup_highlights),
})
vim.schedule(setup_highlights)

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
    elseif line == "后台核验中" or line == "过程日志" or section_labels[line] then
      vim.api.nvim_buf_add_highlight(buf, ns, "DoraCallAuditSection", lnum - 1, 0, -1)
    elseif line:match("不成立") or line:match("无法验证") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DoraCallAuditRisk", lnum - 1, 0, -1)
    elseif line:match("后台核验") or line:match("^当前阶段:") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DoraCallAuditStreaming", lnum - 1, 0, -1)
    elseif line:match("^[>%s]%s*%[%d+%]") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DoraCallAuditEvidence", lnum - 1, 0, -1)
    elseif line:match("^状态:") or line:match("^>") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DoraCallAuditMuted", lnum - 1, 0, -1)
    end
  end
end

local clock = vim.uv or vim.loop

function M.format_duration(seconds)
  seconds = math.max(0, math.floor(tonumber(seconds) or 0))
  local hours = math.floor(seconds / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  local remainder = seconds % 60
  if hours > 0 then return ("%d:%02d:%02d"):format(hours, minutes, remainder) end
  return ("%02d:%02d"):format(minutes, remainder)
end

local function elapsed_seconds()
  if not state.started_at_ns then return 0 end
  local finish = state.finished_at_ns or clock.hrtime()
  return math.max(0, (finish - state.started_at_ns) / 1000000000)
end

local function elapsed_text()
  return M.format_duration(elapsed_seconds())
end

local status_labels = {
  idle = "等待",
  preparing = "准备中",
  streaming = "后台核验中",
  complete = "已完成",
  failed = "失败",
  stopped = "已停止",
}

local function status_text(status)
  return status_labels[status or "idle"] or tostring(status or "idle")
end

function M.progress_report_lines(context, progress)
  progress = vim.tbl_extend("force", {
    provider = M.defaults.provider,
    activity = "正在准备调用链上下文",
    elapsed = "00:00",
    commands_completed = 0,
    reasoning_rounds = 0,
    progress_events = {},
    show_log = false,
  }, progress or {})

  local evidence_count = #(context and context.evidence or {})
  local lines = {
    "# AI 调用讲解",
    "",
    ("状态: 后台核验中  Provider: %s  耗时: %s"):format(progress.provider, progress.elapsed),
    "",
    "## 后台核验中",
    "正在还原真实入口路径，并核对调用方、被调用方及相关契约。",
    "",
    "当前阶段: " .. progress.activity,
    ("工具读取: %d 次  推理阶段: %d  图中证据: %d 个节点"):format(
      progress.commands_completed,
      progress.reasoning_rounds,
      evidence_count
    ),
    "",
    "按 q 收起面板继续工作；任务会在后台运行，完成后主动通知。",
    "按 E 可随时回来查看，L 显示过程日志，S 停止任务。",
  }

  if progress.show_log then
    table.insert(lines, "")
    table.insert(lines, "## 过程日志")
    if #progress.progress_events == 0 then
      table.insert(lines, "尚无新的阶段事件。")
    else
      for _, entry in ipairs(progress.progress_events) do
        table.insert(lines, ("- %s  %s"):format(entry.elapsed or "00:00", entry.text or ""))
      end
    end
  end
  return lines
end

local function render_toc_lines()
  local lines = {
    "AI 调用讲解",
    ("状态 %s"):format(status_text(state.status)),
    ("耗时 %s"):format(elapsed_text()),
    ("读取 %d 次"):format(state.commands_completed or 0),
    "",
    "讲解目录",
    "",
  }
  for index, section in ipairs(sections) do
    local marker = state.active_section == index and ">" or " "
    table.insert(lines, ("%s %d. %s"):format(marker, index, section.label))
  end
  table.insert(lines, "")
  table.insert(lines, "操作")
  table.insert(lines, "1-5 跳转")
  table.insert(lines, "q 转入后台")
  table.insert(lines, "L 过程日志")
  table.insert(lines, "E 重新核验")
  table.insert(lines, "S 停止任务")
  table.insert(lines, "C 复制结果")
  table.insert(lines, "Q 收起三窗")
  return lines
end

local function render_report_lines()
  local lines
  if state.report_text and state.report_text ~= "" then
    lines = vim.split(state.report_text, "\n", { plain = true })
    table.insert(lines, 1, ("耗时: %s"):format(elapsed_text()))
    table.insert(lines, 1, ("状态: %s  Provider: %s"):format(
      status_text(state.status),
      state.provider or M.defaults.provider
    ))
    table.insert(lines, 1, "# AI 调用讲解")
  elseif state.status == "preparing" or state.status == "streaming" then
    lines = M.progress_report_lines(state.context, {
      provider = state.provider,
      activity = state.activity,
      elapsed = elapsed_text(),
      commands_completed = state.commands_completed,
      reasoning_rounds = state.reasoning_rounds,
      progress_events = state.progress_events,
      show_log = state.show_log,
    })
  else
    lines = M.initial_report_lines({ status = state.status, provider = state.provider })
    table.insert(lines, 3, ("耗时: %s"):format(elapsed_text()))
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
    "C 复制讲解",
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

local function add_progress(text)
  if not text or text == "" then return end
  local events = state.progress_events or {}
  local last = events[#events]
  if last and last.text == text then return end
  table.insert(events, { elapsed = elapsed_text(), text = text })
  while #events > 8 do
    table.remove(events, 1)
  end
  state.progress_events = events
end

local function stop_elapsed_timer()
  if not state.elapsed_timer then return end
  pcall(vim.fn.timer_stop, state.elapsed_timer)
  state.elapsed_timer = nil
end

local function start_elapsed_timer()
  stop_elapsed_timer()
  state.elapsed_timer = vim.fn.timer_start(5000, function()
    if state.status ~= "streaming" then
      stop_elapsed_timer()
      return
    end
    if state.bufs then refresh_panel() end
  end, { ["repeat"] = -1 })
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
    end, ("Call explanation: section %d"):format(index))
  end

  map("E", function()
    if not state.context then return end
    M.open(state.context.root, vim.tbl_extend("force", state.context.opts or {}, {
      force_refresh = true,
    }))
  end, "Call explanation: restart verification")

  map("L", function()
    state.show_log = not state.show_log
    refresh_panel()
  end, "Call explanation: toggle process log")

  map("S", function()
    M.stop()
  end, "Call explanation: stop")

  map("C", function()
    M.copy_report()
  end, "Call explanation: copy")

  map("<CR>", function()
    jump_to_evidence(selected_evidence())
  end, "Call explanation: jump evidence")

  map("]", function()
    move_evidence(1)
  end, "Call explanation: next evidence")

  map("[", function()
    move_evidence(-1)
  end, "Call explanation: previous evidence")

  map("q", function()
    M.hide()
  end, "Call explanation: continue in background")

  map("Q", function()
    M.hide()
  end, "Call explanation: hide all panes and continue in background")

  local function locked()
    vim.notify("讲解面板已锁定；按 q 收起后可继续编辑，任务会留在后台。", vim.log.levels.INFO)
  end
  for _, lhs in ipairs({ "]b", "[b", "<S-h>", "<leader>bn", "<leader>bp" }) do
    map(lhs, locked, "Call explanation: locked buffer")
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

local function panel_is_visible()
  return state.wins
    and state.wins.report
    and vim.api.nvim_win_is_valid(state.wins.report)
end

local function close_panel_windows()
  local managed = state.wins or {}
  local current = vim.api.nvim_get_current_win()
  local close_current = false
  state.wins = nil
  state.bufs = nil

  for _, win in pairs(managed) do
    if win == current then
      close_current = true
    elseif vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
  if close_current and vim.api.nvim_win_is_valid(current) then
    pcall(vim.api.nvim_win_close, current, true)
  end
end

local function open_panel()
  close_panel_windows()

  local original_win = focus_normal_window()
  local layout = M.panel_layout(vim.o.columns, vim.o.lines, state.opts)
  state.layout = layout
  state.bufs = {
    toc = make_buf("Call Explanation TOC", "call_audit"),
    report = make_buf("Call Explanation Report", "call_audit"),
    evidence = make_buf("Call Explanation Evidence", "call_audit"),
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
    toc = "  讲解目录",
    report = "  AI 调用讲解",
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
      vim.wo[win].statusline = " " .. (winbars[name] or "AI 调用讲解")
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

local function cleanup_final_output()
  local path = state.final_output_path
  if path and path ~= "" then pcall(vim.fn.delete, path) end
  state.final_output_path = nil
end

local function read_final_output()
  local path = state.final_output_path
  if not path or path == "" or vim.fn.filereadable(path) ~= 1 then return "" end
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or not lines then return "" end
  return trim(table.concat(lines, "\n"))
end

local function start_job()
  local provider = state.provider or M.defaults.provider
  local run_id = state.run_id
  cleanup_final_output()
  if provider == "codex" then
    state.final_output_path = vim.fn.tempname() .. "-call-explanation.md"
  end

  local command, err = M.provider_command(provider, state.cwd, state.context.prompt, state.final_output_path)
  local stdin = M.provider_stdin(provider, state.context.prompt)
  if not command then
    state.status = "failed"
    state.report_text = "## 启动失败\n\n" .. err
    cleanup_final_output()
    refresh_panel()
    return
  end

  if vim.fn.executable(command[1]) ~= 1 then
    state.status = "failed"
    state.report_text = ("## 启动失败\n\nProvider executable not found: `%s`\n\n已检查 PATH、~/.local/bin、~/bin、/opt/homebrew/bin、/usr/local/bin。"):format(command[1])
    cleanup_final_output()
    refresh_panel()
    return
  end

  state.status = "streaming"
  state.report_text = ""
  state.pending_message = ""
  state.provider_error = ""
  state.commands_completed = 0
  state.reasoning_rounds = 0
  state.progress_events = {}
  state.started_at_ns = clock.hrtime()
  state.finished_at_ns = nil
  state.activity = "正在启动 GPT-5.6 Sol · Ultra · Bypass"
  add_progress(state.activity)
  refresh_panel()
  start_elapsed_timer()

  local job_opts = {
    cwd = state.cwd,
    stdout_buffered = false,
    stderr_buffered = false,
    env = {
      CLAUDE_CODE_NON_INTERACTIVE = "1",
    },
    on_stdout = function(_, data)
      vim.schedule(function()
        if run_id ~= state.run_id then return end
        local should_refresh = false
        for _, line in ipairs(data or {}) do
          if line ~= "" then
            local event = parse_provider_line(line)
            if event and event.done and provider == "codex" then
              state.activity = "正在整理最终讲解"
              add_progress(state.activity)
              should_refresh = true
            elseif event and event.activity then
              state.activity = event.activity
              add_progress(event.activity)
              should_refresh = true
            end
            if event and event.text then
              if provider == "codex" then
                if event.delta then
                  state.pending_message = (state.pending_message or "") .. event.text
                else
                  state.pending_message = event.text
                end
                should_refresh = true
              else
                append_text(event.text)
              end
            end
            if event and event.command_done then
              state.commands_completed = (state.commands_completed or 0) + 1
              should_refresh = true
            end
            if event and event.reasoning_done then
              state.reasoning_rounds = (state.reasoning_rounds or 0) + 1
              should_refresh = true
            end
          end
        end
        if should_refresh and provider == "codex" then refresh_panel() end
      end)
    end,
    on_stderr = function(_, data)
      vim.schedule(function()
        if run_id ~= state.run_id then return end
        local text = M.provider_stderr_text(provider, data)
        if text ~= "" then
          local errors = vim.tbl_filter(function(value)
            return value ~= ""
          end, { state.provider_error or "", text })
          state.provider_error = trim(table.concat(errors, "\n"))
          state.activity = "Provider 返回了诊断信息"
          add_progress(state.activity)
          refresh_panel()
        end
      end)
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        if run_id ~= state.run_id then return end
        if state.status == "stopped" then
          stop_elapsed_timer()
          cleanup_final_output()
          refresh_panel()
          return
        end

        local final_output = read_final_output()
        cleanup_final_output()
        state.job = nil
        state.finished_at_ns = clock.hrtime()
        stop_elapsed_timer()
        state.status = code == 0 and "complete" or "failed"
        state.activity = code == 0 and "讲解完成" or "讲解失败"
        add_progress(state.activity)

        if code == 0 then
          if final_output ~= "" then
            state.report_text = final_output
          elseif state.report_text == "" and state.pending_message ~= "" then
            state.report_text = state.pending_message
          elseif state.report_text == "" then
            state.report_text = "## 完成\n\nProvider 没有返回可用的最终讲解。"
          end
        else
          state.report_text = "## Provider 失败\n\n退出码: " .. tostring(code)
          if state.provider_error and state.provider_error ~= "" then
            state.report_text = state.report_text .. "\n\n" .. state.provider_error
          end
        end

        local hidden = not panel_is_visible()
        refresh_panel()
        local message = code == 0 and "AI 调用讲解已完成" or "AI 调用讲解失败"
        if hidden then message = message .. "；回到调用图按 E 查看" end
        vim.notify(message, code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR)
      end)
    end,
    stdin = stdin and "pipe" or "null",
  }

  state.job = vim.fn.jobstart(command, job_opts)

  if state.job <= 0 then
    state.status = "failed"
    state.report_text = "## 启动失败\n\n无法启动 provider job。"
    state.job = nil
    state.finished_at_ns = clock.hrtime()
    stop_elapsed_timer()
    cleanup_final_output()
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
  local force_refresh = opts.force_refresh == true
  opts.force_refresh = nil
  local graph = opts.graph or require("dora.call_hierarchy")
  if not root then
    vim.notify("No call hierarchy graph available for explanation", vim.log.levels.WARN)
    return
  end

  local same_context = state.context and state.context.root == root
  local reusable = same_context
    and not force_refresh
    and (
      state.job ~= nil
      or state.status == "preparing"
      or state.status == "complete"
      or state.status == "failed"
    )
  if reusable then
    state.opts = opts
    if panel_is_visible() then
      refresh_panel()
      vim.api.nvim_set_current_win(state.wins.report)
    else
      open_panel()
    end
    return
  end

  if state.job then M.stop() end
  state.run_id = (state.run_id or 0) + 1
  local diagram_lines = opts.diagram_lines
  if not diagram_lines and graph.to_ascii_diagram then
    diagram_lines = graph.to_ascii_diagram(root, opts)
  end

  state.opts = opts
  state.cwd = opts.cwd or vim.fn.getcwd()
  state.provider = opts.provider or vim.g.call_audit_provider or M.defaults.provider
  state.status = "preparing"
  state.report_text = ""
  state.activity = "正在准备调用链上下文"
  state.commands_completed = 0
  state.reasoning_rounds = 0
  state.pending_message = ""
  state.progress_events = {}
  state.show_log = false
  state.started_at_ns = nil
  state.finished_at_ns = nil
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
  state.run_id = (state.run_id or 0) + 1
  if state.job then
    pcall(vim.fn.jobstop, state.job)
    state.job = nil
  end
  stop_elapsed_timer()
  cleanup_final_output()
  if state.started_at_ns and not state.finished_at_ns then state.finished_at_ns = clock.hrtime() end
  state.status = "stopped"
  state.activity = "任务已停止"
  add_progress(state.activity)
  refresh_panel()
end

function M.copy_report()
  local text = state.report_text
  if not text or text == "" then
    vim.notify("调用讲解尚未完成；可以按 q 转入后台，完成后再复制。", vim.log.levels.INFO)
    return
  end
  vim.fn.setreg("+", text)
  vim.notify("Call explanation copied to clipboard", vim.log.levels.INFO)
end

function M.hide()
  local running = state.job ~= nil
  close_panel_windows()
  vim.notify(
    running and "调用讲解已转入后台；完成后会通知。" or "调用讲解面板已收起；按 E 可再次查看。",
    vim.log.levels.INFO
  )
end

function M.close()
  if state.job then M.stop() end
  close_panel_windows()
  cleanup_final_output()
  state.context = nil
end

function M.render_panel_lines(context, state)
  state = vim.tbl_deep_extend("force", {
    status = "idle",
    provider = M.defaults.provider,
    report = {},
  }, state or {})

  local lines = {
    "AI Call Explanation",
    ("状态=%s  Provider=%s"):format(state.status, state.provider),
    "",
    "讲解目录",
  }
  local maps = {
    evidence_lines = {},
    evidence_by_line = {},
  }

  for _, section in ipairs(sections) do
    table.insert(lines, ("  %s - %s"):format(section.label, section.hint))
  end

  table.insert(lines, "")
  table.insert(lines, "AI 调用讲解")
  if state.report and #state.report > 0 then
    vim.list_extend(lines, M.render_markdown_view(state.report))
  elseif state.status == "preparing" or state.status == "streaming" then
    local progress = M.progress_report_lines(context, {
      provider = state.provider,
      activity = state.activity,
      elapsed = state.elapsed or "00:00",
      commands_completed = state.commands_completed or 0,
      reasoning_rounds = state.reasoning_rounds or 0,
      progress_events = state.progress_events or {},
      show_log = state.show_log,
    })
    table.remove(progress, 1)
    if progress[1] == "" then table.remove(progress, 1) end
    vim.list_extend(lines, M.render_markdown_view(progress))
  else
    vim.list_extend(lines, M.render_markdown_view({
      "## 调用结论",
      "等待 AI 输出...",
      "",
      "## 执行过程",
      "等待 AI 输出...",
      "",
      "## 数据与状态",
      "等待 AI 输出...",
      "",
      "## 正确性核验",
      "等待 AI 输出...",
      "",
      "## 上下文边界",
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
  table.insert(lines, "q/Q 后台收起  L 日志  E 重跑  S 停止  C 复制  <CR> 跳转证据  [/] 切换证据")

  return lines, maps
end

return M

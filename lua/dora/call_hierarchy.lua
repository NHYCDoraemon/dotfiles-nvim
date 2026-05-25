local M = {}

M.defaults = {
  max_depth = 4,
  max_nodes = 120,
  direction = "outgoing",
  business_view = true,
  exclude_patterns = {
    "^java%.",
    "^javax%.",
    "^jakarta%.",
    "^org%.springframework%.",
    "^org%.slf4j%.",
    "^ch%.qos%.logback%.",
    "^com%.fasterxml%.",
    "^lombok%.",
    "^kotlin%.",
    "^scala%.",
    "^reactor%.",
  },
}

local state_suffix = {
  cycle = "  ↺ 循环",
  duplicate = "  ↩ 重复",
  filtered = "  ⋯ 已过滤",
  truncated = "  ⋯ 已截断",
  error = "  ! 错误",
}

local ns = vim.api.nvim_create_namespace("dora-call-hierarchy")
local line_maps = {}

local function merge_opts(opts)
  return vim.tbl_deep_extend("force", M.defaults, opts or {})
end

local function basename(path)
  return vim.fn.fnamemodify(path, ":t")
end

local function uri_to_path(uri)
  if not uri or uri == "" then return "" end
  if uri:match("^file://") then
    local ok, path = pcall(vim.uri_to_fname, uri)
    if ok then return path end
  end
  return uri
end

local function range_line(item)
  local range = item and (item.selectionRange or item.range)
  local start = range and range.start
  return start and ((start.line or 0) + 1) or 1
end

function M.item_key(item)
  local range = item and (item.selectionRange or item.range) or {}
  local start = range.start or {}
  return table.concat({
    item and (item.uri or "") or "",
    item and (item.name or "") or "",
    tostring(start.line or 0),
    tostring(start.character or 0),
  }, ":")
end

local function strip_signature(name)
  name = name or ""
  name = name:gsub("%s*:.*$", "")
  name = name:gsub("%b()", "")
  name = name:gsub("%s+", "")
  return name
end

function M.method_name(item)
  local name = strip_signature(item and item.name or "")
  return name:match("([%w_$]+)$") or name
end

function M.owner_name(item)
  local detail = item and item.detail or ""
  detail = strip_signature(detail)
  detail = detail:gsub("<.->", "")
  detail = detail:gsub("%$", ".")
  if detail ~= "" then
    return detail:match("([%w_$]+)$") or detail
  end

  local path = uri_to_path(item and item.uri)
  local file = basename(path)
  return file:gsub("%.java$", ""):gsub("%.kt$", ""):gsub("%.go$", ""):gsub("%.rs$", ""):gsub("%.ts$", ""):gsub("%.lua$", "")
end

function M.label(item)
  if not item then return "(unknown)" end
  local owner = M.owner_name(item)
  local method = M.method_name(item)
  if owner ~= "" and method ~= "" and method ~= owner then
    return owner .. "." .. method
  end
  return method ~= "" and method or (item.name or "(anonymous)")
end

function M.location_text(item)
  local path = uri_to_path(item and item.uri)
  if path == "" then return "" end
  return ("%s:%d"):format(basename(path), range_line(item))
end

function M.should_skip_item(item, opts)
  opts = merge_opts(opts)
  local uri = item and item.uri or ""
  if uri:match("^jdt://") then return true end
  if uri:match("%.m2/repository/") then return true end

  local owner = M.owner_name(item)
  local method = M.method_name(item)
  if opts.business_view then
    if uri:match("/src/test/") or owner:match("Test$") or owner:match("Test%.") or owner:match("Test%$") then
      return true
    end
    if owner:match("Exception$") or method:match("Exception$") or method == owner then
      return true
    end
    if method:match("^get[A-Z]") or method:match("^set[A-Z]") or method:match("^is[A-Z]") or method:match("^has[A-Z]") then
      return true
    end
    if vim.tbl_contains({
      "id",
      "value",
      "name",
      "code",
      "message",
      "reason",
      "tenantId",
      "userId",
      "snapshotId",
      "workItemId",
      "actorUserId",
      "delegateeUserId",
      "candidateUserIds",
    }, method) then
      return true
    end
  end

  local haystack = table.concat({
    item and item.name or "",
    item and item.detail or "",
    uri,
  }, " ")
  for _, pattern in ipairs(opts.exclude_patterns or {}) do
    if haystack:match(pattern) then return true end
  end
  return false
end

function M.new_node(item, depth, state)
  return {
    item = item,
    depth = depth or 0,
    state = state or "ok",
    children = {},
  }
end

local function render_node(lines, line_map, node, prefix, is_last)
  local branch = node.depth == 0 and "" or (is_last and "└─ " or "├─ ")
  local next_prefix = node.depth == 0 and "" or (prefix .. (is_last and "   " or "│  "))
  local suffix = state_suffix[node.state] or ""
  local loc = M.location_text(node.item)
  local text = prefix .. branch .. M.label(node.item)
  if loc ~= "" then text = text .. "  " .. loc end
  text = text .. suffix

  table.insert(lines, text)
  line_map[#lines] = node

  for i, child in ipairs(node.children or {}) do
    render_node(lines, line_map, child, next_prefix, i == #node.children)
  end
end

function M.render_tree(root, opts)
  opts = merge_opts(opts)
  local title = opts.title or (opts.direction == "incoming" and "Incoming Call Hierarchy" or "Outgoing Call Hierarchy")
  local lines = {
    title,
    ("深度=%d  上限=%d  方向=%s  视图=%s"):format(
      opts.max_depth,
      opts.max_nodes,
      opts.direction == "incoming" and "上游" or "下游",
      opts.business_view and "业务优先" or "完整"
    ),
    "<CR> 跳转  K 文档  r 刷新  G 紧凑图  A Diagram图  E AI审计  P Preview图  y 复制链路  Y 导出DOT",
    "",
  }
  local line_map = {}
  render_node(lines, line_map, root, "", true)
  return lines, line_map
end

local function markdown_node(lines, node, depth)
  local marker = state_suffix[node.state] or ""
  local loc = M.location_text(node.item)
  table.insert(lines, ("%s- %s%s%s"):format(
    string.rep("  ", depth),
    M.label(node.item),
    loc ~= "" and (" `" .. loc .. "`") or "",
    marker
  ))
  for _, child in ipairs(node.children or {}) do
    markdown_node(lines, child, depth + 1)
  end
end

function M.to_markdown(root, opts)
  opts = merge_opts(opts)
  local lines = {
    "# " .. (opts.direction == "incoming" and "Incoming Call Hierarchy" or "Outgoing Call Hierarchy"),
    "",
  }
  markdown_node(lines, root, 0)
  return table.concat(lines, "\n")
end

local function dot_escape(text)
  return tostring(text):gsub("\\", "\\\\"):gsub("\"", "\\\"")
end

local roles = {
  controller = { label = "Controller / Entry", color = "#f2e9e1", border = "#d7827e" },
  service = { label = "Application Service", color = "#fffaf3", border = "#907aa9" },
  port = { label = "Port / Interface", color = "#f4ede8", border = "#56949f" },
  adapter = { label = "Adapter", color = "#faf4ed", border = "#ea9d34" },
  repository = { label = "Repository / Mapper", color = "#fffaf3", border = "#286983" },
  domain = { label = "Domain", color = "#f4ede8", border = "#b4637a" },
  other = { label = "Other", color = "#fffaf3", border = "#cecacd" },
}

local role_order = { "controller", "service", "domain", "port", "adapter", "repository", "other" }
local role_short = {
  controller = "入口",
  service = "服务",
  domain = "领域",
  port = "端口",
  adapter = "适配",
  repository = "存储",
  other = "其他",
}

function M.node_role(item)
  local owner = M.owner_name(item)
  local path = uri_to_path(item and item.uri)
  local haystack = owner .. " " .. path

  if haystack:match("Controller") or haystack:match("Listener") or haystack:match("Consumer") or haystack:match("Scheduler") then
    return "controller"
  end
  if haystack:match("Service") or haystack:match("/application/") or haystack:match("%.application%.") then
    return "service"
  end
  if haystack:match("Port$") or haystack:match("Port%.") then
    return "port"
  end
  if haystack:match("Adapter") or haystack:match("/infrastructure/") or haystack:match("%.infrastructure%.") then
    return "adapter"
  end
  if haystack:match("Repository") or haystack:match("Mapper") or haystack:match("Dao") then
    return "repository"
  end
  if haystack:match("/domain/") or haystack:match("%.domain%.") then
    return "domain"
  end
  return "other"
end

local function push_unique(list, seen, value)
  value = vim.trim(value or "")
  if value == "" or seen[value] then return end
  seen[value] = true
  table.insert(list, value)
end

local function strip_source_noise(line)
  line = line or ""
  line = line:gsub("//.*$", "")
  line = line:gsub("%s+", " ")
  return vim.trim(line)
end

local function collect_method_lines(lines, start_lnum, max_lines)
  local collected = {}
  local balance = 0
  local started = false

  for i = math.max(start_lnum or 1, 1), #lines do
    local line = lines[i] or ""
    table.insert(collected, line)

    local cleaned = line:gsub('".-"', '""')
    local opens = select(2, cleaned:gsub("{", ""))
    local closes = select(2, cleaned:gsub("}", ""))
    if opens > 0 then started = true end
    if started then balance = balance + opens - closes end
    if started and balance <= 0 then break end
    if #collected >= (max_lines or 80) then break end
  end

  return collected
end

local ignored_action = {
  ["if"] = true,
  ["for"] = true,
  ["while"] = true,
  ["switch"] = true,
  ["catch"] = true,
  ["return"] = true,
  ["new"] = true,
  ["throw"] = true,
  ["this"] = true,
  ["super"] = true,
  ["true"] = true,
  ["false"] = true,
  ["null"] = true,
  ["info"] = true,
  ["warn"] = true,
  ["error"] = true,
  ["debug"] = true,
  ["trace"] = true,
  ["format"] = true,
  ["ok"] = true,
  ["of"] = true,
  ["ofNullable"] = true,
  ["empty"] = true,
  ["builder"] = true,
  ["build"] = true,
  ["stream"] = true,
  ["map"] = true,
  ["filter"] = true,
  ["collect"] = true,
  ["toList"] = true,
  ["orElse"] = true,
  ["orElseGet"] = true,
  ["orElseThrow"] = true,
  ["isEmpty"] = true,
  ["size"] = true,
  ["equals"] = true,
  ["hashCode"] = true,
  ["toString"] = true,
  ["valueOf"] = true,
}

local ignored_property_owner = {
  log = true,
  logger = true,
  Objects = true,
  Collections = true,
  Optional = true,
  List = true,
  Map = true,
  Set = true,
  String = true,
  Math = true,
  R = true,
  ResponseEntity = true,
}

local ignored_property_method = vim.tbl_extend("force", ignored_action, {
  add = true,
  clear = true,
  contains = true,
  get = true,
  put = true,
  remove = true,
})

local summary_cache = {}

function M.method_summary(item, opts)
  opts = merge_opts(opts)
  local path = uri_to_path(item and item.uri)
  if path == "" or vim.fn.filereadable(path) ~= 1 then
    return { actions = {}, properties = {}, outputs = {}, exceptions = {} }
  end

  local cache_key = table.concat({ M.item_key(item), tostring(vim.fn.getftime(path)), tostring(opts.summary_max_lines or 80) }, "|")
  if summary_cache[cache_key] then return summary_cache[cache_key] end

  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or not lines then
    return { actions = {}, properties = {}, outputs = {}, exceptions = {} }
  end

  local body = collect_method_lines(lines, range_line(item), opts.summary_max_lines or 80)
  local actions, properties, outputs, exceptions = {}, {}, {}, {}
  local seen_actions, seen_properties, seen_outputs, seen_exceptions = {}, {}, {}, {}

  for _, raw in ipairs(body) do
    local line = strip_source_noise(raw)
    if line ~= "" and not line:match("^%*") and not line:match("^@") then
      local created = line:match("new%s+([%w_.$]+)%s*%(")
      if created and not created:match("Exception$") then
        push_unique(actions, seen_actions, "创建 " .. created:gsub(".*%.", ""))
      end

      local thrown = line:match("throw%s+new%s+([%w_.$]+)%s*%(")
      if thrown then
        local exception = thrown:gsub(".*%.", "")
        push_unique(actions, seen_actions, "抛出 " .. exception)
        push_unique(exceptions, seen_exceptions, exception)
      end

      local assigned = line:match("^[%w_<>,%[%]%?%.%s]+%s+([%w_]+)%s*=")
      if assigned and assigned ~= "var" then
        push_unique(outputs, seen_outputs, assigned)
      end

      local returned = line:match("^return%s+(.+);?$")
      if returned then
        returned = returned:gsub(";$", "")
        push_unique(outputs, seen_outputs, "return " .. returned)
      end

      local line_property_methods = {}
      for owner, method, args in line:gmatch("([%w_]+)%.([%w_]+)%s*%(([^()]*)%)") do
        if args:match("^%s*$") and not ignored_property_owner[owner] and not ignored_property_method[method] then
          push_unique(properties, seen_properties, owner .. "." .. method)
          line_property_methods[method] = true
        end
      end

      for fn in line:gmatch("([%a_][%w_]*)%s*%(") do
        if not ignored_action[fn] and not line_property_methods[fn] and not fn:match("^[A-Z][%w_]*$") and fn ~= M.method_name(item) then
          push_unique(actions, seen_actions, fn)
        end
      end
    end
  end

  local summary = { actions = actions, properties = properties, outputs = outputs, exceptions = exceptions }
  summary_cache[cache_key] = summary
  return summary
end

local function take(list, limit)
  local out = {}
  for i = 1, math.min(#(list or {}), limit or 4) do
    table.insert(out, list[i])
  end
  if #(list or {}) > (limit or 4) then
    table.insert(out, "...")
  end
  return out
end

local function truncate_display(text, max_width)
  text = tostring(text or "")
  if vim.fn.strdisplaywidth(text) <= max_width then return text end

  local out = ""
  local width = 0
  local budget = math.max(max_width - 1, 1)
  for i = 0, vim.fn.strchars(text) - 1 do
    local char = vim.fn.strcharpart(text, i, 1)
    local char_width = vim.fn.strdisplaywidth(char)
    if width + char_width > budget then break end
    out = out .. char
    width = width + char_width
  end
  return out .. "…"
end

local function pad_display(text, width)
  local padding = math.max(width - vim.fn.strdisplaywidth(text), 0)
  return text .. string.rep(" ", padding)
end

local function split_display_width(text, max_width)
  text = tostring(text or "")
  local chunks = {}
  local current = ""
  local width = 0

  for i = 0, vim.fn.strchars(text) - 1 do
    local char = vim.fn.strcharpart(text, i, 1)
    local char_width = vim.fn.strdisplaywidth(char)
    if current ~= "" and width + char_width > max_width then
      table.insert(chunks, current)
      current = char
      width = char_width
    else
      current = current .. char
      width = width + char_width
    end
  end

  if current ~= "" then table.insert(chunks, current) end
  if #chunks == 0 then table.insert(chunks, "") end
  return chunks
end

local function wrap_display(text, max_width)
  text = tostring(text or "")
  if vim.fn.strdisplaywidth(text) <= max_width then return { text } end

  local lines = {}
  local current = ""
  for token, space in text:gmatch("([^%s]+)(%s*)") do
    local candidate = current == "" and token or (current .. " " .. token)
    if vim.fn.strdisplaywidth(candidate) <= max_width then
      current = candidate
    else
      if current ~= "" then
        table.insert(lines, current)
        current = ""
      end
      if vim.fn.strdisplaywidth(token) > max_width then
        local segmented = token:gsub("([%._/$])", "%1 ")
        if segmented ~= token then
          for _, segment in ipairs(wrap_display(segmented, max_width)) do
            table.insert(lines, vim.trim(segment))
          end
        else
          vim.list_extend(lines, split_display_width(token, max_width))
        end
      else
        current = token
      end
    end
    if space:match("\n") and current ~= "" then
      table.insert(lines, current)
      current = ""
    end
  end

  if current ~= "" then table.insert(lines, current) end
  if #lines == 0 then table.insert(lines, "") end
  return lines
end

local function node_annotation_lines(item, opts)
  opts = merge_opts(opts)
  local summary = M.method_summary(item, opts)
  local lines = {}

  if summary.actions and #summary.actions > 0 then
    table.insert(lines, "做: " .. table.concat(take(summary.actions, opts.ascii_max_actions or 5), " → "))
  end
  if summary.properties and #summary.properties > 0 then
    table.insert(lines, "用: " .. table.concat(take(summary.properties, opts.ascii_max_properties or 5), ", "))
  end
  if summary.outputs and #summary.outputs > 0 then
    table.insert(lines, "产出: " .. table.concat(take(summary.outputs, opts.ascii_max_outputs or 4), ", "))
  end

  if not opts.ascii_no_truncate then
    local max_width = opts.ascii_detail_width or 116
    for i, line in ipairs(lines) do
      lines[i] = truncate_display(line, max_width)
    end
  end
  return lines
end

local function camel_words(text)
  text = tostring(text or "")
  text = text:gsub("([a-z0-9])([A-Z])", "%1 %2")
  text = text:gsub("[_%-]+", " ")
  return vim.trim(text)
end

local function intent_text(item)
  local method = M.method_name(item)
  local role = role_short[M.node_role(item)] or role_short.other
  local lowered = method:lower()
  local verb = "处理"

  if lowered:match("^get") or lowered:match("^find") or lowered:match("^load") or lowered:match("^read") or lowered:match("^query") or lowered:match("^list") then
    verb = "读取/查询"
  elseif lowered:match("^parse") or lowered:match("^resolve") or lowered:match("^from") then
    verb = "解析/转换"
  elseif lowered:match("^require") or lowered:match("^validate") or lowered:match("^check") then
    verb = "校验"
  elseif lowered:match("^save") or lowered:match("^persist") or lowered:match("^insert") or lowered:match("^update") or lowered:match("^delete") then
    verb = "持久化/变更"
  elseif lowered:match("^create") or lowered:match("^build") or lowered:match("^new") or lowered:match("^of") then
    verb = "创建"
  elseif lowered:match("^submit") then
    verb = "提交"
  elseif lowered:match("^publish") or lowered:match("^send") or lowered:match("^notify") then
    verb = "发布/通知"
  elseif lowered:match("^delegate") then
    verb = "委派"
  elseif lowered:match("^suspend") then
    verb = "暂停/挂起"
  elseif lowered:match("^resume") then
    verb = "恢复"
  elseif lowered:match("^complete") or lowered:match("^approve") or lowered:match("^reject") then
    verb = "推进状态"
  end

  return ("%s: %s %s"):format(role, verb, camel_words(method))
end

local function diagram_annotation_lines(item, opts)
  opts = merge_opts(opts)
  local summary = M.method_summary(item, opts)
  local lines = {
    "意图: " .. intent_text(item),
  }

  if summary.actions and #summary.actions > 0 then
    table.insert(lines, "动作: " .. table.concat(summary.actions, " → "))
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

local function render_ascii_node(lines, line_map, node, prefix, is_last, opts)
  local is_root = node.depth == 0
  local branch = is_root and "" or (is_last and "└─▶ " or "├─▶ ")
  local next_prefix = is_root and "" or (prefix .. (is_last and "   " or "│  "))
  local role = role_short[M.node_role(node.item)] or role_short.other
  local loc = M.location_text(node.item)
  local suffix = state_suffix[node.state] or ""
  local label = ("[%s] %s"):format(role, M.label(node.item))
  if loc ~= "" then label = label .. "  " .. loc end
  label = truncate_display(label .. suffix, opts.ascii_label_width or 104)

  table.insert(lines, prefix .. branch .. label)
  line_map[#lines] = node

  for _, annotation in ipairs(node_annotation_lines(node.item, opts)) do
    table.insert(lines, next_prefix .. "  " .. annotation)
    line_map[#lines] = node
  end

  for i, child in ipairs(node.children or {}) do
    render_ascii_node(lines, line_map, child, next_prefix, i == #node.children, opts)
  end
end

function M.to_ascii_graph(root, opts)
  opts = merge_opts(opts)
  local lines = {
    opts.title or (opts.direction == "incoming" and "Incoming Call Graph" or "Business Call Graph"),
    ("深度=%d  上限=%d  方向=%s  视图=%s"):format(
      opts.max_depth,
      opts.max_nodes,
      opts.direction == "incoming" and "上游" or "下游",
      opts.business_view and "业务优先" or "完整"
    ),
    "<CR> 跳转  K 文档  A Diagram图  E AI审计  P Preview图  y 复制ASCII  q/Esc关闭",
    "",
  }
  local line_map = {}
  render_ascii_node(lines, line_map, root, "", true, opts)
  return lines, line_map
end

local function diagram_box_lines(node, opts)
  opts = merge_opts(opts)
  local role = role_short[M.node_role(node.item)] or role_short.other
  local loc = M.location_text(node.item)
  local screen_columns = opts.diagram_screen_columns or vim.o.columns
  local dynamic_width = math.floor(screen_columns * 0.60)
  local max_width = opts.diagram_box_width or math.max(34, dynamic_width)
  local raw = {}
  vim.list_extend(raw, wrap_display(("[%s] %s"):format(role, M.label(node.item)), max_width))

  if loc ~= "" then
    vim.list_extend(raw, wrap_display("@ " .. loc, max_width))
  end

  for _, detail in ipairs(diagram_annotation_lines(node.item, opts)) do
    vim.list_extend(raw, wrap_display(detail, max_width))
  end

  local width = 24
  for _, line in ipairs(raw) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  width = math.min(width, max_width)

  local lines = { "┌" .. string.rep("─", width + 2) .. "┐" }
  for _, line in ipairs(raw) do
    table.insert(lines, "│ " .. pad_display(truncate_display(line, width), width) .. " │")
  end
  table.insert(lines, "└" .. string.rep("─", width + 2) .. "┘")
  return lines
end

local function render_ascii_diagram_node(lines, line_map, node, prefix, is_last, is_root, opts)
  local branch = is_root and "" or (is_last and "└──▶ " or "├──▶ ")
  local continuation = is_root and prefix or (prefix .. (is_last and "     " or "│    "))
  local box = diagram_box_lines(node, opts)

  for i, line in ipairs(box) do
    local lead = i == 1 and (prefix .. branch) or continuation
    table.insert(lines, lead .. line)
    line_map[#lines] = node
  end

  for i, child in ipairs(node.children or {}) do
    render_ascii_diagram_node(lines, line_map, child, continuation, i == #node.children, false, opts)
  end
end

function M.to_ascii_diagram(root, opts)
  opts = merge_opts(opts)
  local lines = {
    opts.title or (opts.direction == "incoming" and "Incoming Call Diagram" or "Business ASCII Diagram"),
    ("深度=%d  上限=%d  方向=%s  视图=%s"):format(
      opts.max_depth,
      opts.max_nodes,
      opts.direction == "incoming" and "上游" or "下游",
      opts.business_view and "业务优先" or "完整"
    ),
    "<CR> 跳转  K 文档  G 紧凑图  E AI审计  P Preview图  y 复制Diagram  q/Esc关闭",
    "",
  }
  local line_map = {}
  render_ascii_diagram_node(lines, line_map, root, "", true, true, opts)
  return lines, line_map
end

function M.ascii_window_size(lines, columns, rows)
  columns = columns or vim.o.columns
  rows = rows or vim.o.lines

  local longest = 80
  for _, line in ipairs(lines or {}) do
    longest = math.max(longest, vim.fn.strdisplaywidth(line))
  end

  local editor_width = math.max(20, columns - 4)
  local max_width = math.min(editor_width, math.max(40, math.floor(columns * 0.82)))
  local min_width = math.min(72, max_width)
  local wanted_width = math.min(longest + 4, max_width)

  local editor_height = math.max(6, rows - 4)
  local max_height = math.min(editor_height, math.max(10, math.floor(rows * 0.62)))
  local min_height = math.min(14, max_height)
  local wanted_height = math.min(#(lines or {}) + 2, max_height)

  return {
    width = math.max(min_width, wanted_width),
    height = math.max(min_height, wanted_height),
  }
end

local function collect_dot_graph(root)
  local nodes = {}
  local order = {}
  local edges = {}

  local function ensure(node)
    local key = M.item_key(node.item)
    if not nodes[key] then
      nodes[key] = {
        id = "n" .. (#order + 1),
        key = key,
        item = node.item,
        role = M.node_role(node.item),
      }
      table.insert(order, key)
    end
    return nodes[key]
  end

  local function walk(node)
    local from = ensure(node)
    for _, child in ipairs(node.children or {}) do
      if child.item and child.state ~= "truncated" and child.state ~= "error" then
        local to = ensure(child)
        table.insert(edges, { from = from.id, to = to.id, state = child.state })
        if child.state == "ok" then
          walk(child)
        end
      end
    end
  end

  walk(root)
  return nodes, order, edges
end

function M.to_dot(root, opts)
  opts = merge_opts(opts)
  local nodes, order, edges = collect_dot_graph(root)
  local by_role = {}
  for _, role in ipairs(role_order) do
    by_role[role] = {}
  end
  for _, key in ipairs(order) do
    local node = nodes[key]
    table.insert(by_role[node.role] or by_role.other, node)
  end

  local lines = {
    "digraph CallHierarchy {",
    "  rankdir=LR;",
    "  graph [bgcolor=\"#faf4ed\", pad=\"0.35\", nodesep=\"0.55\", ranksep=\"0.85\"];",
    "  node [shape=box, style=\"rounded,filled\", fontname=\"Liga Comic Mono\", fontsize=12, margin=\"0.12,0.08\"];",
    "  edge [color=\"#907aa9\"];",
    ("  label=\"%s\";"):format(dot_escape(opts.title or (opts.direction == "incoming" and "Incoming Call Hierarchy" or "Outgoing Call Hierarchy"))),
    "  labelloc=\"t\";",
    "  fontsize=18;",
  }

  for _, role in ipairs(role_order) do
    local grouped = by_role[role]
    if grouped and #grouped > 0 then
      local meta = roles[role]
      table.insert(lines, ("  subgraph cluster_%s {"):format(role))
      table.insert(lines, ("    label=\"%s\";"):format(meta.label))
      table.insert(lines, "    style=\"rounded,filled\";")
      table.insert(lines, "    color=\"#dfdad9\";")
      table.insert(lines, "    fillcolor=\"#fffaf3\";")
      for _, node in ipairs(grouped) do
        local label = dot_escape(M.label(node.item) .. "\\n" .. M.location_text(node.item))
        table.insert(lines, ("    %s [label=\"%s\", fillcolor=\"%s\", color=\"%s\"];"):format(
          node.id,
          label,
          meta.color,
          meta.border
        ))
      end
      table.insert(lines, "  }")
    end
  end

  for _, edge in ipairs(edges) do
    local attrs = edge.state == "cycle" and " [style=dashed, label=\"cycle\"]"
      or edge.state == "duplicate" and " [style=dotted]"
      or ""
    table.insert(lines, ("  %s -> %s%s;"):format(edge.from, edge.to, attrs))
  end

  table.insert(lines, "}")
  return table.concat(lines, "\n")
end

local function puml_escape(text)
  return tostring(text):gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("\n", "\\n")
end

function M.to_plantuml(root, opts)
  opts = merge_opts(opts)
  local nodes, order, edges = collect_dot_graph(root)
  local by_role = {}
  for _, role in ipairs(role_order) do
    by_role[role] = {}
  end
  for _, key in ipairs(order) do
    local node = nodes[key]
    table.insert(by_role[node.role] or by_role.other, node)
  end

  local lines = {
    "@startuml",
    "left to right direction",
    "skinparam shadowing false",
    "skinparam defaultFontName \"Liga Comic Mono\"",
    "skinparam packageStyle rectangle",
    ("title %s"):format(puml_escape(opts.title or "Business Call Graph")),
  }

  for _, role in ipairs(role_order) do
    local grouped = by_role[role]
    if grouped and #grouped > 0 then
      local meta = roles[role]
      table.insert(lines, ("package \"%s\" {"):format(puml_escape(meta.label)))
      for _, node in ipairs(grouped) do
        local label = puml_escape(M.label(node.item))
        table.insert(lines, ("  rectangle \"%s\" as %s %s"):format(label, node.id, meta.color))
      end
      table.insert(lines, "}")
    end
  end

  for _, edge in ipairs(edges) do
    table.insert(lines, ("%s --> %s"):format(edge.from, edge.to))
  end

  table.insert(lines, "@enduml")
  return table.concat(lines, "\n")
end

local graph_highlights = {
  DoraCallGraphBorder = { fg = "#907aa9" },
  DoraCallGraphArrow = { fg = "#d7827e", bold = true },
  DoraCallGraphEntry = { fg = "#d7827e", bold = true },
  DoraCallGraphService = { fg = "#907aa9", bold = true },
  DoraCallGraphDomain = { fg = "#b4637a", bold = true },
  DoraCallGraphPort = { fg = "#56949f", bold = true },
  DoraCallGraphAdapter = { fg = "#ea9d34", bold = true },
  DoraCallGraphRepository = { fg = "#286983", bold = true },
  DoraCallGraphOther = { fg = "#575279", bold = true },
  DoraCallGraphIntent = { fg = "#56949f", bold = true },
  DoraCallGraphAction = { fg = "#d7827e" },
  DoraCallGraphInput = { fg = "#907aa9" },
  DoraCallGraphOutput = { fg = "#286983" },
  DoraCallGraphException = { fg = "#b4637a", bold = true },
  DoraCallGraphLocation = { fg = "#9893a5" },
}

local role_highlight = {
  ["入口"] = "DoraCallGraphEntry",
  ["服务"] = "DoraCallGraphService",
  ["领域"] = "DoraCallGraphDomain",
  ["端口"] = "DoraCallGraphPort",
  ["适配"] = "DoraCallGraphAdapter",
  ["存储"] = "DoraCallGraphRepository",
  ["其他"] = "DoraCallGraphOther",
}

local function setup_graph_highlights()
  for group, spec in pairs(graph_highlights) do
    vim.api.nvim_set_hl(0, group, spec)
  end
end

local function add_line_match(buf, lnum, line, pattern, group)
  local start_col, end_col = line:find(pattern)
  if start_col then
    vim.api.nvim_buf_add_highlight(buf, ns, group, lnum - 1, start_col - 1, end_col)
  end
end

local function apply_graph_highlights(buf, lines)
  setup_graph_highlights()
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  for lnum, line in ipairs(lines) do
    if lnum == 1 then
      vim.api.nvim_buf_add_highlight(buf, ns, "Title", lnum - 1, 0, -1)
    elseif lnum <= 3 then
      vim.api.nvim_buf_add_highlight(buf, ns, "Comment", lnum - 1, 0, -1)
    end

    if line:find("[┌┐└┘│─]") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DoraCallGraphBorder", lnum - 1, 0, -1)
    end
    add_line_match(buf, lnum, line, "▶", "DoraCallGraphArrow")
    add_line_match(buf, lnum, line, "@ .+", "DoraCallGraphLocation")

    for role, group in pairs(role_highlight) do
      add_line_match(buf, lnum, line, "%[" .. role .. "%]", group)
    end

    add_line_match(buf, lnum, line, "意图:", "DoraCallGraphIntent")
    add_line_match(buf, lnum, line, "动作:", "DoraCallGraphAction")
    add_line_match(buf, lnum, line, "输入:", "DoraCallGraphInput")
    add_line_match(buf, lnum, line, "输出:", "DoraCallGraphOutput")
    add_line_match(buf, lnum, line, "异常:", "DoraCallGraphException")
  end
end

local jump_to_item

local function is_managed_buffer(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return false end
  local ft = vim.bo[buf].filetype
  local name = vim.api.nvim_buf_get_name(buf)
  return ft == "call_hierarchy"
    or ft == "call_hierarchy_graph"
    or ft == "call_audit"
    or name:match("Call Audit") ~= nil
    or name:match("Call Hierarchy") ~= nil
end

function M.close_all()
  local ok, audit = pcall(require, "dora.call_audit")
  if ok and audit and audit.close then pcall(audit.close) end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      if is_managed_buffer(buf) then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
  end

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if is_managed_buffer(buf) then
      line_maps[buf] = nil
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end

  vim.notify("Call hierarchy and AI audit panels closed", vim.log.levels.INFO)
end

local function open_text_buffer(lines, title, line_map)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "call_hierarchy_graph"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  if line_map then line_maps[buf] = line_map end

  local size = M.ascii_window_size(lines, vim.o.columns, vim.o.lines)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = size.width,
    height = size.height,
    row = math.floor((vim.o.lines - size.height) / 2),
    col = math.floor((vim.o.columns - size.width) / 2),
    border = "rounded",
    title = " " .. title .. " - q/Esc close ",
    title_pos = "center",
    style = "minimal",
  })
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false

  local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, silent = true, desc = desc })
  end

  local function node_under_cursor()
    local map_for_buf = line_maps[vim.api.nvim_get_current_buf()]
    return map_for_buf and map_for_buf[vim.api.nvim_win_get_cursor(0)[1]]
  end

  map("<CR>", function()
    local node = node_under_cursor()
    if node and jump_to_item then jump_to_item(node.item, true) end
  end, "Call graph: jump")

  map("K", function()
    local node = node_under_cursor()
    if not node or not jump_to_item then return end
    jump_to_item(node.item, true)
    vim.defer_fn(vim.lsp.buf.hover, 80)
  end, "Call graph: hover target")

  map("P", function()
    if M._last_root then M.render_graph(M._last_root, M._last_opts) end
  end, "Call graph: open Preview graph")

  map("E", function()
    if not M._last_root then return end
    local old_win = vim.api.nvim_get_current_win()
    require("dora.call_audit").open(M._last_root, vim.tbl_extend("force", M._last_opts or {}, {
      graph = M,
      diagram_lines = lines,
    }))
    if vim.api.nvim_win_is_valid(old_win) then pcall(vim.api.nvim_win_close, old_win, true) end
  end, "Call graph: AI audit")

  map("S", function()
    require("dora.call_audit").stop()
  end, "Call graph: stop AI audit")

  map("C", function()
    require("dora.call_audit").copy_report()
  end, "Call graph: copy AI audit")

  map("G", function()
    if not M._last_root then return end
    local old_win = vim.api.nvim_get_current_win()
    M.render_ascii_graph(M._last_root, M._last_opts)
    if vim.api.nvim_win_is_valid(old_win) then pcall(vim.api.nvim_win_close, old_win, true) end
  end, "Call graph: compact ASCII graph")

  map("A", function()
    if not M._last_root then return end
    local old_win = vim.api.nvim_get_current_win()
    M.render_ascii_diagram(M._last_root, M._last_opts)
    if vim.api.nvim_win_is_valid(old_win) then pcall(vim.api.nvim_win_close, old_win, true) end
  end, "Call graph: ASCII diagram")

  map("y", function()
    vim.fn.setreg("+", table.concat(lines, "\n"))
    vim.notify("Call graph ASCII copied to clipboard", vim.log.levels.INFO)
  end, "Call graph: copy ASCII")

  map("Y", function()
    if not M._last_root then return end
    vim.fn.setreg("+", M.to_dot(M._last_root, M._last_opts))
    vim.notify("Call graph DOT copied to clipboard", vim.log.levels.INFO)
  end, "Call graph: copy DOT")

  map("<Left>", "zh", "Call graph: scroll left")
  map("<Right>", "zl", "Call graph: scroll right")
  map("<S-Left>", "zH", "Call graph: scroll left faster")
  map("<S-Right>", "zL", "Call graph: scroll right faster")
  map("q", "<cmd>close<CR>", "Call graph: close")
  map("<Esc>", "<cmd>close<CR>", "Call graph: close")
  map("Q", M.close_all, "Call graph: close all hierarchy/audit panels")
  apply_graph_highlights(buf, lines)
  return buf, win
end

function M.render_ascii_graph(root, opts)
  opts = merge_opts(opts)
  local lines, line_map = M.to_ascii_graph(root, opts)
  M._last_ascii = { lines = lines }
  M._last_root = root
  M._last_opts = opts
  vim.fn.setreg("+", table.concat(lines, "\n"))
  open_text_buffer(lines, "Call Graph ASCII", line_map)
end

function M.render_ascii_diagram(root, opts)
  opts = merge_opts(opts)
  local lines, line_map = M.to_ascii_diagram(root, opts)
  M._last_ascii = { lines = lines }
  M._last_root = root
  M._last_opts = opts
  vim.fn.setreg("+", table.concat(lines, "\n"))
  open_text_buffer(lines, "Call Graph Diagram", line_map)
end

local function tmp_base()
  local dir = vim.env.TMPDIR or "/tmp/"
  if not dir:match("/$") then dir = dir .. "/" end
  return dir .. "dora-call-hierarchy-" .. os.time()
end

function M.render_graph(root, opts)
  opts = merge_opts(opts)
  local base = tmp_base()
  local dot_path = base .. ".dot"
  local pdf_path = base .. ".pdf"
  local svg_path = base .. ".svg"
  local dot = M.to_dot(root, opts)
  local fd = io.open(dot_path, "w")
  if not fd then
    vim.notify("Cannot write call graph DOT: " .. dot_path, vim.log.levels.ERROR)
    return nil
  end
  fd:write(dot)
  fd:close()

  M._last_graph = { dot = dot_path, pdf = pdf_path, svg = svg_path }
  vim.fn.setreg("+", dot)

  if vim.fn.executable("dot") ~= 1 then
    vim.notify("Graphviz `dot` not found. DOT copied to clipboard:\n" .. dot_path, vim.log.levels.WARN)
    return M._last_graph
  end

  vim.notify("Rendering call graph…", vim.log.levels.INFO)
  vim.fn.jobstart({ "dot", "-Tsvg", dot_path, "-o", svg_path }, { detach = true })
  vim.fn.jobstart({ "dot", "-Tpdf", dot_path, "-o", pdf_path }, {
    on_exit = function(_, code)
      vim.schedule(function()
        if code ~= 0 or vim.fn.filereadable(pdf_path) ~= 1 then
          vim.notify("Call graph render failed. DOT copied to clipboard:\n" .. dot_path, vim.log.levels.ERROR)
          return
        end
        vim.fn.jobstart({ "open", pdf_path }, { detach = true })
        vim.notify(table.concat({
          "Call graph rendered:",
          "  PDF: " .. pdf_path,
          "  SVG: " .. svg_path,
          "  DOT: " .. dot_path,
        }, "\n"), vim.log.levels.INFO, { title = "Call Graph", timeout = 8000 })
      end)
    end,
  })

  return M._last_graph
end

local method_pattern = [[^%s*[%w_<>,%[%]%?%s%.]+%s+[%w_]+%s*%([^;]*%)]]

function M.find_next_java_method_line(lines, start_lnum)
  for i = start_lnum, math.min(#lines, start_lnum + 30) do
    local line = lines[i] or ""
    if line:match(method_pattern) and not line:match("^%s*if%s*%(") and not line:match("^%s*for%s*%(") then
      return i
    end
  end
  return start_lnum
end

local function make_position_params(client)
  return vim.lsp.util.make_position_params(0, client and client.offset_encoding or "utf-16")
end

local function call_method(direction)
  return ("callHierarchy/%sCalls"):format(direction == "incoming" and "incoming" or "outgoing")
end

local function extract_call_item(call, direction)
  if direction == "incoming" then
    return call.from
  end
  return call.to
end

local function request_client(client, bufnr, method, params, cb)
  local ok = client:request(method, params, function(err, result)
    vim.schedule(function()
      cb(err, result)
    end)
  end, bufnr)
  if not ok then
    vim.schedule(function()
      cb("request failed", nil)
    end)
  end
end

jump_to_item = function(item, focus)
  if not item or not item.uri then return end
  local loc = {
    uri = item.uri,
    range = item.selectionRange or item.range,
  }
  vim.lsp.util.show_document(loc, "utf-16", { focus = focus ~= false })
end

local function current_tree_node()
  local buf = vim.api.nvim_get_current_buf()
  local map = line_maps[buf]
  if not map then return nil end
  return map[vim.api.nvim_win_get_cursor(0)[1]]
end

local function set_tree_keymaps(buf)
  local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, silent = true, desc = desc })
  end

  map("<CR>", function()
    local node = current_tree_node()
    if node then jump_to_item(node.item, true) end
  end, "Call hierarchy: jump")

  map("K", function()
    local node = current_tree_node()
    if not node then return end
    jump_to_item(node.item, true)
    vim.defer_fn(vim.lsp.buf.hover, 80)
  end, "Call hierarchy: hover target")

  map("r", function()
    if M._last_open then M.open(M._last_open) end
  end, "Call hierarchy: refresh")

  map("y", function()
    if not M._last_root then return end
    vim.fn.setreg("+", M.to_markdown(M._last_root, M._last_opts))
    vim.notify("Call hierarchy markdown copied to clipboard", vim.log.levels.INFO)
  end, "Call hierarchy: copy markdown")

  map("Y", function()
    if not M._last_root then return end
    local dot = M.to_dot(M._last_root, M._last_opts)
    local path = tmp_base() .. ".dot"
    local fd = io.open(path, "w")
    if fd then
      fd:write(dot)
      fd:close()
    end
    vim.fn.setreg("+", dot)
    vim.notify("DOT copied to clipboard" .. (fd and ("\n" .. path) or ""), vim.log.levels.INFO)
  end, "Call hierarchy: copy DOT")

  map("G", function()
    if not M._last_root then return end
    M.render_ascii_graph(M._last_root, M._last_opts)
  end, "Call hierarchy: open ASCII graph")

  map("A", function()
    if not M._last_root then return end
    M.render_ascii_diagram(M._last_root, M._last_opts)
  end, "Call hierarchy: open ASCII diagram")

  map("P", function()
    if not M._last_root then return end
    M.render_graph(M._last_root, M._last_opts)
  end, "Call hierarchy: open Preview graph")

  map("E", function()
    if not M._last_root then return end
    local diagram_lines = M.to_ascii_diagram(M._last_root, M._last_opts)
    require("dora.call_audit").open(M._last_root, vim.tbl_extend("force", M._last_opts or {}, {
      graph = M,
      diagram_lines = diagram_lines,
    }))
  end, "Call hierarchy: AI audit")

  map("S", function()
    require("dora.call_audit").stop()
  end, "Call hierarchy: stop AI audit")

  map("C", function()
    require("dora.call_audit").copy_report()
  end, "Call hierarchy: copy AI audit")

  map("q", "<cmd>close<CR>", "Call hierarchy: close")
  map("<Esc>", "<cmd>close<CR>", "Call hierarchy: close")
  map("Q", M.close_all, "Call hierarchy: close all hierarchy/audit panels")
end

local function apply_highlights(buf, lines, line_map)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for lnum, line in ipairs(lines) do
    if lnum == 1 then
      vim.api.nvim_buf_add_highlight(buf, ns, "Title", lnum - 1, 0, -1)
    elseif lnum == 2 then
      vim.api.nvim_buf_add_highlight(buf, ns, "Comment", lnum - 1, 0, -1)
    elseif line_map[lnum] then
      local node = line_map[lnum]
      local group = node.state == "ok" and "Normal" or "Comment"
      vim.api.nvim_buf_add_highlight(buf, ns, group, lnum - 1, 0, -1)
    end
  end
end

function M.open_buffer(root, opts)
  opts = merge_opts(opts)
  local lines, line_map = M.render_tree(root, opts)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "call_hierarchy"
  M._buf_counter = (M._buf_counter or 0) + 1
  vim.api.nvim_buf_set_name(buf, "Call Hierarchy " .. M._buf_counter)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  line_maps[buf] = line_map
  M._last_root = root
  M._last_opts = opts

  vim.cmd("botright vertical 52split")
  vim.api.nvim_win_set_buf(0, buf)
  vim.wo.wrap = false
  vim.wo.cursorline = true
  vim.wo.number = false
  vim.wo.relativenumber = false
  set_tree_keymaps(buf)
  apply_highlights(buf, lines, line_map)
end

local function notify_no_support()
  vim.notify("Current LSP does not support call hierarchy at this position", vim.log.levels.WARN)
end

function M.build_from_cursor(opts, done)
  opts = merge_opts(opts)
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  clients = vim.tbl_filter(function(client)
    return client.supports_method and client:supports_method("textDocument/prepareCallHierarchy", bufnr)
  end, clients)
  if #clients == 0 then
    notify_no_support()
    return
  end

  local client = clients[1]
  local params = make_position_params(client)
  request_client(client, bufnr, "textDocument/prepareCallHierarchy", params, function(err, result)
    if err or not result or vim.tbl_isempty(result) then
      notify_no_support()
      return
    end

    local root = M.new_node(result[1], 0)
    local seen = { [M.item_key(root.item)] = true }
    local node_count = 1
    local pending = 0
    local completed = false

    local function finish_if_idle()
      if not completed and pending == 0 then
        completed = true
        done(root, opts)
      end
    end

    local function expand(node, path)
      if node.depth >= opts.max_depth or node_count >= opts.max_nodes then
        return
      end

      pending = pending + 1
      request_client(client, bufnr, call_method(opts.direction), { item = node.item }, function(call_err, calls)
        pending = pending - 1
        if call_err then
          table.insert(node.children, M.new_node(node.item, node.depth + 1, "error"))
          finish_if_idle()
          return
        end

        for _, call in ipairs(calls or {}) do
          if node_count >= opts.max_nodes then
            table.insert(node.children, M.new_node(node.item, node.depth + 1, "truncated"))
            break
          end

          local child_item = extract_call_item(call, opts.direction)
          if child_item and not M.should_skip_item(child_item, opts) then
            local key = M.item_key(child_item)
            local state = "ok"
            if path[key] then
              state = "cycle"
            elseif seen[key] then
              state = "duplicate"
            end

            local child = M.new_node(child_item, node.depth + 1, state)
            table.insert(node.children, child)
            node_count = node_count + 1

            if state == "ok" then
              seen[key] = true
              local next_path = vim.deepcopy(path)
              next_path[key] = true
              expand(child, next_path)
            end
          end
        end
        finish_if_idle()
      end)
    end

    expand(root, { [M.item_key(root.item)] = true })
    finish_if_idle()
  end)
end

function M.open(opts)
  opts = merge_opts(opts)
  M._last_open = opts
  vim.notify("Building call hierarchy…", vim.log.levels.INFO)
  M.build_from_cursor(opts, function(root, build_opts)
    M.open_buffer(root, build_opts)
    if build_opts.graph_first == "preview" then
      M.render_graph(root, build_opts)
    elseif build_opts.graph_first == "diagram" then
      M.render_ascii_diagram(root, build_opts)
    elseif build_opts.graph_first then
      M.render_ascii_graph(root, build_opts)
    end
  end)
end

function M.jump_to_next_java_method(start_lnum)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local lnum = M.find_next_java_method_line(lines, start_lnum)
  local text = lines[lnum] or ""
  local name_start = text:find("[%w_]+%s*%(") or 1
  vim.api.nvim_win_set_cursor(0, { lnum, math.max(name_start - 1, 0) })
end

function M.open_spring_entries()
  Snacks.picker.grep({
    search = [[^\s*@(RequestMapping|GetMapping|PostMapping|PutMapping|DeleteMapping|PatchMapping|KafkaListener|RabbitListener|JmsListener|EventListener|Scheduled)\b]],
    regex = true,
    live = false,
    title = "Spring entries → downstream call hierarchy",
    ft = { "java" },
    confirm = function(picker, item)
      picker:close()
      if not item or not item.file or not item.pos then return end
      vim.cmd.edit(vim.fn.fnameescape(item.file))
      vim.api.nvim_win_set_cursor(0, { item.pos[1], item.pos[2] or 0 })
      M.jump_to_next_java_method(item.pos[1])
      vim.defer_fn(function()
        M.open({
          direction = "outgoing",
          title = "Spring Entry Downstream",
          max_depth = 3,
          max_nodes = 80,
          business_view = true,
          graph_first = "ascii",
        })
      end, 120)
    end,
  })
end

function M.setup(opts)
  M.defaults = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M

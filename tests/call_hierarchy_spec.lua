vim.opt.runtimepath:append(vim.fn.getcwd())
package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

local graph = require("dora.call_hierarchy")

local function assert_eq(actual, expected, label)
  if actual ~= expected then
    error(("%s\nexpected: %s\nactual:   %s"):format(label or "assert_eq failed", vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

local function assert_match(value, pattern, label)
  if not tostring(value):match(pattern) then
    error(("%s\npattern: %s\nvalue:   %s"):format(label or "assert_match failed", pattern, tostring(value)), 2)
  end
end

local function assert_not_match(value, pattern, label)
  if tostring(value):match(pattern) then
    error(("%s\nunexpected pattern: %s\nvalue:   %s"):format(label or "assert_not_match failed", pattern, tostring(value)), 2)
  end
end

local function item(name, detail, path, line)
  return {
    name = name,
    detail = detail,
    uri = path:match("^%a[%w+.-]*:") and path or vim.uri_from_fname(path),
    selectionRange = {
      start = { line = line or 0, character = 2 },
      ["end"] = { line = line or 0, character = 12 },
    },
    range = {
      start = { line = line or 0, character = 0 },
      ["end"] = { line = line or 0, character = 20 },
    },
  }
end

local function run(name, fn)
  fn()
  print("ok - " .. name)
end

local function temp_java(lines)
  local path = vim.fn.tempname() .. ".java"
  vim.fn.writefile(lines, path)
  return path
end

run("filters framework and dependency call hierarchy items", function()
  assert_eq(graph.should_skip_item(item("requireNonNull", "java.util.Objects", "jdt://contents/java.base/Objects.class", 1)), true)
  assert_eq(graph.should_skip_item(item("createBean", "org.springframework.beans.BeanFactory", "jdt://contents/spring-beans/BeanFactory.class", 1)), true)
  assert_eq(graph.should_skip_item(item("publish", "com.nhyc.event.EventPublishingPort", "/repo/src/EventPublishingPort.java", 8)), false)
end)

run("filters test fakes, exception constructors, and value accessors in business view", function()
  assert_eq(graph.should_skip_item(item(
    "findById(TenantId, long) : Optional<NodeSnapshot>",
    "com.nhyc.process.CrossSubprocessRetreatRejectionTest$InMemorySnapshotRepository",
    "/repo/src/test/java/com/nhyc/process/CrossSubprocessRetreatRejectionTest.java",
    88
  )), true, "test fake repository should be hidden")
  assert_eq(graph.should_skip_item(item(
    "BusinessException(ErrorCode, String)",
    "com.nhyc.shared.BusinessException",
    "/repo/src/main/java/com/nhyc/shared/BusinessException.java",
    18
  )), true, "exception constructors should be hidden")
  assert_eq(graph.should_skip_item(item(
    "tenantId() : TenantId",
    "com.nhyc.process.NodeSnapshot",
    "/repo/src/main/java/com/nhyc/process/NodeSnapshot.java",
    281
  )), true, "record-style accessors should be hidden")
end)

run("compacts jdtls method signatures into readable class method labels", function()
  local label = graph.label(item(
    "suspendAlert(String, SuspendAlertRequest, HttpServletRequest) : R<NodeSnapshotView>",
    "com.nhyc.process.RuntimeWorkItemActionController",
    "/repo/src/main/java/com/nhyc/process/RuntimeWorkItemActionController.java",
    112
  ))

  assert_eq(label, "RuntimeWorkItemActionController.suspendAlert")
end)

run("renders call hierarchy tree with duplicates and cycles", function()
  local root = graph.new_node(item("publish", "com.nhyc.web.EventController", "/repo/src/EventController.java", 10), 0)
  local service = graph.new_node(item("persist", "com.nhyc.app.EventService", "/repo/src/EventService.java", 22), 1)
  local repo = graph.new_node(item("save", "com.nhyc.infra.EventRepository", "/repo/src/EventRepository.java", 40), 2)
  local duplicate = graph.new_node(item("save", "com.nhyc.infra.EventRepository", "/repo/src/EventRepository.java", 40), 2, "duplicate")
  local cycle = graph.new_node(item("publish", "com.nhyc.web.EventController", "/repo/src/EventController.java", 10), 3, "cycle")

  root.children = { service }
  service.children = { repo, duplicate, cycle }

  local lines, line_map = graph.render_tree(root, { direction = "outgoing", title = "Downstream" })

  assert_match(lines[1], "Downstream", "title is rendered")
  assert_match(table.concat(lines, "\n"), "EventController%.publish", "root label includes type and method")
  assert_match(table.concat(lines, "\n"), "重复", "duplicate marker is rendered")
  assert_match(table.concat(lines, "\n"), "循环", "cycle marker is rendered")
  assert_eq(line_map[6].item.name, "persist", "line map points at navigable node")
end)

run("exports markdown and dot from rendered tree", function()
  local root = graph.new_node(item("entry", "com.nhyc.web.AdminController", "/repo/src/AdminController.java", 10), 0)
  root.children = {
    graph.new_node(item("handle", "com.nhyc.app.AdminService", "/repo/src/AdminService.java", 20), 1),
  }

  local markdown = graph.to_markdown(root, { direction = "outgoing" })
  assert_match(markdown, "%- AdminController%.entry", "markdown includes root")
  assert_match(markdown, "AdminService%.handle", "markdown includes child")

  local dot = graph.to_dot(root, { direction = "outgoing" })
  assert_match(dot, "digraph", "dot starts graph")
  assert_match(dot, "\"AdminController%.entry", "dot includes root node")
  assert_match(dot, "%-%>", "dot includes edge")
end)

run("groups business graph nodes by role in DOT", function()
  local root = graph.new_node(item("submit", "com.nhyc.web.RuntimeFormViewController", "/repo/src/RuntimeFormViewController.java", 59), 0)
  local service = graph.new_node(item("submit", "com.nhyc.application.RuntimeFormSubmissionService", "/repo/src/RuntimeFormSubmissionService.java", 96), 1)
  local port = graph.new_node(item("findSchemaById", "com.nhyc.application.FormPort", "/repo/src/FormPort.java", 46), 2)
  local adapter = graph.new_node(item("findSchemaById", "com.nhyc.infrastructure.LocalFormAdapter", "/repo/src/LocalFormAdapter.java", 124), 3)
  root.children = { service }
  service.children = { port }
  port.children = { adapter }

  local dot = graph.to_dot(root, { direction = "outgoing", title = "Business Call Graph" })

  assert_match(dot, "rankdir=LR", "graph should be horizontal")
  assert_match(dot, "cluster_controller", "controller cluster is present")
  assert_match(dot, "cluster_service", "service cluster is present")
  assert_match(dot, "cluster_port", "port cluster is present")
  assert_match(dot, "cluster_adapter", "adapter cluster is present")
  assert_match(dot, "RuntimeFormViewController%.submit", "graph includes compact labels")
end)

run("exports PlantUML source for in-editor ASCII graph rendering", function()
  local root = graph.new_node(item("submit", "com.nhyc.web.RuntimeFormViewController", "/repo/src/RuntimeFormViewController.java", 59), 0)
  local service = graph.new_node(item("submit", "com.nhyc.application.RuntimeFormSubmissionService", "/repo/src/RuntimeFormSubmissionService.java", 96), 1)
  root.children = { service }

  local puml = graph.to_plantuml(root, { title = "Business ASCII Graph" })

  assert_match(puml, "@startuml", "plantuml starts")
  assert_match(puml, "left to right direction", "plantuml requests horizontal graph")
  assert_match(puml, "package \"Controller / Entry\"", "plantuml groups controller role")
  assert_match(puml, "RuntimeFormViewController%.submit", "plantuml includes compact root label")
  assert_not_match(puml, "\\\\n", "plantuml should contain real PlantUML newlines, not literal backslash-n text")
  assert_match(puml, "%-%->", "plantuml includes edge")
  assert_match(puml, "@enduml", "plantuml ends")
end)

run("summarizes Java method body actions and accessed properties", function()
  local path = temp_java({
    "package com.nhyc.application;",
    "class RuntimeFormSubmissionService {",
    "  public SubmitFormResult submit(SubmitFormCommand command) {",
    "    requireMatchingTenant(command.tenantId());",
    "    FormRuntimeViewSnapshot snapshot = loadSnapshot(command);",
    "    FormPort.FormSchemaView schema = formPort.findSchemaById(command.tenantId(), command.schemaKey(), command.schemaVersion())",
    "      .orElseThrow(() -> new ProcessDeploymentException(ErrorCode.FORM_NOT_FOUND, \"missing\"));",
    "    RuntimeFormViewService.RuntimeFormView view = rehydrateRuntimeView(snapshot, schema);",
    "    List<FormPort.ValidationError> providerErrors = providerErrors(view);",
    "    return accepted(command.traceId(), snapshot.snapshotId(), view);",
    "  }",
    "}",
  })

  local summary = graph.method_summary(item(
    "submit(SubmitFormCommand command) : SubmitFormResult",
    "com.nhyc.application.RuntimeFormSubmissionService",
    path,
    2
  ))

  assert_match(table.concat(summary.actions, " "), "requireMatchingTenant", "summary includes local validation action")
  assert_match(table.concat(summary.actions, " "), "loadSnapshot", "summary includes loading action")
  assert_match(table.concat(summary.actions, " "), "findSchemaById", "summary includes port call")
  assert_match(table.concat(summary.properties, " "), "command%.tenantId", "summary includes accessed tenant property")
  assert_match(table.concat(summary.properties, " "), "command%.schemaKey", "summary includes accessed schema key")
  assert_match(table.concat(summary.outputs, " "), "snapshot", "summary includes produced local value")
end)

run("renders compact ASCII graph with explicit arrows and method summaries", function()
  local path = temp_java({
    "class RuntimeFormSubmissionService {",
    "  public SubmitFormResult submit(SubmitFormCommand command) {",
    "    requireMatchingTenant(command.tenantId());",
    "    FormRuntimeViewSnapshot snapshot = loadSnapshot(command);",
    "    return accepted(command.traceId(), snapshot.snapshotId());",
    "  }",
    "}",
  })
  local root = graph.new_node(item("submit", "com.nhyc.web.RuntimeFormViewController", "/repo/src/RuntimeFormViewController.java", 59), 0)
  local service = graph.new_node(item("submit", "com.nhyc.application.RuntimeFormSubmissionService", path, 1), 1)
  root.children = { service }

  local lines, line_map = graph.to_ascii_graph(root, { direction = "outgoing", title = "Business Call Graph" })
  local text = table.concat(lines, "\n")

  assert_match(text, "[├└]─▶%s+%[服务%] RuntimeFormSubmissionService%.submit", "graph uses explicit arrowheads")
  assert_match(text, "做: .*requireMatchingTenant", "graph includes action summary")
  assert_match(text, "用: .*command%.tenantId", "graph includes property summary")

  local mapped = false
  for lnum, line in ipairs(lines) do
    if line:match("RuntimeFormSubmissionService%.submit") and line_map[lnum] == service then
      mapped = true
      break
    end
  end
  assert_eq(mapped, true, "graph node line remains jumpable")
end)

run("renders boxed ASCII diagram with branch arrows and jump map", function()
  local path = temp_java({
    "class EventService {",
    "  public void persist(EventCommand command) {",
    "    validate(command.eventId());",
    "    EventRecord record = mapper.toRecord(command);",
    "    repository.save(record);",
    "  }",
    "}",
  })
  local root = graph.new_node(item("publish", "com.nhyc.web.EventController", "/repo/src/EventController.java", 10), 0)
  local service = graph.new_node(item("persist", "com.nhyc.application.EventService", path, 1), 1)
  local repo = graph.new_node(item("save", "com.nhyc.infrastructure.EventRepository", "/repo/src/EventRepository.java", 40), 1)
  root.children = { service, repo }

  local lines, line_map = graph.to_ascii_diagram(root, { direction = "outgoing", title = "Business ASCII Diagram" })
  local text = table.concat(lines, "\n")

  assert_match(text, "┌", "diagram renders box top borders")
  assert_match(text, "└", "diagram renders box bottom borders")
  assert_match(text, "├──▶%s+┌", "diagram renders branch arrow into first child box")
  assert_match(text, "└──▶%s+┌", "diagram renders branch arrow into last child box")
  assert_match(text, "%[服务%] EventService%.persist", "diagram includes role and compact label")
  assert_match(text, "意图: .*持久化", "diagram includes business intent")
  assert_match(text, "动作: .*validate", "diagram includes method action summary")
  assert_match(text, "输入: .*command%.eventId", "diagram includes method property summary")

  local mapped = false
  for lnum, line in ipairs(lines) do
    if line:match("EventRepository%.save") and line_map[lnum] == repo then
      mapped = true
      break
    end
  end
  assert_eq(mapped, true, "diagram box line remains jumpable")
end)

run("wraps boxed ASCII diagram content instead of truncating details", function()
  local path = temp_java({
    "class RuntimeControllerSupport {",
    "  public TenantId parseCountersignMemberId(String raw) {",
    "    String[] parts = raw.split(\":\");",
    "    TenantId tenantId = TenantId.of(parts[0]);",
    "    if (tenantId.value().isBlank()) {",
    "      throw new WorkItemOperationException(ErrorCode.INVALID_COUNTERSIGN_MEMBER, \"bad\");",
    "    }",
    "    return tenantId;",
    "  }",
    "}",
  })
  local root = graph.new_node(item(
    "parseCountersignMemberId(String raw) : TenantId",
    "com.nhyc.interfaces.rest.RuntimeControllerSupport",
    path,
    1
  ), 0)

  local lines = graph.to_ascii_diagram(root, {
    direction = "outgoing",
    title = "Business ASCII Diagram",
    diagram_box_width = 34,
  })
  local text = table.concat(lines, "\n")

  assert_not_match(text, "…", "diagram should wrap long text instead of truncating it")
  assert_match(text, "parseCountersignMemberId", "long method name is still visible")
  assert_match(text, "WorkItemOperationException", "long action detail is still visible")
end)

run("sizes boxed ASCII diagram by screen reserve instead of a fixed width", function()
  local root = graph.new_node(item(
    "parseCountersignMemberIdWithLongBusinessName(String raw) : TenantId",
    "com.nhyc.interfaces.rest.RuntimeControllerSupport",
    "/repo/src/RuntimeControllerSupport.java",
    1
  ), 0)

  local lines = graph.to_ascii_diagram(root, {
    direction = "outgoing",
    title = "Business ASCII Diagram",
    diagram_screen_columns = 100,
  })

  for _, line in ipairs(lines) do
    if line:match("^┌") then
      assert_eq(vim.fn.strdisplaywidth(line) <= 64, true, "box keeps 20% horizontal reserve on each side")
    end
  end
end)

run("adds business intent and keeps full diagram details", function()
  local path = temp_java({
    "class RuntimeFormSubmissionService {",
    "  public SubmitFormResult submit(SubmitFormCommand command) {",
    "    requireMatchingTenant(command.tenantId());",
    "    loadSnapshot(command);",
    "    applyPolicy(command.policyKey());",
    "    persistSubmission(command.traceId());",
    "    publishEvent(command.eventId());",
    "    return accepted(command.traceId(), command.eventId());",
    "  }",
    "}",
  })
  local root = graph.new_node(item(
    "submit(SubmitFormCommand command) : SubmitFormResult",
    "com.nhyc.application.RuntimeFormSubmissionService",
    path,
    1
  ), 0)

  local lines = graph.to_ascii_diagram(root, {
    direction = "outgoing",
    title = "Business ASCII Diagram",
    diagram_screen_columns = 120,
  })
  local text = table.concat(lines, "\n")

  assert_match(text, "意图:", "diagram explains the node intent")
  assert_match(text, "动作:", "diagram names the operation chain")
  assert_match(text, "输入:", "diagram names consumed inputs")
  assert_match(text, "输出:", "diagram names produced outputs")
  assert_match(text, "publishEvent", "diagram keeps later actions instead of hiding them behind truncation")
  assert_not_match(text, "%.%.%.", "diagram should not hide remaining details behind ASCII ellipsis")
end)

run("caps ASCII graph floating window size", function()
  local lines = { string.rep("x", 300), "short" }
  local size = graph.ascii_window_size(lines, 240, 80)

  assert_eq(size.width <= math.floor(240 * 0.82), true, "width is capped to a readable portion of the editor")
  assert_eq(size.height <= math.floor(80 * 0.62), true, "height is capped to a readable portion of the editor")
end)

run("finds Java method declaration after Spring annotation", function()
  local lines = {
    "  @PostMapping(\"/events\")",
    "  @Transactional",
    "  public ResponseEntity<EventPayload> publish(@RequestBody EventPayload payload) {",
    "    return service.publish(payload);",
    "  }",
  }

  assert_eq(graph.find_next_java_method_line(lines, 1), 3)
end)

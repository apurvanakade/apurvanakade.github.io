--[[
  AI-owned Pandoc filter for the course pages, courses/*.qmd (applied by
  courses/_metadata.yml). See CLAUDE.md §3, "Course pages". HTML only; the
  pages have no PDF.

  The pages are full copies of Canvas sites and run long, so the filter
  reorganises them rather than the text being cut. It recognises these
  shapes, so the .qmd files stay plain Markdown:

    * every `###` and what follows it, up to the next `##` or `###`: a
      closed <details> toggle whose summary is the heading (exam-by-exam
      topics, policies, project rubrics, student projects by term);
    * the bullet list before the first `##` (Syllabus, notes, exams...), and
      any later list whose items are each a single link: pill buttons, in
      one row when no item has a note, else one per line with the text after
      the link as a muted note;
    * a table whose first column is "Project" and which has a "Description"
      column (project ideas): a stack of title, description and course
      connection, which reads better than three cramped columns;
    * a bullet list or idea stack of more than FOLD_OVER items outside a
      `###` toggle: the first FOLD_KEEP are shown, the rest folded;
    * a table whose first column is "Exam" and which has a "Date" column:
      one date tile per exam;
    * a table whose first column is "Week": rows that mention an exam are
      highlighted, and rows with no week number (a break) are greyed out.

  Anything that does not match is left as it is.
--]]

if not quarto.doc.is_format("html") then return {} end

local function text(x) return pandoc.utils.stringify(x) end

local function cls(classes) return pandoc.Attr("", classes) end

local FOLD_OVER, FOLD_KEEP = 8, 6

-------------------------------------------------------------- link list

-- Drop leading spaces and one leading ":" from an inline list.
local function trim_lead(inls)
  local out = pandoc.Inlines(inls)
  while #out > 0 and (out[1].t == "Space" or (out[1].t == "Str" and out[1].text == ":")) do
    out:remove(1)
  end
  if #out > 0 and out[1].t == "Str" and out[1].text:sub(1, 1) == ":" then
    out[1] = pandoc.Str(out[1].text:sub(2))
    if out[1].text == "" then out:remove(1) end
    while #out > 0 and out[1].t == "Space" do out:remove(1) end
  end
  return out
end

local function link_rows(list)
  local rows, noted = {}, false
  for _, item in ipairs(list.content) do
    local first = item[1]
    if #item ~= 1 or (first.t ~= "Plain" and first.t ~= "Para") then return nil end
    local inls = first.content
    local row
    if inls[1] and inls[1].t == "Link" then
      local link = inls[1]
      link.classes:insert("project-link")
      local rest = {}
      for i = 2, #inls do rest[#rest + 1] = inls[i] end
      rest = trim_lead(rest)
      row = { pandoc.Plain({ link }) }
      if #rest > 0 then
        noted = true
        row[#row + 1] = pandoc.Div(pandoc.Plain(rest), cls({ "course-links__desc" }))
      end
    else
      noted = true
      row = { pandoc.Div(pandoc.Plain(inls), cls({ "course-links__desc" })) }
    end
    rows[#rows + 1] = pandoc.Div(row, cls({ "course-links__item" }))
  end
  return pandoc.Div(rows, cls({ "course-links", noted and "course-links--noted" or "course-links--row" }))
end

-- True when every item is one link and nothing else.
local function links_only(list)
  for _, item in ipairs(list.content) do
    local first = item[1]
    if #item ~= 1 or (first.t ~= "Plain" and first.t ~= "Para") then return false end
    local inls = first.content
    if #inls ~= 1 or inls[1].t ~= "Link" then return false end
  end
  return true
end

-------------------------------------------------------------- long lists

local function more(n)
  return pandoc.RawBlock("html", '<details class="course-more"><summary>Show '
    .. n .. ' more</summary>')
end

local function fold(list)
  local n = #list.content
  if n <= FOLD_OVER then return nil end
  local shown, hidden = {}, {}
  for i, item in ipairs(list.content) do
    if i <= FOLD_KEEP then shown[#shown + 1] = item else hidden[#hidden + 1] = item end
  end
  return {
    pandoc.BulletList(shown), more(n - FOLD_KEEP),
    pandoc.BulletList(hidden), pandoc.RawBlock("html", "</details>"),
  }
end

-------------------------------------------------------------- exam tiles

local function header_names(tbl)
  local names = {}
  local hrow = tbl.head.rows[1]
  if not hrow then return names end
  for i, cell in ipairs(hrow.cells) do names[i] = text(cell.contents) end
  return names
end

local function body_rows(tbl)
  local rows = {}
  for _, body in ipairs(tbl.bodies) do
    for _, row in ipairs(body.body) do rows[#rows + 1] = row end
  end
  return rows
end

local function exam_tiles(tbl)
  local names = header_names(tbl)
  if names[1] ~= "Exam" then return nil end
  local date_col, time_col
  for i, n in ipairs(names) do
    if n == "Date" then date_col = i elseif n == "Time" then time_col = i end
  end
  if not date_col then return nil end

  local tiles = {}
  for _, row in ipairs(body_rows(tbl)) do
    local name = text(row.cells[1].contents)
    local date = text(row.cells[date_col].contents)
    local time = time_col and text(row.cells[time_col].contents) or ""
    -- "Monday, October 5" -> weekday, month, day; anything else is shown whole.
    local weekday, month, day = date:match("^(%a+),%s*(%a+)%s+(%d+)$")
    local html = '<div class="course-exam">'
      .. '<div class="course-exam__name">' .. name .. '</div>'
    if weekday then
      html = html .. '<div class="course-exam__date"><span class="course-exam__month">'
        .. month:sub(1, 3) .. '</span> <span class="course-exam__day">' .. day
        .. '</span></div><div class="course-exam__meta">' .. weekday
    else
      html = html .. '<div class="course-exam__meta">' .. date
    end
    if time ~= "" then html = html .. ' &middot; ' .. time end
    tiles[#tiles + 1] = html .. '</div></div>'
  end
  return pandoc.RawBlock("html", '<div class="course-exams">' .. table.concat(tiles) .. '</div>')
end

-------------------------------------------------------- weekly schedule

local function row_class(row)
  local week = text(row.cells[1].contents)
  local parts = {}
  for _, cell in ipairs(row.cells) do parts[#parts + 1] = text(cell.contents) end
  local all = table.concat(parts, " ")
  if week == "" then return "course-row--break" end
  if all:find("Exam") or all:find("Midterm") or all:find("Final exam") then
    return "course-row--exam"
  end
end

-- The row is marked by an empty span in its first cell, styled with
-- tr:has(...). A class on the <tr> itself is lost: Quarto rebuilds some
-- tables (the Graph Theory schedule, with math and links in its cells) after
-- this filter runs, and drops row attributes when it does. Bodies and rows
-- are copied out, changed and assigned back, because a change made through
-- tbl.bodies[i].body[j] directly does not reach the table.
local function mark_schedule(tbl)
  if header_names(tbl)[1] ~= "Week" then return nil end
  local bodies = tbl.bodies
  for b = 1, #bodies do
    local body = bodies[b]
    local rows = body.body
    for r = 1, #rows do
      local c = row_class(rows[r])
      if c then
        local cells = rows[r].cells
        local cell = cells[1]
        local blocks = cell.contents
        blocks:insert(1, pandoc.Plain({ pandoc.Span({}, cls({ c })) }))
        cell.contents = blocks
        cells[1] = cell
        rows[r].cells = cells
      end
    end
    body.body = rows
    bodies[b] = body
  end
  tbl.bodies = bodies
  return tbl
end

----------------------------------------------------------- project ideas

-- Returns the idea Divs, or nil when the table is not an idea table. Every
-- column after the title and description becomes a muted line labelled with
-- its header, so no cell and no header is lost.
local function idea_items(tbl)
  local names = header_names(tbl)
  if names[1] ~= "Project" then return nil end
  local desc_col
  for i, n in ipairs(names) do if n == "Description" then desc_col = i end end
  if not desc_col then return nil end
  local items = {}
  for _, row in ipairs(body_rows(tbl)) do
    local parts = {
      pandoc.Div(row.cells[1].contents, cls({ "course-idea__title" })),
      pandoc.Div(row.cells[desc_col].contents, cls({ "course-idea__desc" })),
    }
    for i = 2, #names do
      if i ~= desc_col then
        local inls = pandoc.Inlines({ pandoc.Str(names[i] .. ":"), pandoc.Space() })
        for _, b in ipairs(row.cells[i].contents) do
          if b.content then inls:extend(b.content) end
        end
        parts[#parts + 1] = pandoc.Div(pandoc.Plain(inls), cls({ "course-idea__conn" }))
      end
    end
    items[#items + 1] = pandoc.Div(parts, cls({ "course-idea" }))
  end
  return items
end

local function idea_blocks(items, folding)
  if not folding or #items <= FOLD_OVER then
    return { pandoc.Div(items, cls({ "course-ideas" })) }
  end
  local shown, hidden = {}, {}
  for i, it in ipairs(items) do
    if i <= FOLD_KEEP then shown[#shown + 1] = it else hidden[#hidden + 1] = it end
  end
  return {
    pandoc.Div(shown, cls({ "course-ideas" })), more(#items - FOLD_KEEP),
    pandoc.Div(hidden, cls({ "course-ideas" })), pandoc.RawBlock("html", "</details>"),
  }
end

------------------------------------------------------------- h3 toggles

local function html_inlines(inls)
  return pandoc.write(pandoc.Pandoc({ pandoc.Plain(inls) }), "html"):gsub("\n$", "")
end

local function open_toggle(h)
  local id = h.identifier ~= "" and (' id="' .. h.identifier .. '"') or ""
  return pandoc.RawBlock("html", '<details class="course-fold"' .. id
    .. '><summary>' .. html_inlines(h.content) .. '</summary>')
end

----------------------------------------------------------------- entry

function Pandoc(doc)
  local out, seen_h2, linked, in_fold = {}, false, false, false
  local function close()
    if in_fold then out[#out + 1] = pandoc.RawBlock("html", "</details>") end
    in_fold = false
  end
  for _, blk in ipairs(doc.blocks) do
    local items = blk.t == "Table" and idea_items(blk)
    if blk.t == "Header" and blk.level <= 3 then
      close()
      if blk.level == 2 then seen_h2 = true end
      if blk.level == 3 then
        out[#out + 1] = open_toggle(blk)
        in_fold = true
      else
        out[#out + 1] = blk
      end
    elseif items then
      for _, b in ipairs(idea_blocks(items, not in_fold)) do out[#out + 1] = b end
    elseif blk.t == "BulletList" and not seen_h2 and not linked then
      local rows = link_rows(blk)
      linked = rows ~= nil
      out[#out + 1] = rows or blk
    elseif blk.t == "BulletList" and links_only(blk) then
      out[#out + 1] = link_rows(blk)
    else
      local folded = blk.t == "BulletList" and not in_fold and fold(blk)
      if folded then
        for _, b in ipairs(folded) do out[#out + 1] = b end
      else
        out[#out + 1] = blk
      end
    end
  end
  close()
  doc.blocks = pandoc.Blocks(out)
  -- Tables are walked, not just read off the top level, because Quarto may
  -- already have wrapped one in a Div.
  return doc:walk({
    Table = function(tbl) return exam_tiles(tbl) or mark_schedule(tbl) end,
  })
end

return { { Pandoc = Pandoc } }

--[[
  AI-owned Pandoc filter for the course pages, courses/**/*.qmd (applied by
  courses/_metadata.yml). See CLAUDE.md §3, "Course pages". HTML only; the
  pages have no PDF.

  It recognises three shapes, so the .qmd files stay plain Markdown:

    * the bullet list before the first `##` (Syllabus, notes, exams...): each
      item that opens with a link becomes a pill button, and the rest of the
      item its muted description;
    * a table whose first column is "Exam" and which has a "Date" column:
      one date tile per exam;
    * a table whose first column is "Week": rows that mention an exam are
      highlighted, and rows with no week number (a break) are greyed out.

  Anything that does not match is left as it is.
--]]

if not quarto.doc.is_format("html") then return {} end

local function text(x) return pandoc.utils.stringify(x) end

local function cls(classes) return pandoc.Attr("", classes) end

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
  local rows = {}
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
        row[#row + 1] = pandoc.Div(pandoc.Plain(rest), cls({ "course-links__desc" }))
      end
    else
      row = { pandoc.Div(pandoc.Plain(inls), cls({ "course-links__desc" })) }
    end
    rows[#rows + 1] = pandoc.Div(row, cls({ "course-links__item" }))
  end
  return pandoc.Div(rows, cls({ "course-links" }))
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

----------------------------------------------------------------- entry

function Pandoc(doc)
  local out, seen_h2, linked = {}, false, false
  for _, blk in ipairs(doc.blocks) do
    if blk.t == "Header" and blk.level == 2 then seen_h2 = true end
    if blk.t == "BulletList" and not seen_h2 and not linked then
      local rows = link_rows(blk)
      linked = rows ~= nil
      out[#out + 1] = rows or blk
    else
      out[#out + 1] = blk
    end
  end
  doc.blocks = pandoc.Blocks(out)
  -- Tables are walked, not just read off the top level, because Quarto may
  -- already have wrapped one in a Div.
  return doc:walk({
    Table = function(tbl) return exam_tiles(tbl) or mark_schedule(tbl) end,
  })
end

return { { Pandoc = Pandoc } }

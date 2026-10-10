--[[
  AI-owned Pandoc filter: reproduces the two-column LaTeX CV layout.  See CLAUDE.md.

  It rewrites the body of CV.qmd so that:

    * each `## Section` becomes a two-column row -- the section name sits in a
      narrow label column on the left, its entries in a wide column on the right;
    * any entry paragraph ending in ", <year>" has that year lifted out and
      right-aligned in its own column.

  Recognised year tails (always preceded by a comma):
      2025            2019-2021        2019-21        2023-Present
      2023-           Fall 2024        Spring 2024    Winter, Spring 2022

  Nothing in cv/*.qmd needs to change: keep writing plain
  "Faculty Forward Fellowship, JHU, 2025" and the layout happens here.

  Set `cv-layout: false` in a document's metadata to switch the filter off.
--]]

local enabled = true

-- HTML-only extras (the PDF keeps the plain LaTeX CV layout):
--   * TIMELINE_SECTIONS are drawn as a timeline, one dot per entry, coloured by
--     the institution named in the entry (INSTITUTIONS; the colours are the
--     site-wide --inst-* tokens in _theme/base.scss);
--   * TEACHING_SECTION's course lists become one row per term with a chip per
--     course, plus a link to the teaching portfolio;
--   * FOLDED_SECTIONS show their first FOLD_AFTER entries and fold the rest
--     into a <details> toggle.
local TIMELINE_SECTIONS = { ["Experience"] = true, ["Education"] = true }
local TEACHING_SECTION = "Teaching"
local PORTFOLIO_HREF = "teaching-portfolio.html"
local FOLDED_SECTIONS = { ["Conferences Attended"] = true }
local FOLD_AFTER = 5
-- Sections whose entry lines are set in bold, in the PDF too: each entry there
-- is a title with a line of detail beneath it.
local BOLD_SECTIONS = { ["Course Design & Materials"] = true }
local INSTITUTIONS = {
  { key = "jhu", patterns = { "Johns Hopkins", "JHU" } },
  { key = "nw",  patterns = { "Northwestern" } },
  { key = "uwo", patterns = { "Western Ontario", "UWO" } },
}

--------------------------------------------------------------------- helpers

local SEASONS = { Spring = true, Summer = true, Fall = true, Autumn = true, Winter = true }

-- Does `s` look like a year tail? Returns true/false.
local function is_year_tail(s)
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  if s == "" then return false end
  -- strip leading season words: "Fall 2024", "Winter, Spring 2022"
  local stripped = s
  local guard = 0
  while guard < 4 do
    local word, rest = stripped:match("^(%a+)%s*,?%s*(.*)$")
    if word and SEASONS[word] and rest ~= "" then
      stripped, guard = rest, guard + 1
    else
      break
    end
  end
  -- 2025 | 2019-2021 | 2019-21 | 2023-Present | 2023-
  if stripped:match("^%d%d%d%d$") then return true end
  if stripped:match("^%d%d%d%d%s*[-\u{2013}]%s*%d%d%d%d$") then return true end
  if stripped:match("^%d%d%d%d%s*[-\u{2013}]%s*%d%d$") then return true end
  if stripped:match("^%d%d%d%d%s*[-\u{2013}]%s*[Pp]resent$") then return true end
  if stripped:match("^%d%d%d%d%s*[-\u{2013}]$") then return true end
  return false
end

-- Render a list of inlines to plain text (for tail sniffing only).
local function inlines_to_text(inls)
  return pandoc.utils.stringify(pandoc.Inlines(inls))
end

-- Split a paragraph's inlines at the final top-level comma whose tail is a
-- year. Returns text_inlines, year_inlines -- or nil when there is no year.
local function split_year(inlines)
  -- Walk backwards to the last Str containing a comma, trying each candidate.
  for i = #inlines, 1, -1 do
    local el = inlines[i]
    if el.t == "Str" then
      -- a comma may sit inside this Str ("JHU,") or the Str may be the tail
      local before, after = el.text:match("^(.*),%s*(.-)$")
      if before then
        local tail = {}
        if after ~= "" then tail[#tail + 1] = pandoc.Str(after) end
        for j = i + 1, #inlines do tail[#tail + 1] = inlines[j] end
        if is_year_tail(inlines_to_text(tail)) then
          local head = {}
          for j = 1, i - 1 do head[#head + 1] = inlines[j] end
          if before ~= "" then head[#head + 1] = pandoc.Str(before) end
          -- trim trailing space from head
          while #head > 0 and head[#head].t == "Space" do table.remove(head) end
          -- trim leading space from tail
          while #tail > 0 and tail[1].t == "Space" do table.remove(tail, 1) end
          if #head > 0 and #tail > 0 then
            return pandoc.Inlines(head), pandoc.Inlines(tail)
          end
        end
      end
    end
  end
  return nil
end

--------------------------------------------------------------- entry emitters

local function html_entry(text_inlines, year_inlines)
  if year_inlines then
    return pandoc.Div({
      pandoc.Div(pandoc.Plain(text_inlines), pandoc.Attr("", { "cv-entry-text" })),
      pandoc.Div(pandoc.Plain(year_inlines), pandoc.Attr("", { "cv-entry-year" })),
    }, pandoc.Attr("", { "cv-entry" }))
  end
  return pandoc.Div(pandoc.Plain(text_inlines), pandoc.Attr("", { "cv-entry" }))
end

local function tex(s) return pandoc.RawBlock("latex", s) end

local function latex_entry(text_inlines, year_inlines)
  local body = pandoc.write(pandoc.Pandoc({ pandoc.Plain(text_inlines) }), "latex")
  local year = year_inlines
    and pandoc.write(pandoc.Pandoc({ pandoc.Plain(year_inlines) }), "latex")
    or ""
  return tex("\\cventry{" .. body .. "}{" .. year .. "}")
end

--------------------------------------------------------------- block rewrites

-- Rewrite the blocks that make up one section's body.
local function build_body(blocks, fmt, bold)
  local out = {}
  for _, blk in ipairs(blocks) do
    if blk.t == "Para" or blk.t == "Plain" then
      local text, year = split_year(blk.content)
      if bold then text = pandoc.Inlines({ pandoc.Strong(text or blk.content) }) end
      if fmt == "latex" then
        out[#out + 1] = latex_entry(text or blk.content, year)
      else
        out[#out + 1] = html_entry(text or blk.content, year)
      end
    elseif blk.t == "Header" and fmt == "latex" then
      -- \subsection inside the cvsection list environment is illegal in LaTeX,
      -- so render sub-headings as plain formatted paragraphs instead.
      local txt = pandoc.write(pandoc.Pandoc({ pandoc.Plain(blk.content) }), "latex")
      local cmd = (blk.level >= 4) and "cvsubsubsection" or "cvsubsection"
      out[#out + 1] = tex("\\" .. cmd .. "{" .. txt .. "}")
    else
      out[#out + 1] = blk
    end
  end
  return out
end

------------------------------------------------------------ html extras

-- The one institution an entry names, or "other" for none or several.
local function institution_of(text)
  local found = nil
  for _, inst in ipairs(INSTITUTIONS) do
    for _, pat in ipairs(inst.patterns) do
      if text:find(pat, 1, true) then
        if found and found ~= inst.key then return "other" end
        found = inst.key
        break
      end
    end
  end
  return found or "other"
end

local function add_timeline_classes(blocks)
  for _, blk in ipairs(blocks) do
    if blk.t == "Div" and blk.classes:includes("cv-entry") then
      local key = institution_of(pandoc.utils.stringify(blk))
      blk.classes:insert("cv-entry--" .. key)
    end
  end
  return blocks
end

-- Split "Course name, Spring 2022" into name and term. The term starts at the
-- first ", " followed by a season, a year or "Intersession"; a parenthetical
-- that opens the term ("(Coordinator) 2022-23") moves to the name.
local TERM_START = { "Spring", "Summer", "Fall", "Autumn", "Winter", "Intersession", "(" }
local function split_term(text)
  local pos = 1
  while true do
    local i = text:find(", ", pos, true)
    if not i then return nil end
    local rest = text:sub(i + 2)
    local ok = rest:match("^%d%d%d%d") ~= nil
    for _, w in ipairs(TERM_START) do
      if rest:sub(1, #w) == w then ok = true end
    end
    if ok then
      local name = text:sub(1, i - 1)
      local paren, after = rest:match("^(%b())%s*(.*)$")
      if paren then name, rest = name .. " " .. paren, after end
      if rest == "" then return nil end
      return name, rest
    end
    pos = i + 2
  end
end

local function term_row(term, names)
  local chips, seen = {}, {}
  for _, n in ipairs(names) do
    if not seen[n] then
      seen[n] = true
      chips[#chips + 1] = pandoc.Span(pandoc.Str(n), pandoc.Attr("", { "cv-course" }))
      chips[#chips + 1] = pandoc.Space()
    end
  end
  return pandoc.Div({
    pandoc.Div(pandoc.Plain(pandoc.Str(term)), pandoc.Attr("", { "cv-term__label" })),
    pandoc.Div(pandoc.Plain(chips), pandoc.Attr("", { "cv-term__courses" })),
  }, pandoc.Attr("", { "cv-term" }))
end

-- Parse a bullet list whose every item is "Course, Term". Returns a list of
-- {name, term} or nil.
local function parse_course_list(list)
  local items = {}
  for _, item in ipairs(list.content) do
    local name, term = split_term(pandoc.utils.stringify(item))
    if not name then return nil end
    items[#items + 1] = { name = name, term = term }
  end
  return items
end

-- Teaching: each "#### Term" + list, and each list of "Course, Term" items,
-- becomes rows of course chips, one row per term in the order first seen.
local function compact_teaching(blocks)
  local out = {
    pandoc.Div(pandoc.Plain({
      pandoc.Link("Course details, ratings and student comments in the teaching portfolio",
        PORTFOLIO_HREF, "", pandoc.Attr("", { "project-link" })),
    }), pandoc.Attr("", { "cv-portfolio-link" })),
  }
  local i = 1
  while i <= #blocks do
    local blk, nxt = blocks[i], blocks[i + 1]
    if blk.t == "Header" and blk.level == 4 and nxt and nxt.t == "BulletList"
        and parse_course_list(nxt) then
      local names = {}
      for _, it in ipairs(parse_course_list(nxt)) do names[#names + 1] = it.name end
      out[#out + 1] = term_row(pandoc.utils.stringify(blk), names)
      i = i + 2
    elseif blk.t == "BulletList" and parse_course_list(blk) then
      local order, by_term = {}, {}
      for _, it in ipairs(parse_course_list(blk)) do
        if not by_term[it.term] then
          by_term[it.term] = {}
          order[#order + 1] = it.term
        end
        table.insert(by_term[it.term], it.name)
      end
      for _, term in ipairs(order) do out[#out + 1] = term_row(term, by_term[term]) end
      i = i + 1
    else
      out[#out + 1] = blk
      i = i + 1
    end
  end
  return out
end

-- Keep the first FOLD_AFTER entries; fold the rest into <details>.
local function fold_entries(blocks)
  local entries = 0
  for _, b in ipairs(blocks) do
    if b.t == "Div" and b.classes:includes("cv-entry") then entries = entries + 1 end
  end
  if entries <= FOLD_AFTER then return blocks end
  local out, seen, opened = {}, 0, false
  for _, b in ipairs(blocks) do
    if b.t == "Div" and b.classes:includes("cv-entry") then seen = seen + 1 end
    if seen > FOLD_AFTER and not opened then
      out[#out + 1] = pandoc.RawBlock("html", '<details class="cv-more"><summary>Show '
        .. (entries - FOLD_AFTER) .. ' more</summary>')
      opened = true
    end
    out[#out + 1] = b
  end
  out[#out + 1] = pandoc.RawBlock("html", "</details>")
  return out
end

local function build_section(label_inlines, body_blocks, fmt)
  if fmt == "latex" then
    local label = pandoc.write(pandoc.Pandoc({ pandoc.Plain(label_inlines) }), "latex")
    local out = { tex("\\begin{cvsection}{" .. label .. "}") }
    local name = pandoc.utils.stringify(pandoc.Inlines(label_inlines))
    for _, b in ipairs(build_body(body_blocks, fmt, BOLD_SECTIONS[name])) do out[#out + 1] = b end
    out[#out + 1] = tex("\\end{cvsection}")
    return out
  end
  -- A real top-level <h2> carries the id, the anchor and the TOC entry; it is
  -- visually hidden.  The visible label is a plain div in the left column and
  -- is hidden from assistive tech so the text is not announced twice.
  local slug = pandoc.utils.stringify(pandoc.Inlines(label_inlines))
    :lower():gsub("[^%w%s-]", ""):gsub("%s+", "-")
  local heading = pandoc.Header(2, label_inlines, pandoc.Attr(slug, { "cv-anchor" }))
  local label = pandoc.Div(pandoc.Plain(label_inlines),
    pandoc.Attr("", { "cv-label" }, { ["aria-hidden"] = "true" }))
  local name = pandoc.utils.stringify(pandoc.Inlines(label_inlines))
  local classes = { "cv-section" }
  if name == TEACHING_SECTION then body_blocks = compact_teaching(body_blocks) end
  local body_content = build_body(body_blocks, fmt, BOLD_SECTIONS[name])
  if TIMELINE_SECTIONS[name] then
    body_content = add_timeline_classes(body_content)
    classes[#classes + 1] = "cv-section--timeline"
  end
  if FOLDED_SECTIONS[name] then body_content = fold_entries(body_content) end
  local body = pandoc.Div(body_content, pandoc.Attr("", { "cv-body" }))
  return { heading, pandoc.Div({ label, body }, pandoc.Attr("", classes)) }
end

----------------------------------------------------------------- cv header

-- Build the name / affiliation / contact block from CV.qmd metadata:
--   cv-subtitle: "Assistant Teaching Professor, ..."
--   cv-contact:  ["apurva.nakade@jhu.edu", "apurvanakade.github.io"]
local function build_header(meta, fmt)
  local subtitle = meta["cv-subtitle"]
  local contact = meta["cv-contact"]
  if not subtitle and not contact then return {} end

  local function render(inls)
    if fmt == "latex" then
      return pandoc.write(pandoc.Pandoc({ pandoc.Plain(inls) }), "latex")
    end
    return inls
  end

  if fmt == "latex" then
    local parts = {}
    if subtitle then parts[#parts + 1] = render(subtitle) end
    if contact then
      local bits = {}
      for _, c in ipairs(contact) do bits[#bits + 1] = render(c) end
      parts[#parts + 1] = table.concat(bits, " \\quad\\textperiodcentered\\quad ")
    end
    return { tex("\\cvcontact{" .. table.concat(parts, "\\\\[2pt]") .. "}\\cvrule") }
  end

  local rows = {}
  if subtitle then
    rows[#rows + 1] = pandoc.Div(pandoc.Plain(subtitle), pandoc.Attr("", { "cv-affiliation" }))
  end
  if contact then
    local items = {}
    for _, c in ipairs(contact) do
      items[#items + 1] = pandoc.Span(c)
    end
    rows[#rows + 1] = pandoc.Div(pandoc.Plain(pandoc.Inlines(items)), pandoc.Attr("", { "cv-contact" }))
  end
  rows[#rows + 1] = pandoc.RawBlock("html", '<hr class="cv-rule">')
  return { pandoc.Div(rows, pandoc.Attr("", { "cv-header" })) }
end

--------------------------------------------------------------------- entry pt

local doc_meta = nil

function Meta(meta)
  if meta["cv-layout"] ~= nil and meta["cv-layout"] == false then enabled = false end
  doc_meta = meta
  return meta
end

function Pandoc(doc)
  if not enabled then return doc end

  local fmt = FORMAT:match("latex") and "latex" or "html"
  local out, preamble = {}, {}
  local label, body, in_section = nil, {}, false

  local function flush()
    if in_section then
      for _, b in ipairs(build_section(label, body, fmt)) do out[#out + 1] = b end
    end
    label, body, in_section = nil, {}, false
  end

  for _, blk in ipairs(doc.blocks) do
    if blk.t == "Header" and blk.level == 2 then
      flush()
      label, in_section = blk.content, true
    elseif in_section then
      body[#body + 1] = blk
    else
      preamble[#preamble + 1] = blk
    end
  end
  flush()

  local blocks = {}
  for _, b in ipairs(build_header(doc_meta or doc.meta, fmt)) do blocks[#blocks + 1] = b end
  for _, b in ipairs(preamble) do blocks[#blocks + 1] = b end
  for _, b in ipairs(out) do blocks[#blocks + 1] = b end
  if fmt == "latex" then
    blocks[#blocks + 1] = tex("\\vfill\\hfill{\\footnotesize Updated on: "
      .. os.date("%B %d, %Y") .. ".}")
  end

  doc.blocks = pandoc.Blocks(blocks)
  return doc
end

return { { Meta = Meta }, { Pandoc = Pandoc } }

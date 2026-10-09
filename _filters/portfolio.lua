--[[
  AI-owned Pandoc filter for teaching-portfolio.qmd.  See CLAUDE.md §4.

  The portfolio stays prose, pipe tables and bullet lists; everything visual
  is built here from that structure, for HTML and LaTeX alike:

  - a summary band (courses, students, universities, teaching since, recent
    JHU rating) above the first `##`, computed from the course tables;
  - a chart of every semester's instructor rating at the top of `## Courses`;
  - each course `###` "Name (Institution, code)" gets an institution badge
    and a muted course code;
  - rating cells "4.37 / 5" get a thin bar (HTML);
  - a course with a page under projects/ gets a link card (HTML);
  - the list under `#### Sample materials` becomes pill links (HTML);
  - the list under `#### Selected student comments` becomes quote cards;
  - the first bullet list in `## Teaching philosophy` whose items all start
    with **bold label** becomes a row of icon tiles (HTML).

  HTML styles live in _theme/portfolio.css, attached to this page only;
  LaTeX environments and colours live in _includes/portfolio-preamble.tex.
--]]

local is_html = quarto.doc.is_format("html")
local is_latex = quarto.doc.is_format("latex")
local stringify = pandoc.utils.stringify

-- Institution as written in a course heading -> key, badge text, chart label.
-- The key names the CSS custom properties and LaTeX colours.
local INSTITUTIONS = {
  ["JHU"]             = { key = "jhu", badge = "JHU",             short = "JHU" },
  ["Northwestern"]    = { key = "nw",  badge = "Northwestern",    short = "Northwestern" },
  ["Western Ontario"] = { key = "uwo", badge = "Western Ontario", short = "Western" },
}
local OTHER = { key = "other", badge = nil, short = "Other" }

-- Start of the current JHU appointment; the summary band's rating covers
-- JHU semesters from this year on.
local CURRENT_ROLE_START = 2023

-- Course name (normalised) -> projects/<slug>.qmd describing it.
local COURSE_PROJECTS = {
  ["monte carlo methods"] = "monte-carlo-methods",
  ["discrete structures for engineering"] = "discrete-math-online",
  ["algebraic topology"] = "algebraic-topology",
  ["introduction to optimization"] = "intro-to-optimization",
  ["honors single variable calculus"] = "honors-single-variable-calculus",
  ["symmetries and polynomials"] = "symmetries-and-polynomials",
  ["hitchhiker s guide to algebraic topology"] = "hitchhikers-guide-algebraic-topology",
}

-- Bootstrap Icons for the philosophy tiles, chosen by a word in the label.
local TILE_ICONS = {
  { "resubmi", "bi-arrow-repeat" },
  { "assess",  "bi-ui-checks" },
  { "online",  "bi-code-slash" },
  { "project", "bi-easel" },
  { " ai ",    "bi-stars" },
}

-- Fraction of the calendar year at which each kind of term sits on the chart.
local TERM_OFFSET = {
  Intersession = 0.03, Winter = 0.12, Spring = 0.38, Summer = 0.6, Fall = 0.85,
}

-------------------------------------------------------------------- helpers

local function normalise(s)
  return (s:lower():gsub("[^%w]+", " "):gsub("^ +", ""):gsub(" +$", ""))
end

local function words(s)
  local out = pandoc.Inlines({})
  for w in s:gmatch("%S+") do
    if #out > 0 then out:insert(pandoc.Space()) end
    out:insert(pandoc.Str(w))
  end
  return out
end

local function html_escape(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

local function latex_escape(s)
  return (s:gsub("\\", "\\textbackslash{}"):gsub("([&%%$#_{}])", "\\%1")
           :gsub("~", "\\textasciitilde{}"):gsub("%^", "\\textasciicircum{}"))
end

local function fmt(x, digits)
  return string.format("%." .. (digits or 2) .. "f", x)
end

local function thousands(n)
  local s = tostring(math.floor(n))
  local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (out:gsub("^,", ""))
end

local function term_time(term)
  local season, year = term:match("^(%a+)%s+(%d%d%d%d)")
  if not season then return nil end
  return tonumber(year) + (TERM_OFFSET[season] or 0.5), tonumber(year)
end

local function parse_rating(s)
  local v, m = s:match("^%s*([%d%.]+)%s*/%s*(%d+)%s*$")
  if not v then return nil end
  return tonumber(v), tonumber(m)
end

local function read_project(slug)
  local root = (quarto.project and quarto.project.directory) or "."
  local f = io.open(root .. "/projects/" .. slug .. ".qmd", "r")
  if not f then return nil end
  local text = f:read("a")
  f:close()
  local fm = text:match("^%-%-%-\n(.-)\n%-%-%-") or ""
  local function field(name)
    local v = fm:match("\n" .. name .. ":%s*([^\n]+)") or fm:match("^" .. name .. ":%s*([^\n]+)")
    if not v then return nil end
    return (v:gsub('^%s*"', ""):gsub('"%s*$', ""):gsub("%s+$", ""))
  end
  local image = field("image")
  if image then image = image:gsub("^%.%./", "") end
  return { slug = slug, title = field("title"), description = field("description"), image = image }
end

------------------------------------------------------------ course headings

local function parse_course_heading(h)
  local text = stringify(h.content)
  local name, paren = text:match("^(.-)%s*%(([^()]*)%)%s*$")
  if not name then return { name = text, inst = OTHER } end
  local inst_text, code = paren:match("^([^,]+),%s*(.+)$")
  inst_text = inst_text or paren
  return { name = name, inst = INSTITUTIONS[inst_text] or OTHER, code = code }
end

local function decorate_heading(h, c)
  local content = words(c.name)
  if c.inst.badge then
    content:insert(pandoc.Space())
    if is_latex then
      content:insert(pandoc.RawInline("latex", "\\texorpdfstring{\\instbadge{" ..
        c.inst.key .. "}{" .. latex_escape(c.inst.badge) .. "}}{}"))
    else
      content:insert(pandoc.Span(pandoc.Str(c.inst.badge), pandoc.Attr("", { "inst-badge" })))
    end
  end
  if c.code then
    content:insert(pandoc.Space())
    if is_latex then
      content:insert(pandoc.RawInline("latex", "\\texorpdfstring{\\coursecode{" ..
        latex_escape(c.code) .. "}}{}"))
    else
      content:insert(pandoc.Span(words(c.code), pandoc.Attr("", { "course-code" })))
    end
  end
  h.content = content
  -- Pandoc's section-divs copies these onto the wrapping <section>; the
  -- inst-* rules in portfolio.css set custom properties only, so that is safe
  -- and lets the section's table and quotes inherit the institution colour.
  h.classes:insert("course")
  h.classes:insert("inst-" .. c.inst.key)
  return h
end

---------------------------------------------------------------- course tables

local function column_index(tbl)
  local idx = {}
  local head = tbl.head.rows[1]
  if not head then return idx end
  for i, cell in ipairs(head.cells) do
    local t = stringify(cell.contents)
    if t:match("^Semester") then idx.term = i
    elseif t:match("^Students") then idx.students = i
    elseif t:match("^Course rating") then idx.course = i
    elseif t:match("^Instructor rating") then idx.instructor = i
    end
  end
  return idx
end

local function rating_cell(cell)
  local v, m = parse_rating(stringify(cell.contents))
  if not v then return end
  local pct = 100 * v / m
  cell.contents = pandoc.Blocks({ pandoc.Plain({
    pandoc.Span(pandoc.Str(stringify(cell.contents)),
      pandoc.Attr("", { "rating" }, { style = "--pct: " .. fmt(pct, 1) .. "%" }))
  }) })
end

local function read_table(tbl, course)
  local idx = column_index(tbl)
  for _, body in ipairs(tbl.bodies) do
    for _, row in ipairs(body.body) do
      local cells = row.cells
      local term = idx.term and stringify(cells[idx.term].contents) or ""
      local t, year = term_time(term)
      local students = idx.students and tonumber(stringify(cells[idx.students].contents)) or nil
      local iv, im
      if idx.instructor then iv, im = parse_rating(stringify(cells[idx.instructor].contents)) end
      course.rows[#course.rows + 1] = {
        term = term, t = t, year = year, students = students,
        rating = iv, scale = im,
      }
      if is_html then
        if idx.course then rating_cell(cells[idx.course]) end
        if idx.instructor then rating_cell(cells[idx.instructor]) end
      end
    end
  end
  if is_html then
    -- A wrapper, not a class on the table: Quarto drops classes from a table
    -- whose header holds a footnote. The wrapper also scrolls on phones.
    return pandoc.Div({ tbl }, pandoc.Attr("", { "course-table" }))
  end
  return tbl
end

local function project_card(course)
  local slug = COURSE_PROJECTS[normalise(course.name)]
  if not slug then return nil end
  local p = read_project(slug)
  if not p or not p.title then return nil end
  local img = p.image and ('<img src="' .. html_escape(p.image) .. '" alt="" loading="lazy">') or ""
  return pandoc.RawBlock("html",
    '<a class="course-project" href="projects/' .. slug .. '.html">' .. img ..
    '<span class="course-project__body">' ..
    '<span class="course-project__eyebrow">Project page</span>' ..
    '<span class="course-project__title">' .. html_escape(p.title) .. '</span>' ..
    (p.description and ('<span class="course-project__desc">' .. html_escape(p.description) .. '</span>') or "") ..
    '</span></a>')
end

----------------------------------------------------------------- list blocks

-- "quote text" (Term)  ->  quote inlines (without the marks), "Term"
local function split_quote(item)
  if #item ~= 1 or (item[1].t ~= "Plain" and item[1].t ~= "Para") then return nil end
  local inl = item[1].content
  local qi
  for i = #inl, 1, -1 do
    if inl[i].t == "Quoted" then qi = i; break end
  end
  if not qi then return nil end
  local tail = pandoc.Inlines({})
  for i = qi + 1, #inl do tail:insert(inl[i]) end
  local term = stringify(tail):match("^%s*%((.-)%)%s*$")
  if not term then return nil end
  local before = pandoc.Inlines({})
  for i = 1, qi - 1 do before:insert(inl[i]) end
  return before, inl[qi], term
end

local function quotes_block(list, inst_key)
  if is_latex then
    local out = pandoc.Blocks({})
    for _, item in ipairs(list.content) do
      local before, quoted, term = split_quote(item)
      out:insert(pandoc.RawBlock("latex", "\\begin{portfolioquote}{" .. inst_key .. "}"))
      if quoted then
        local para = pandoc.Inlines(before)
        para:insert(quoted)
        para:insert(pandoc.RawInline("latex", "\\portfolioterm{" .. latex_escape(term) .. "}"))
        out:insert(pandoc.Para(para))
      else
        out:extend(item)
      end
      out:insert(pandoc.RawBlock("latex", "\\end{portfolioquote}"))
    end
    return out
  end
  local cards = pandoc.Blocks({})
  for _, item in ipairs(list.content) do
    local before, quoted, term = split_quote(item)
    if quoted then
      local para = pandoc.Inlines(before)
      para:extend(quoted.content)
      cards:insert(pandoc.Div({
        pandoc.Para(para),
        pandoc.Div(pandoc.Plain(pandoc.Str(term)), pandoc.Attr("", { "portfolio-quote__term" })),
      }, pandoc.Attr("", { "portfolio-quote" })))
    else
      cards:insert(pandoc.Div(item, pandoc.Attr("", { "portfolio-quote" })))
    end
  end
  return pandoc.Blocks({ pandoc.Div(cards, pandoc.Attr("", { "portfolio-quotes" })) })
end

local function materials_block(list)
  local rows = pandoc.Blocks({})
  for _, item in ipairs(list.content) do
    local first = item[1]
    if #item ~= 1 or not first.content then return nil end
    local inl = first.content
    if inl[1].t ~= "Link" then return nil end
    local link = inl[1]
    link.classes:insert("project-link")
    local desc = pandoc.Inlines({})
    for i = 2, #inl do desc:insert(inl[i]) end
    -- drop the ": " joining the link to its description
    if desc[1] and desc[1].t == "Str" and desc[1].text:match("^:") then
      desc[1].text = desc[1].text:gsub("^:%s*", "")
      if desc[1].text == "" then desc:remove(1) end
    end
    while desc[1] and desc[1].t == "Space" do desc:remove(1) end
    local row = pandoc.Blocks({ pandoc.Plain({ link }) })
    if #desc > 0 then
      row:insert(pandoc.Div(pandoc.Plain(desc), pandoc.Attr("", { "portfolio-material__desc" })))
    end
    rows:insert(pandoc.Div(row, pandoc.Attr("", { "portfolio-material" })))
  end
  return pandoc.Div(rows, pandoc.Attr("", { "portfolio-materials" }))
end

local function tiles_block(list)
  local tiles = pandoc.Blocks({})
  for _, item in ipairs(list.content) do
    local first = item[1]
    if #item ~= 1 or not first.content or first.content[1].t ~= "Strong" then return nil end
    local inl = first.content
    local label = inl[1]
    local desc = pandoc.Inlines({})
    for i = 2, #inl do desc:insert(inl[i]) end
    if desc[1] and desc[1].t == "Str" and desc[1].text:match("^:") then
      desc[1].text = desc[1].text:gsub("^:%s*", "")
      if desc[1].text == "" then desc:remove(1) end
    end
    while desc[1] and desc[1].t == "Space" do desc:remove(1) end
    local icon = "bi-lightbulb"
    local key = " " .. normalise(stringify(label)) .. " "
    for _, pair in ipairs(TILE_ICONS) do
      if key:find(pair[1], 1, true) then icon = pair[2]; break end
    end
    tiles:insert(pandoc.Div({
      pandoc.RawBlock("html", '<i class="bi ' .. icon .. '" aria-hidden="true"></i>'),
      pandoc.Div(pandoc.Plain(label.content), pandoc.Attr("", { "portfolio-tile__label" })),
      pandoc.Div(pandoc.Plain(desc), pandoc.Attr("", { "portfolio-tile__desc" })),
    }, pandoc.Attr("", { "portfolio-tile" })))
  end
  return pandoc.Div(tiles, pandoc.Attr("", { "portfolio-tiles" }))
end

------------------------------------------------------------- summary + chart

local function summarise(courses)
  local students, years, insts, recent = 0, nil, {}, {}
  for _, c in ipairs(courses) do
    if c.inst.key ~= "other" then insts[c.inst.key] = true end
    for _, r in ipairs(c.rows) do
      students = students + (r.students or 0)
      if r.year and (not years or r.year < years) then years = r.year end
      if c.inst.key == "jhu" and r.rating and r.year and r.year >= CURRENT_ROLE_START then
        recent[#recent + 1] = r
      end
    end
  end
  local n_insts = 0
  for _ in pairs(insts) do n_insts = n_insts + 1 end
  local stats = {
    { value = tostring(#courses), label = "courses taught" },
    -- Several tables have blank student counts, so the sum is a lower bound.
    { value = thousands(math.floor(students / 50) * 50) .. "+", label = "students taught" },
    { value = tostring(n_insts), label = "universities" },
    { value = years and tostring(years) or "", label = "teaching since" },
  }
  if #recent > 0 then
    local values, last = {}, 0
    for _, r in ipairs(recent) do
      values[#values + 1] = r.rating
      if r.year > last then last = r.year end
    end
    table.sort(values)
    local n = #values
    local median = n % 2 == 1 and values[(n + 1) / 2]
      or (values[n / 2] + values[n / 2 + 1]) / 2
    stats[#stats + 1] = {
      value = fmt(median) .. " / " .. recent[1].scale,
      label = "median JHU instructor rating, " .. CURRENT_ROLE_START .. "-" .. tostring(last):sub(3),
    }
  end
  return stats
end

local function stats_block(stats)
  if is_latex then
    local cols, vals, labels = {}, {}, {}
    for _, s in ipairs(stats) do
      cols[#cols + 1] = "c"
      vals[#vals + 1] = "\\portfoliostatvalue{" .. latex_escape(s.value) .. "}"
      labels[#labels + 1] = "\\portfoliostatlabel{" .. latex_escape(s.label) .. "}"
    end
    return pandoc.RawBlock("latex",
      "\\begin{portfoliostats}\n\\begin{tabularx}{\\linewidth}{" ..
      string.rep(">{\\centering\\arraybackslash}X", #stats) .. "}\n" ..
      table.concat(vals, " & ") .. " \\\\[-2pt]\n" ..
      table.concat(labels, " & ") .. "\n\\end{tabularx}\n\\end{portfoliostats}")
  end
  local parts = { '<div class="portfolio-stats">' }
  for _, s in ipairs(stats) do
    parts[#parts + 1] = '<div class="portfolio-stat"><span class="portfolio-stat__value">' ..
      html_escape(s.value) .. '</span><span class="portfolio-stat__label">' ..
      html_escape(s.label) .. '</span></div>'
  end
  parts[#parts + 1] = "</div>"
  return pandoc.RawBlock("html", table.concat(parts))
end

-- One point per semester with an instructor rating, as % of the scale's top.
local function chart_points(courses)
  local pts = {}
  for _, c in ipairs(courses) do
    for _, r in ipairs(c.rows) do
      if r.rating and r.t then
        pts[#pts + 1] = {
          t = r.t, pct = 100 * r.rating / r.scale, inst = c.inst,
          course = c.name, term = r.term, rating = fmt(r.rating) .. " / " .. r.scale,
        }
      end
    end
  end
  table.sort(pts, function(a, b) return a.t < b.t end)
  -- spread points that share a term so they do not sit on top of each other
  local i = 1
  while i <= #pts do
    local j = i
    while j < #pts and pts[j + 1].t == pts[i].t do j = j + 1 end
    local n = j - i + 1
    for k = i, j do pts[k].x = pts[k].t + (k - i - (n - 1) / 2) * 0.09 end
    i = j + 1
  end
  -- consecutive runs at one institution become labelled bands
  local bands = {}
  for _, p in ipairs(pts) do
    local b = bands[#bands]
    if b and b.inst == p.inst then
      b.lo = math.min(b.lo, p.x); b.hi = math.max(b.hi, p.x)
    else
      bands[#bands + 1] = { inst = p.inst, lo = p.x, hi = p.x }
    end
  end
  return pts, bands
end

local Y_MIN, Y_MAX = 60, 100

local function chart_svg(pts, bands)
  local W, H = 760, 250
  local L, R, T, B = 40, 12, 30, 26
  local x0 = math.floor(pts[1].t)
  local x1 = math.ceil(pts[#pts].t)
  local function sx(x) return L + (x - x0) / (x1 - x0) * (W - L - R) end
  local function sy(y) return T + (Y_MAX - y) / (Y_MAX - Y_MIN) * (H - T - B) end
  local function shape(key, x, y, cls)
    if key == "nw" then
      return string.format('<rect class="%s" x="%.1f" y="%.1f" width="9" height="9" rx="1.5"/>', cls, x - 4.5, y - 4.5)
    elseif key == "uwo" then
      return string.format('<path class="%s" d="M%.1f %.1fl5.5 5.5l-5.5 5.5l-5.5 -5.5z"/>', cls, x, y - 5.5)
    end
    return string.format('<circle class="%s" cx="%.1f" cy="%.1f" r="5"/>', cls, x, y)
  end

  local o = {}
  o[#o + 1] = string.format('<svg class="rating-chart" viewBox="0 0 %d %d" role="img" ' ..
    'aria-label="Instructor rating each semester, as a percentage of the scale maximum">', W, H)
  for _, b in ipairs(bands) do
    local bx0, bx1 = sx(b.lo - 0.2), sx(b.hi + 0.2)
    o[#o + 1] = string.format('<rect class="band inst-%s" x="%.1f" y="%d" width="%.1f" height="%d" rx="4"/>',
      b.inst.key, bx0, T - 22, bx1 - bx0, H - B - T + 22)
    local cx = (bx0 + bx1) / 2
    o[#o + 1] = '<g class="inst-' .. b.inst.key .. '">' ..
      shape(b.inst.key, cx - 4 - #b.inst.short * 3.1, T - 12, "mark") ..
      string.format('<text class="band-label" x="%.1f" y="%d" text-anchor="middle">%s</text></g>',
        cx + 6, T - 8, html_escape(b.inst.short))
  end
  for y = Y_MIN, Y_MAX, 10 do
    o[#o + 1] = string.format('<line class="grid" x1="%d" x2="%d" y1="%.1f" y2="%.1f"/>', L, W - R, sy(y), sy(y))
    o[#o + 1] = string.format('<text class="tick" x="%d" y="%.1f" text-anchor="end">%d%%</text>', L - 6, sy(y) + 4, y)
  end
  for yr = x0, x1, 2 do
    o[#o + 1] = string.format('<text class="tick" x="%.1f" y="%d" text-anchor="middle">%d</text>', sx(yr), H - 6, yr)
  end
  for _, p in ipairs(pts) do
    local x, y = sx(p.x), sy(p.pct)
    o[#o + 1] = '<g class="pt inst-' .. p.inst.key .. '" data-course="' .. html_escape(p.course) ..
      '" data-term="' .. html_escape(p.term) .. '" data-rating="' .. html_escape(p.rating) .. '">' ..
      string.format('<circle class="hit" cx="%.1f" cy="%.1f" r="11"/>', x, y) ..
      shape(p.inst.key, x, y, "mark") .. '</g>'
  end
  o[#o + 1] = "</svg>"
  return table.concat(o)
end

local CHART_CAPTION = "Instructor rating each semester, as a percentage of the top of " ..
  "each university's scale (5 at JHU, 6 at Northwestern, 7 at Western Ontario)."

local function chart_tikz(pts, bands)
  local W, H = 15.5, 5.0
  local x0 = math.floor(pts[1].t)
  local x1 = math.ceil(pts[#pts].t)
  local function sx(x) return (x - x0) / (x1 - x0) * W end
  local function sy(y) return (y - Y_MIN) / (Y_MAX - Y_MIN) * H end
  local function shape(key, x, y)
    if key == "nw" then
      return string.format("\\fill[instchart-nw] (%.3f,%.3f) +(-2.2pt,-2.2pt) rectangle +(2.2pt,2.2pt);", x, y)
    elseif key == "uwo" then
      return string.format("\\fill[instchart-uwo] (%.3f,%.3f) +(0,2.8pt) -- +(2.8pt,0) -- +(0,-2.8pt) -- +(-2.8pt,0) -- cycle;", x, y)
    end
    return string.format("\\fill[instchart-%s] (%.3f,%.3f) circle (2.4pt);", key, x, y)
  end
  local o = { "\\begin{center}\\begin{tikzpicture}[font=\\scriptsize]" }
  for _, b in ipairs(bands) do
    local bx0, bx1 = sx(b.lo - 0.2), sx(b.hi + 0.2)
    o[#o + 1] = string.format("\\fill[instchart-%s, opacity=0.09, rounded corners=2pt] (%.3f,0) rectangle (%.3f,%.3f);",
      b.inst.key, bx0, bx1, H + 0.55)
    local cx = (bx0 + bx1) / 2
    o[#o + 1] = shape(b.inst.key, cx - 0.2 - #b.inst.short * 0.055, H + 0.3)
    o[#o + 1] = string.format("\\node[text=black!65, anchor=west, inner sep=0] at (%.3f,%.3f) {%s};",
      cx - #b.inst.short * 0.055, H + 0.3, latex_escape(b.inst.short))
  end
  for y = Y_MIN, Y_MAX, 10 do
    o[#o + 1] = string.format("\\draw[black!12] (0,%.3f) -- (%.3f,%.3f);", sy(y), W, sy(y))
    o[#o + 1] = string.format("\\node[text=black!60, anchor=east] at (0,%.3f) {%d\\%%};", sy(y), y)
  end
  for yr = x0, x1, 2 do
    o[#o + 1] = string.format("\\node[text=black!60, anchor=north] at (%.3f,-0.12) {%d};", sx(yr), yr)
  end
  for _, p in ipairs(pts) do
    o[#o + 1] = shape(p.inst.key, sx(p.x), sy(p.pct))
  end
  o[#o + 1] = "\\end{tikzpicture}\\\\[2pt]"
  o[#o + 1] = "{\\footnotesize\\itshape\\color{black!65}" .. latex_escape(CHART_CAPTION) .. "}\\end{center}"
  return table.concat(o, "\n")
end

-- The hover tooltip. An SVG <title> only shows after the pointer rests for
-- about a second, and never on touch, so the chart draws its own: the point
-- under the pointer (or tapped) fills .chart-tip from its data-* attributes.
local CHART_TIP_SCRIPT = [[
<script>
(() => {
  const fig = document.currentScript.closest(".portfolio-chart");
  const svg = fig.querySelector("svg");
  const tip = fig.querySelector(".chart-tip");
  const hide = () => { tip.hidden = true; };
  const show = (g) => {
    tip.replaceChildren();
    const name = document.createElement("strong");
    name.textContent = g.dataset.course;
    const detail = document.createElement("span");
    detail.textContent = g.dataset.term + ": " + g.dataset.rating;
    tip.append(name, detail);
    tip.hidden = false;
    const f = fig.getBoundingClientRect();
    const m = g.querySelector(".mark").getBoundingClientRect();
    const w = tip.offsetWidth, h = tip.offsetHeight;
    const x = m.left + m.width / 2 - f.left;
    tip.style.left = Math.max(0, Math.min(f.width - w, x - w / 2)) + "px";
    tip.style.top = (m.top - f.top - h - 8) + "px";
  };
  svg.addEventListener("pointerover", (e) => {
    const g = e.target.closest(".pt");
    g ? show(g) : hide();
  });
  svg.addEventListener("pointerleave", hide);
})();
</script>]]

local function chart_block(courses)
  local pts, bands = chart_points(courses)
  if #pts == 0 then return nil end
  if is_latex then return pandoc.RawBlock("latex", chart_tikz(pts, bands)) end
  return pandoc.RawBlock("html",
    '<figure class="portfolio-chart">' .. chart_svg(pts, bands) ..
    '<div class="chart-tip" role="status" hidden></div>' ..
    '<figcaption>' .. html_escape(CHART_CAPTION) .. ' Hover over or tap a point for the course.</figcaption>' ..
    CHART_TIP_SCRIPT .. '</figure>')
end

------------------------------------------------------------------- the walk

function Pandoc(doc)
  if not (is_html or is_latex) then return doc end
  if is_html then
    quarto.doc.add_html_dependency({
      name = "teaching-portfolio",
      version = "1",
      stylesheets = { "../_theme/portfolio.css" },
    })
  end

  local out = pandoc.Blocks({})
  local courses = {}
  local h2, course, pending = nil, nil, nil
  local first_h2_at, courses_at
  local tiles_done = false

  for _, blk in ipairs(doc.blocks) do
    if blk.t == "Header" and blk.level == 2 then
      h2 = stringify(blk.content)
      course, pending = nil, nil
      out:insert(blk)
      first_h2_at = first_h2_at or #out
      if h2 == "Courses" then courses_at = #out end
    elseif blk.t == "Header" and blk.level == 3 and h2 == "Courses" then
      course = parse_course_heading(blk)
      course.rows = {}
      courses[#courses + 1] = course
      pending = nil
      out:insert(decorate_heading(blk, course))
    elseif blk.t == "Header" and blk.level == 4 then
      local t = stringify(blk.content)
      if t == "Selected student comments" then pending = "quotes"
      elseif t == "Sample materials" then pending = "materials"
      else pending = nil end
      out:insert(blk)
    elseif blk.t == "Table" and course and not course.table_seen then
      course.table_seen = true
      out:insert(read_table(blk, course))
      if is_html then
        local card = project_card(course)
        if card then out:insert(card) end
      end
    elseif blk.t == "BulletList" and pending == "quotes" and course then
      out:extend(quotes_block(blk, course.inst.key))
      pending = nil
    elseif blk.t == "BulletList" and pending == "materials" and is_html then
      out:insert(materials_block(blk) or blk)
      pending = nil
    elseif blk.t == "BulletList" and h2 == "Teaching philosophy" and not tiles_done and is_html then
      local tiles = tiles_block(blk)
      out:insert(tiles or blk)
      tiles_done = tiles ~= nil
    else
      out:insert(blk)
    end
  end

  -- Insert the chart first: it sits after the summary band's position.
  if courses_at then
    local chart = chart_block(courses)
    if chart then out:insert(courses_at + 1, chart) end
  end
  if first_h2_at and #courses > 0 then
    out:insert(first_h2_at, stats_block(summarise(courses)))
  end

  doc.blocks = out
  return doc
end

return { { Pandoc = Pandoc } }

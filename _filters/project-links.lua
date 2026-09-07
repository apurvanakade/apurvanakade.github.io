--[[
  AI-owned Pandoc filter for projects/*.qmd.  See CLAUDE.md.

  Turns a `links:` list in a project's frontmatter

      links:
        - text: "Course notes"
          href: "https://..."

  into a row of buttons at the top of the rendered page, plus a matching
  "categories" line.  Project .qmd files therefore stay frontmatter + prose,
  with no markup for chrome.
--]]

local links = nil

function Meta(meta)
  links = meta.links
  return meta
end

function Pandoc(doc)
  if not links or #links == 0 then return doc end

  local items = {}
  for _, l in ipairs(links) do
    if l.href and l.text then
      local href = pandoc.utils.stringify(l.href)
      local link = pandoc.Link(l.text, href, "",
        pandoc.Attr("", { "project-link" }))
      items[#items + 1] = pandoc.Plain({ link })
    end
  end
  if #items == 0 then return doc end

  local bar = pandoc.Div(items, pandoc.Attr("", { "project-links" }))
  local blocks = { bar }
  for _, b in ipairs(doc.blocks) do blocks[#blocks + 1] = b end
  doc.blocks = pandoc.Blocks(blocks)
  return doc
end

return { { Meta = Meta }, { Pandoc = Pandoc } }

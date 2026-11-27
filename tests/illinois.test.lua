-- illinois-revealjs tests. Run from the repo root: quarto pandoc lua path/to/qtest.lua
-- tests/fixtures/template.qmd links to the repo's template.qmd, the deck that
-- quarto use template gives people, so these tests render that deck.
local t = require("qtest")

local FORMAT = "illinois-revealjs"

--- Render the template deck. With `read`, also read those output files.
---@param read? string[]
---@return QtestResult
local function deck(read)
  return t.render("template.qmd", FORMAT, { output = "template.html", read = read })
end

--- The compiled theme stylesheet: its path in the render folder, and its text.
--- Its name carries a content hash, so one render finds it and a second reads it.
---@return string path
---@return string css
local function theme()
  local path
  for file in pairs(deck().files) do
    if file:match("^template_files/libs/revealjs/dist/theme/quarto%-[%x]+%.css$") then path = file end
  end
  t.ok(path, "the render has a compiled theme stylesheet")
  local css = deck({ path }).extra[path]
  t.ok(css, "the theme stylesheet can be read")
  return path, css
end

--- Resolve a relative url() against the folder of the stylesheet.
---@param css_path string
---@param url string
---@return string
local function resolve(css_path, url)
  local parts = {}
  for part in css_path:gmatch("[^/]+") do parts[#parts + 1] = part end
  parts[#parts] = nil
  for part in url:gmatch("[^/]+") do
    if part == ".." then parts[#parts] = nil else parts[#parts + 1] = part end
  end
  return table.concat(parts, "/")
end

t.test("the template deck renders with the logo, slide numbers and a long date", function()
  local r = deck()
  r:succeeded()
  t.contains(r.text, '<img src="_extensions/illinois/logo-illinois-block-i.png" class="slide-logo">')
  t.ok(r.files["logo-illinois-block-i.png"], "the logo is copied next to the deck")
  t.contains(r.text, "slideNumber: 'c/t'")
  t.ok(r.text:match('<p class="date">%u%l+ %d%d?, %d%d%d%d</p>'), "the date is in long form, such as May 25, 2023")
end)

t.test("the theme sets the documented fonts and colors", function()
  local path, css = theme()
  css = css:lower()
  t.contains(css, '"fira sans"')
  t.contains(css, '"fira code"')
  t.contains(css, "h1.title{color:#1a292c")              -- title slide text
  t.contains(css, "background-color:#eb811b")            -- the orange rules
  t.contains(css, ".reveal a{line-height:1.5em;color:#e84a27") -- links
  t.contains(css, "#fafafa")                             -- background
  t.contains(css, ".reveal .progress{color:#23373b}")    -- progress bar
  -- The menu and chalkboard icons are SVGs in data URLs, which need rgb()
  -- because a "#" would end the URL
  t.count(css, 'fill="rgb(35, 55, 59)"', 3)
  -- The block I in each slide heading points at the copied logo
  local url = css:match('%.reveal h2:before{[^}]*background%-image:url%("([^"]+)"%)')
  t.ok(url, "slide headings have a background logo")
  t.ok(deck().files[resolve(path, url)], "the heading logo url resolves to the copied logo, got " .. tostring(url))
end)

-- Regression: the unquoted url() of the heading logo made every render print
-- "Error adding css vars block SCSSParsingError", leave a
-- _quarto_internal_scss_error.scss file behind, and drop the theme's exported
-- --quarto-scss-export-* CSS variables.
t.test("the theme compiles without an SCSS error and keeps its exported CSS variables", function()
  local r = deck()
  t.not_contains(r.log, "SCSSParsingError")
  for file in pairs(r.files) do
    t.ok(not file:find("_quarto_internal_scss_error", 1, true), "no SCSS error file is left behind, found " .. file)
  end
  local _, css = theme()
  t.ok(t.occurrences(css, "--quarto-scss-export-") > 0, "the theme exports its SCSS variables")
end)

-- Regression: the template's closing slide told people to install from the
-- repository's old name, coatless/quarto-illinois.
t.test("the template's install instructions name the current repository", function()
  local f = assert(io.open("template.qmd"))
  local text = f:read("a")
  f:close()
  t.contains(text, "quarto add coatless-quarto/illinois-revealjs")
  t.contains(text, "quarto use template coatless-quarto/illinois-revealjs")
  t.not_contains(text, "coatless/quarto-illinois")
end)

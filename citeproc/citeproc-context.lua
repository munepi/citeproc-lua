--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local context = {}

local LocalizedQuotes = require("citeproc-output").LocalizedQuotes

local util = require("citeproc-util")


local Context = {
  reference = nil,
  format = nil,
  cite_id = nil,
  style = nil,
  locale = nil,
  name_citation = nil,
  names_delimiter = nil,

  position = nil,

  disamb_pass = nil,

  cite = nil,
  bib_number = nil,

  in_bibliography = false,
  sort_key = nil,

  year_suffix = nil,
}

function Context:new()
  local o = {
    in_bibliography = false
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function Context:get_variable(name, form)
  local variable_type = util.variable_types[name]
  if variable_type == "number" then
    return self:get_number(name)
  -- elseif variable_type == "date" then
  --   return self:get_date(name)
  elseif variable_type == "name" then
    return self:get_name(name)
  else
    return self:get_ordinary(name, form)
  end
end

function Context:get_number(name)
  if name == "locator" then
    return self.cite.locator
  elseif name == "citation-number" then
    -- return self.bib_number
    return self.reference["citation-number"]
  elseif name == "first-reference-note-number" then
    return self.cite["first-reference-note-number"]
  elseif name == "page-first" then
    return self.page_first(self.reference.page)
  else
    return self.reference[name]
  end
end

function Context:get_ordinary(name, form)
  local res = nil
  local variable_name = name
  if form and form ~= "long" then
    variable_name = variable_name .. "-" .. form
  end

  if variable_name == "locator" or variable_name == "label" then
    res = self.cite[variable_name]
  else
    res = self.reference[variable_name]
  end
  if res then
    return res
  end

  if variable_name == "container-title-short" then
    res = self.reference["journalAbbreviation"]
    if res then
      return res
    end
  end

  if form then
    res = self.reference[name]
    if res then
      return res
    end
  end

  -- if name == "title-short" or name == "container-title-short" then
  --   variable_name = string.gsub(name, "%-short$", "")
  --   res = self.reference[variable_name]
  -- end

  return res
end

-- TODO: optimize: process only once
-- TODO: organize the name parsing code
function Context:get_name(variable_name)
  local names = self.reference[variable_name]
  if names then
    for _, name in ipairs(names) do
      if name.family == "" then
        name.family = nil
      end
      if name.given == "" then
        name.given = nil
      end
      if name.given and not name.family then
        name.family = name.given
        name.given = nil
      end
      self:parse_name_suffix(name)
      self:split_ndp_family(name)
      -- self:split_given_ndp(name)
      self:split_given_dp(name)
    end
  end
  return names
end

function Context:parse_name_suffix(name)
  if not name.suffix and name.family and string.match(name.family, ",") then
    local words = util.split(name.family, ",%s*")
    name.suffix = words[#words]
    name.family = table.concat(util.slice(words, 1, -2), ", ")
  end
  if not name.suffix and name.given and string.match(name.given, ",") then
    -- Split name suffix: magic_NameSuffixNoComma.txt
    -- "John, III" => given: "John", suffix: "III"
    local words = util.split(name.given, ",%s*")
    name.suffix = words[#words]
    name.given = table.concat(util.slice(words, 1, -2), ", ")
  end
end

function Context:split_ndp_family(name)
  if name["non-dropping-particle"] or not name.family then
    return
  end
  if util.startswith(name.family, '"') and util.endswith(name.family, '"') then
    -- Stop parsing family name if surrounded by quotation marks
    -- bugreports_parseName.txt
    name.family = string.gsub(name.family, '"', "")
    return
  end
  local ndp_parts = {}
  local family_parts = {}
  local parts = util.split(name.family)
  for i, part in ipairs(parts) do
    local ndp, family
    -- d'Aubignac
    ndp, family = string.match(part, "^(%l')(.+)$")
    if ndp and family then
      table.insert(ndp_parts, ndp)
      parts[i] = family
    else
      ndp, family = string.match(part, "^(%l’)(.+)$")
      if ndp and family then
        table.insert(ndp_parts, ndp)
        parts[i] = family
      else
        -- al-Aswānī
        ndp, family = string.match(part, "^(%l+%-)(.+)$")
        if ndp and family then
          table.insert(ndp_parts, ndp)
          parts[i] = family
        elseif i < #parts and util.is_lower(part) then
          table.insert(ndp_parts, part)
        end
      end
    end
    if ndp or i == #parts then
      for j = i, #parts do
        table.insert(family_parts, parts[j])
      end
      break
    end
    if not util.is_lower(part) then
      for j = i, #parts do
        table.insert(family_parts, parts[j])
      end
      break
    end
  end
  if #ndp_parts > 0 then
    name["non-dropping-particle"] = table.concat(ndp_parts, " ")
    name.family = table.concat(family_parts, " ")
  end
end

function Context:split_given_dp(name)
  if name["dropping-particle"] or not name.given then
    return
  end
  local dp_parts = {}
  local given_parts = {}
  local parts = util.split(name.given)
  for i = #parts, 1, -1 do
    local part = parts[i]
    if i == 1 or not util.is_lower(part) then
      for j = 1, i do
        table.insert(given_parts, parts[j])
      end
      break
    end
  -- name_ParsedDroppingParticleWithApostrophe.txt
  -- given: "François Hédelin d'" =>
  -- given: "François Hédelin", dropping-particle: "d'"
    if string.match(part, "^%l+'?$") or string.match(part, "^%l+’$") then
      table.insert(dp_parts, 1, part)
    end
  end
  if #dp_parts > 0 then
    name["dropping-particle"] = table.concat(dp_parts, " ")
    name.given = table.concat(given_parts, " ")
  end
end

-- function Context:split_given_ndp(name)
--   if name["non-dropping-particle"] or not name.given then
--     return
--   end

--   if not (string.match(name.given, "%l'$") or string.match(name.given, "%l’$")) then
--     return
--   end

--   local words = util.split(name.given)
--   if #words < 2 then
--     return
--   end
--   local last_word = words[#words]
--   if util.endswith(last_word, "'") or util.endswith(last_word, util.unicode["apostrophe"]) then
--     name["non-dropping-particle"] = last_word
--     name.given = table.concat(util.slice(words, 1, -2), " ")
--   end
--   util.debug(name)
-- end

function Context:get_localized_date(form)
  return self.locale.dates[form]
end

function Context:get_macro(name)
  local res = self.style.macros[name]
  if not res then
    util.error(string.format('Undefined macro "%s"', name))
  end
  return res
end

function Context:get_simple_term(name, form, plural)
  -- assert(self.locale)
  return self.locale:get_simple_term(name, form, plural)
end

function Context:get_localized_quotes()
  return LocalizedQuotes:new(
    self:get_simple_term("open-quote"),
    self:get_simple_term("close-quote"),
    self:get_simple_term("open-inner-quote"),
    self:get_simple_term("close-inner-quote"),
    self.locale.style_options.punctuation_in_quote
  )
end

function Context.page_first(page)
  local page_first = util.split(page, "%s*[&,-]%s*")[1]
  return util.split(page_first, util.unicode["en dash"])[1]
end

-- https://docs.citationstyles.org/en/stable/specification.html#non-english-items
function Context:is_english()
  local language = self:get_variable("language")
  if util.startswith(self.engine.lang, "en") then
    if not language or util.startswith(language, "en") then
      return true
    else
      return false
    end
  else
    if language and util.startswith(language, "en") then
      return true
    else
      return false
    end
  end
end


local IrState = {}

function IrState:new(style, cite_id, cite, reference)
  local o = {
    macro_stack = {},
    suppressed = {},
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function IrState:push_macro(macro_name)
  for _, name in ipairs(macro_name) do
    if name == macro_name then
      util.error(string.format('Recursive macro "%s".', macro_name))
    end
    table.insert(self.macro_stack, macro_name)
  end
end

function IrState:pop_macro(macro_name)
  table.remove(self.macro_stack)
end


context.Context = Context
context.IrState = IrState

return context

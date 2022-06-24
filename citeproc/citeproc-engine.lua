--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local engine = {}

local dom = require("luaxml-domobject")

local richtext = require("citeproc-richtext")
local Element = require("citeproc-element").Element
local nodes = require("citeproc-nodes")
local Style = require("citeproc-node-style").Style
local Locale = require("citeproc-node-locale").Locale
local Context = require("citeproc-context").Context
local IrState = require("citeproc-context").IrState
local formats = require("citeproc-formats")
local OutputFormat = require("citeproc-output").OutputFormat
local InlineElement = require("citeproc-output").InlineElement
local PlainText = require("citeproc-output").PlainText
local HtmlWriter = require("citeproc-output").HtmlWriter
local util = require("citeproc-util")


local CiteProc = {}

function CiteProc.new (sys, style, lang, force_lang)
  if not sys then
    error("\"citeprocSys\" required")
  end
  if sys.retrieveLocale == nil then
    error("\"citeprocSys.retrieveLocale\" required")
  end
  if sys.retrieveItem == nil then
    error("\"citeprocSys.retrieveItem\" required")
  end
  local o = {}
  o.registry = {
    citations = {},  -- A map
    citation_strings = {},  -- A list
    registry = {},  -- A map
    reflist = {},  -- A list
    previous_citation = nil,
    requires_sorting = false,
  }

  o.sys = sys
  o.locales = {}
  o.system_locales = {}

  -- TODO: rename to style
  o.style_element = Style:parse(style)
  -- util.debug(o.style_element)

  if type(style) == "string" then
    o.csl = dom.parse(style)
  else
    o.csl = style
  end
  o.csl:traverse_elements(CiteProc.set_base_class)
  o.csl:root_node().engine = o
  o.style = o.csl:get_path("style")[1]
  o.style.lang = lang

  o.csl:root_node().style = o.style

  o.lang = o.style_element.default_locale
  if not o.lang or force_lang then
    o.lang = lang or "en-US"
  end

  o.formatter = formats.latex
  o.linking_enabled = false

  setmetatable(o, { __index = CiteProc })
  return o
end

function CiteProc:build_cluster(citation_items)
  local output_format = OutputFormat:new()
  local irs = {}
  for _, cite_item in ipairs(citation_items) do
    local state = IrState:new(self.style_element)
    cite_item.id = tostring(cite_item.id)
    local context = Context:new()
    context.engine = self
    context.style = self.style_element
    context.area = self.style_element.citation
    context.locale = self:get_locale(self.lang)
    context.name_inheritance = self.style_element.citation.name_inheritance
    context.format = output_format
    context.id = cite_item.id
    context.cite = cite_item
    context.reference = self:get_item(cite_item.id)

    local ir = self.style_element.citation:build_ir(self, state, context)
    table.insert(irs, ir)
  end

  -- util.debug(irs)

  -- TODO: disambiguation

  -- TODO: collapsing

  -- TODO: Capitalize first
  for i, ir in ipairs(irs) do
    local prefix = citation_items[i].prefix
    if prefix and string.match(prefix, "%.%s*$") and
        #util.split(util.strip(prefix)) > 1 or not prefix then
      -- util.debug(ir)
      ir:capitalize_first_term()
    end
  end

  -- util.debug(irs)

  local citation_delimiter = self.style_element.citation.layout.delimiter
  local citation_stream = {}

  local context = Context:new()
  context.engine = self
  context.style = self.style_element
  context.area = self.style_element.citation
  context.locale = self:get_locale(self.lang)
  context.name_inheritance = self.style_element.citation.name_inheritance
  context.format = output_format

  for i, ir in ipairs(irs) do
    local cite_prefix = citation_items[i].prefix
    local cite_suffix = citation_items[i].suffix
    if citation_delimiter and i > 1 and not (cite_prefix and util.startswith(cite_prefix, ",")) then
      table.insert(citation_stream, PlainText:new(citation_delimiter))
    end

    if cite_prefix then
      for _, inline in ipairs(InlineElement:parse(cite_prefix, context)) do
        table.insert(citation_stream, inline)
      end
    end

    for _, el in ipairs(ir:flatten(output_format)) do
      table.insert(citation_stream, el)
    end

    if cite_suffix then
      for _, inline in ipairs(InlineElement:parse(cite_suffix, context)) do
        table.insert(citation_stream, inline)
      end
    end
  end

  -- util.debug(citation_stream)

  if #citation_stream == 0 then
    citation_stream = {PlainText:new("[CSL STYLE ERROR: reference with no printed form.]")}
  end

  local str = output_format:output(citation_stream)

  return str
end

function CiteProc:updateItems (ids)
  self.registry.reflist = {}
  self.registry.registry = {}
  for _, id in ipairs(ids) do
    self:get_item(id)
  end
end

function CiteProc:updateUncitedItems(ids)
  for _, id in ipairs(ids) do
    if not self.registry.registry[id] then
      self:get_item(id)
    end
  end
  -- TODO: disambiguation
end

function CiteProc:processCitationCluster(citation, citationsPre, citationsPost)
  self.registry.citations[citation.citationID] = citation

  local items = {}

  local cite_first_note_numbers = {}
  local cite_last_note_numbers = {}
  local previous_citation = nil
  for _, citation_pre in ipairs(citationsPre) do
    local pre_citation = self.registry.citations[citation_pre[1]]
    for _, cite_item in ipairs(pre_citation.citationItems) do
      if not cite_first_note_numbers[cite_item.id] then
        cite_first_note_numbers[cite_item.id] = pre_citation.properties.noteIndex
      end
      cite_last_note_numbers[cite_item.id] = pre_citation.properties.noteIndex
    end
    previous_citation = pre_citation
  end

  for i, cite_item in ipairs(citation.citationItems) do
    cite_item.id = tostring(cite_item.id)
    local item_data = self:get_item(cite_item.id)

    local previous_cite
    if i > 1 then
      previous_cite = citation.citationItems[i-1]
    end

    if item_data then
      -- Create a wrapper of the orignal item from registry so that
      -- it may hold different `locator` or `position` values for cites.
      local item = setmetatable(cite_item, {__index = item_data})

      -- Use "page" as locator label if missing
      -- label_PluralWithAmpersand.txt
      if item.locator and not item.label then
        item.label = "page"
      end

      self:set_cite_position(item, citation.properties.noteIndex, cite_first_note_numbers, cite_last_note_numbers, previous_cite, previous_citation)

      table.insert(items, item)
    end
  end

  if self.registry.requires_sorting then
    self:sort_bibliography()
  end

  local params = {
    bibchange = false,
    citation_errors = {},
  }

  local citation_id_note_list = {}
  for _, citation_id_note in ipairs(citationsPre) do
    table.insert(citation_id_note_list, citation_id_note)
  end
  local note_index = 0
  if citation.properties and citation.properties.noteIndex then
    note_index = citation.properties.noteIndex
  end
  table.insert(citation_id_note_list, {citation.citationID, note_index})
  for _, citation_id_note in ipairs(citationsPost) do
    table.insert(citation_id_note_list, citation_id_note)
  end

  local citation_id_cited = {}
  for _, citation_id_note in ipairs(citation_id_note_list) do
    citation_id_cited[citation_id_note[1]] = true
  end
  for citation_id, _ in pairs(self.registry.citations) do
    if not citation_id_cited[citation_id] then
      self.registry.citations[citation_id] = nil
      self.registry.citation_strings[citation_id] = nil
    end
  end

  local output = {}

  for i, citation_id_note in ipairs(citation_id_note_list) do
    local citation_id = citation_id_note[1]
    -- local note_index = citation_id_note[2]
    if citation_id == citation.citationID then
      -- local context = {
      --   build = {},
      --   engine = self,
      -- }
      -- local citation_str = self.style:render_citation(items, context)
      local citation_str = self:build_cluster(items)

      self.registry.citation_strings[citation_id] = citation_str
      table.insert(output, {i - 1, citation_str, citation_id})
    else
      -- TODO: correct note_index
      -- TODO: update other citations after disambiguation
      local citation_str = self.registry.citation_strings[citation_id]
      if self.registry.citation_strings[citation_id] ~= citation_str then
        params.bibchange = true
        self.registry.citation_strings[citation_id] = citation_str
        table.insert(output, {i - 1, citation_str, citation_id})
      end
    end
  end

  return {params, output}
end

function CiteProc:set_cite_position(item, note_number, cite_first_note_numbers, cite_last_note_numbers, previous_cite, previous_citation)
  if type(note_number) ~= "number" then
    note_number = tonumber(note_number)
  end

  item.note_number = note_number
  if cite_first_note_numbers[item.id] then
    item.position = util.position_map["subsequent"]
    item["first-reference-note-number"] = cite_first_note_numbers[item.id]
    item.note_distance = note_number - cite_last_note_numbers[item.id]
  else
    item.position = util.position_map["first"]
    item["first-reference-note-number"] = note_number
    cite_first_note_numbers[item.id] = note_number
    item.note_distance = 0
  end
  cite_last_note_numbers[item.id] = note_number

  -- Find the preceding cite referencing the same item
  local preceding_cite
  if previous_cite then
    -- a. the current cite immediately follows on another cite, within the same
    -- citation, that references the same item
    if item.id == previous_cite.id then
      preceding_cite = previous_cite
    end
  elseif previous_citation then
    -- b. the current cite is the first cite in the citation, and the previous
    -- citation consists of a single cite referencing the same item
    if #previous_citation.citationItems == 1 and previous_citation.citationItems[1].id == item.id then
      preceding_cite = previous_citation.citationItems[1]
    end
  end

  if preceding_cite then
    if preceding_cite.locator then
      if item.locator then
        if item.locator == preceding_cite.locator then
          item.position = util.position_map["ibid"]
        else
          item.position = util.position_map["ibid-with-locator"]
        end
      else
        item.position = util.position_map["subsequent"]
      end
    else
      if item.locator then
        item.position = util.position_map["ibid-with-locator"]
      else
        item.position = util.position_map["ibid"]
      end
    end
  end
end

function CiteProc:makeCitationCluster (citation_items)
  local items = {}
  for _, cite_item in ipairs(citation_items) do
    cite_item.id = tostring(cite_item.id)
    local position_first = (self.registry.registry[cite_item.id] == nil)
    local item_data = self:get_item(cite_item.id)

    -- Create a wrapper of the orignal item from registry so that
    -- it may hold different `locator` or `position` values for cites.
    local item = setmetatable(cite_item, {__index = item_data})

    -- Use "page" as locator label if missing
    -- label_PluralWithAmpersand.txt
    if item.locator and not item.label then
      item.label = "page"
    end

    if not item.position and position_first then
      item.position = util.position_map["first"]
    end
    table.insert(items, item)
  end

  if self.registry.requires_sorting then
    self:sort_bibliography()
  end

  local res = self:build_cluster(citation_items)

  -- local context = {
  --   build = {},
  --   engine=self,
  -- }
  -- local res = self.style:render_citation(items, context)

  self.registry.previous_citation = {
    citationID = "pseudo-citation",
    citationItems = items,
    properties = {
      noteIndex = 1,
    }
  }
  return res
end

function CiteProc:makeBibliography()
  local output_format = OutputFormat:new()
  local html_writer = HtmlWriter:new()

  local params = {
    -- TODO: change to other formats
    bibstart = html_writer.markups["bibstart"],
    bibend = html_writer.markups["bibend"],
  }
  local res = {}

  if not self.style_element.bibliography then
    return params, res
  end

  for _, id in ipairs(self:get_sorted_refs()) do
    local ref = self.registry.registry[id]

    local state = IrState:new()
    local context = Context:new()
    context.engine = self
    context.style = self.style_element
    context.area = self.style_element.bibliography
    context.locale = self:get_locale(self.lang)
    context.name_inheritance = self.style_element.bibliography.name_inheritance
    context.format = output_format
    context.id = id
    context.cite = nil
    context.reference = self:get_item(id)

    local ir = self.style_element.bibliography:build_ir(self, state, context)

    -- subsequent_author_substitute

    local flat = ir:flatten(output_format)

    local str = output_format:output_bibliography_entry(flat)

    table.insert(res, str)
  end

  return {params, res}
end

function CiteProc:get_sorted_refs()
  if self.registry.requires_sorting then
    self:sort_bibliography()
  end
  return self.registry.reflist
end

function CiteProc:set_formatter(format)
  self.formatter = formats[format]
end

function CiteProc:enable_linking()
  self.linking_enabled = true
end

function CiteProc:disable_linking()
  self.linking_enabled = false
end

function CiteProc.set_base_class (node)
  if node:is_element() then
    local name = node:get_element_name()
    local element_class = nodes[name]
    if element_class then
      element_class:set_base_class(node)
    else
      Element:set_base_class(node)
    end
  end
end

function CiteProc.create_element_tree(node)
  local element_name = node:get_element_name()
  local element_class = nodes[element_name]
  local el = nil
  if element_class then
    el = element_class:from_node(node)
  end
  if el then
    for i, child in ipairs(node:get_children()) do
      if child:is_element() then
        local child_element = CiteProc.create_element_tree(child)
        if child_element then
          if not el.children then
            el.children = {}
          end
          table.insert(el.children, child_element)
        end
      end
    end
  end
  return el
end

function CiteProc:get_style_class()
  return self.style:get_attribute("class") or "in-text"
end

function CiteProc:get_item (id)
  local item = self.registry.registry[id]
  if not item then
    item = self:_retrieve_item(id)
    if not item then
      return nil
    end
    table.insert(self.registry.reflist, id)
    item["citation-number"] = #self.registry.reflist
    self.registry.registry[id] = item
    self.registry.requires_sorting = true
  end
  -- local res = {}
  -- setmetatable(res, {__index = item})
  -- return res
  return item
end

function CiteProc:_retrieve_item (id)
  -- Retrieve, copy, and normalize
  local res = {}
  local item = self.sys.retrieveItem(id)
  if not item then
    util.warning(string.format('Failed to retrieve item "%s"', id))
    return nil
  end

  item.id = tostring(item.id)

  for key, value in pairs(item) do
    res[key] = value
  end

  -- if res["page"] and not res["page-first"] then
  --   local page_first = util.split(res["page"], "%s*[&,-]%s*")[1]
  --   page_first = util.split(page_first, util.unicode["en dash"])[1]
  --   res["page-first"] = page_first
  -- end

  return res
end

function CiteProc.normalize_string (str)
  if not str or str == "" then
    return str
  end
  -- French punctuation spacing
  if type(str) == "string" then
    str = string.gsub(str, " ;", util.unicode["narrow no-break space"] .. ";")
    str = string.gsub(str, " %?", util.unicode["narrow no-break space"] .. "?")
    str = string.gsub(str, " !", util.unicode["narrow no-break space"] .. "!")
    str = string.gsub(str, " »", util.unicode["narrow no-break space"] .. "»")
    str = string.gsub(str, "« ", "«" .. util.unicode["narrow no-break space"])
  end
  -- local text = str
  local text = richtext.new(str)
  return text
end

function CiteProc:sort_bibliography()
  -- Sort the items in registry according to the `sort` in `bibliography.`
  -- This will update the `citation-number` of each item.
  local bibliography_sort = self.style:get_path("style bibliography sort")[1]
  if not bibliography_sort then
    return
  end
  local items = {}
  for _, id in ipairs(self.registry.reflist) do
    table.insert(items, self.registry.registry[id])
  end

  local context = {
    engine = self,
    style = self.style,
    mode = "bibliography",
  }
  context = self.style:process_context(context)
  context = self.style:get_path("style bibliography")[1]:process_context(context)

  bibliography_sort:sort(items, context)
  self.registry.reflist = {}
  for i, item in ipairs(items) do
    item["citation-number"] = i
    table.insert(self.registry.reflist, item.id)
  end
  self.registry.requires_sorting = false
end

function CiteProc:get_locale(lang)
  if string.len(lang) == 2 then
    lang = util.primary_dialects[lang] or lang
  end
  local locale = self.locales[lang]
  if locale then
    return locale
  else
    return self:get_merged_locales(lang)
  end
end

function CiteProc:get_merged_locales(lang)
  local fall_back_locales = {}

  local language = string.sub(lang, 1, 2)
  local primary_dialect = util.primary_dialects[language]

  -- 1. In-style cs:locale elements
  --    i. `xml:lang` set to chosen dialect, “de-AT”
  table.insert(fall_back_locales, self.style_element.locales[lang])

  --    ii. `xml:lang` set to matching language, “de” (German)
  if language and language ~= lang then
    table.insert(fall_back_locales, self.style_element.locales[language])
  end

  --    iii. `xml:lang` not set
  table.insert(fall_back_locales, self.style_element.locales["@generic"])

  -- 2. Locale files
  --    iv. `xml:lang` set to chosen dialect, “de-AT”
  if lang then
    table.insert(fall_back_locales, self:get_system_locale(lang))
  end

  --    v. `xml:lang` set to matching primary dialect, “de-DE” (Standard German)
  --       (only applicable when the chosen locale is a secondary dialect)
  if primary_dialect and primary_dialect ~= lang then
    table.insert(fall_back_locales, self:get_system_locale(primary_dialect))
  end

  --    vi. `xml:lang` set to “en-US” (American English)
  if lang ~= "en-US" and primary_dialect ~= "en-US" then
    table.insert(fall_back_locales, self:get_system_locale("en-US"))
  end

  -- Merge locales

  local locale = Locale:new()
  for i = #fall_back_locales, 1, -1 do
    local fall_back_locale = fall_back_locales[i]
    locale:merge(fall_back_locale)
  end

  self.locales[lang] = locale
  return locale
end

function CiteProc:get_system_locale(lang)
  local locale = self.system_locales[lang]
  if locale then
    return locale
  end

  local locale_str = self.sys.retrieveLocale(lang)
  if not locale_str then
    util.warning(string.format("Failed to retrieve locale \"%s\"", lang))
    return nil
  end
  local locale_xml = dom.parse(locale_str)
  local root_element = locale_xml:get_path("locale")[1]
  locale = Locale:from_node(root_element)
  self.system_locales[lang] = locale
  return locale
end


engine.CiteProc = CiteProc

return engine

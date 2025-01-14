--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local style_module = {}

local dom = require("luaxml-domobject")

local Element = require("citeproc-element").Element
local IrNode = require("citeproc-ir-node").IrNode
local Rendered = require("citeproc-ir-node").Rendered
local SeqIr = require("citeproc-ir-node").SeqIr
local PlainText = require("citeproc-output").PlainText
local DisamStringFormat = require("citeproc-output").DisamStringFormat
local util = require("citeproc-util")


local Style = Element:derive("style")

function Style:new()
  local o = {
    children = {},
    macros = {},
    locales = {},
    initialize_with_hyphen = true,
    demote_non_dropping_particle = "display-and-sort",
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function Style:parse(xml_str)
  -- The parsing error is not caught by busted in some situcations and thus it's processed here.
  -- discretionary_CitationNumberAuthorOnlyThenSuppressAuthor.txt
  local status, csl_xml = pcall(function () return dom.parse(xml_str) end)
  if not status or not csl_xml then
    if csl_xml then
      local error_message = string.match(csl_xml, "^.-: (.*)$")
      util.error("CSL parsing error: " .. util.rstrip(error_message))
    else
      util.error("CSL parsing error")
    end
    return nil
  end
  local style_node = csl_xml:get_path("style")[1]
  if not csl_xml then
    error('Element "style" not found.')
  end
  return Style:from_node(style_node)
end

function Style:from_node(node)
  local o = Style:new()

  o:set_attribute(node, "class")
  o:set_attribute(node, "default-locale")
  o:set_attribute(node, "version")

  -- Global Options
  o.initialize_with_hyphen = true
  o:set_bool_attribute(node, "initialize-with-hyphen")
  o:set_attribute(node, "page-range-format")
  o:set_attribute(node, "demote-non-dropping-particle")

  -- Inheritable Name Options
  -- https://docs.citationstyles.org/en/stable/specification.html#inheritable-name-options
  o.name_inheritance = require("citeproc-node-names").Name:new()
  Element.make_name_inheritance(o.name_inheritance, node)

  if o.page_range_format == "chicago" then
    if o.version < "1.1" then
      o.page_range_format = "chicago-15"
    else
      o.page_range_format = "chicago-16"
    end
  end

  o.macros = {}
  o.locales = {}

  o.children = {}
  o:process_children_nodes(node)

  for _, child in ipairs(o.children) do
    local element_name = child.element_name
    if element_name == "info" then
      o.info = child
    elseif element_name == "citation" then
      o.citation = child
    elseif element_name == "bibliography" then
      o.bibliography = child
    elseif element_name == "intext" then
      o.intext = child
    elseif element_name == "macro" then
      o.macros[child.name] = child
    elseif element_name == "locale" then
      local xml_lang = child.xml_lang or "@generic"
      o.locales[xml_lang] = child
    end
  end

  return o
end


Style._default_options = {
  ["initialize-with-hyphen"] = true,
  ["page-range-format"] = nil,
  ["demote-non-dropping-particle"] = "display-and-sort",
}

function Style:set_lang(lang, force_lang)
  local default_locale = self:get_attribute("default-locale")
  if lang then
    if default_locale and not force_lang then
      self.lang = default_locale
    end
  else
    self.lang = default_locale or "en-US"
  end
end


local Info = Element:derive("info")


function Info:from_node(node)
  local o = Info:new()

  -- o.authors = nil
  -- o.contributors = nil
  o.categories = {}
  o.id = nil
  -- o.issn = nil
  -- o.eissn = nil
  -- o.issnl = nil
  o.links = {
    independent_parent = nil,
  }
  -- o.published = nil
  -- o.rights = nil
  -- o.summary = nil
  o.title = nil
  -- o.title_short = nil
  o.updated = nil

  for _, child in ipairs(node:get_children()) do
    if child:is_element() then
      local element_name = child:get_element_name()
      if element_name == "category" then
        local citation_format = child:get_attribute("citation-format")
        if citation_format then
          o.categories.citation_format = citation_format
        end

      elseif element_name == "id" then
        o.id = child:get_text()

      elseif element_name == "link" then
        local href = child:get_attribute("href")
        local rel = child:get_attribute("rel")
        if href and rel == "independent-parent" then
          o.links.independent_parent = href
        end

      elseif element_name == "title" then
        o.title = child:get_text()

      elseif element_name == "updated" then
        o.updated = child:get_text()

      end
    end
  end

  return o
end



style_module.Style = Style


return style_module

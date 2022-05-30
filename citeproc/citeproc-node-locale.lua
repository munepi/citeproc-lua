--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local locale = {}

local Element = require("citeproc-element").Element
local util = require("citeproc-util")


local Locale = Element:derive("locale")

function Locale:new()
  local o = Element:new()

  o.terms = {}
  o.dates = {}
  o.style_options = {}

  return o
end

function Locale:from_node(node)
  local o = Locale:new()
  o:process_children_nodes(node)

  for _, child in ipairs(o.children) do
    local element_name = child.element_name
    if element_name == "terms" then
      o.terms = child
    elseif element_name == "date" then
      o.dates[child.form] = child
    elseif element_name == "style-options" then
      local style_option = child
      o.style_options.limit_day_ordinals_to_day_1 = util.to_boolean(
        style_option:get_attribute("limit-day-ordinals-to-day-1")
      ) or false
      o.style_options.punctuation_in_quote = util.to_boolean(
        style_option:get_attribute("punctuation-in-quote")
      ) or false
    end
  end

  return o
end


function Locale:get_option(key)
  local query = string.format("style-options[%s]", key)
  local option = self:query_selector(query)[1]
  if option then
    local value = option:get_attribute(key)
      if self._option_type[key] == "integer" then
        value = tonumber(value)
      elseif self._option_type[key] == "boolean" then
        value = (value == "true")
      end
    return value
  else
    return nil
  end
end

function Locale:get_term (name, form, number, gender)

  if form == "long" then
    form = nil
  end

  local match_last
  local match_last_two
  local match_whole
  if number then
    assert(type(number) == "number")
    match_last = string.format("%s-%02d", name, number % 10)
    match_last_two = string.format("%s-%02d", name, number % 100)
    match_whole = string.format("%s-%02s", name, number)
  end

  local res = nil
  for _, term in ipairs(self:query_selector("term")) do
    -- Use get_path?
    local match_name = name

    if number then
      local term_match = term:get_attribute("last-two-digits")
      if term_match == "whole-number" then
        match_name = match_whole
      elseif term_match == "last-two-digits" then
        match_name = match_last_two
      elseif number < 10 then
        -- "13" can match only "ordinal-13" not "ordinal-03"
        -- It is sliced to "3" in a later checking pass.
        match_name = match_last_two
      else
        match_name = match_last
      end
    end

    local term_name = term:get_attribute("name")
    local term_form = term:get_attribute("form")
    if term_form == "long" then
      term_form = nil
    end
    local term_gender = term:get_attribute("gender-form")

    if term_name == match_name and term_form == form and term_gender == gender then
      return term
    end

  end

  -- Fallback
  if form == "verb-sort" then
    return self:get_term(name, "verb")
  elseif form == "symbol" then
    return self:get_term(name, "short")
  elseif form == "verb" then
    return self:get_term(name, "long")
  elseif form == "short" then
    return self:get_term(name, "long")
  end

  if number and number > 10 then
    return self:get_term(name, nil, number % 10, gender)
  end

  if gender then
    return self:get_term(name, nil, number, nil)
  end

  if number then
    return self:get_term(name, nil, nil, nil)
  end

  return nil
end


local Terms = Element:derive("terms")

function Terms:new(node)
  local o = Element:new()
  o.element_name = "terms"
  o.children = {}
  o.term_map = {}
  return o
end


function Terms:from_node(node)
  local o = Terms:new()
  o:process_children_nodes(node)
  for _, term in ipairs(o.children) do
    local form = term.form
    local gender_form = term.gender_form
    local match = term.match

    local key = term.name
    if form then
      key = key .. '/form-' .. form
    end
    if gender_form then
      key = key .. '/gender-' .. gender_form
    end
    if match then
      key = key .. '/match-' .. match
    end

    o.term_map[key] = term
  end
  return o
end


local Term = Element:derive("term")

function Term:from_node(node)
  local o = Term:new()

  if o.children then
    for _, child in ipairs(node:get_children()) do
      if child:is_element() then
        local element_name = child:get_element_name()
        if element_name == "single" then
          o.single = child:get_text()
          o.text = o.single
        elseif element_name == "multiple" then
          o.multiple = child:get_text()
        end
      end
    end
  else
    o.text = node:get_text()
  end

  return o
end


function Term:render (context, is_plural)
  self:debug_info(context)
  context = self:process_context(context)

  local output = {
    single = self:get_text(),
  }
  for _, child in ipairs(self:get_children()) do
    if child:is_element() then
      output[child:get_element_name()] = self:escape(child:get_text())
    end
  end
  local res = output.single
  if is_plural then
    if output.multiple then
      res = output.multiple
    end
  end
  if res == "" then
    return nil
  end
  return res
end


locale.Locale = Locale
locale.Term = Term

return locale

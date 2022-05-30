--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local names_module = {}

local unicode = require("unicode")

local IrNode = require("citeproc-ir-node").IrNode
local richtext = require("citeproc-richtext")
local Element = require("citeproc-element").Element
local util = require("citeproc-util")


-- [Name](https://docs.citationstyles.org/en/stable/specification.html#name)
local Name = Element:derive("name")

function Name:new(node)
  local o = Element:new("name")

  o.delimiter = ", "
  o.delimiter_precedes_et_al = "contextual"
  o.delimiter_precedes_last = "contextual"
  o.et_al_use_last = false
  o.form = "long"
  o.initialize = false
  o.sort_separator = false

  return o
end

function Name:from_node(node)
  local o = Name:new()
  o.and_ = node:get_attribute("and")
  o:get_delimiter_attribute(node)
  o.delimiter_precedes_et_al = node:get_attribute("delimiter-precedes-et-al")
  o.delimiter_precedes_last = node:get_attribute("delimiter-precedes-last")
  o.et_al_min = node:get_attribute("et-al-min")
  o.et_al_use_first = node:get_attribute("et-al-use-first")
  o.et_al_subsequent_min = node:get_attribute("et-al-subsequent-min")
  o.et_al_subsequent_use_first = node:get_attribute("et-al-subsequent-use-first")
  o.et_al_use_last = util.to_boolean(node:get_attribute("et-al-use-last"))
  o.form = node:get_attribute("form")
  o.initialize = util.to_boolean(node:get_attribute("initialize"))
  o.initialize_with = node:get_attribute("initialize-with")
  o.name_as_sort_order = node:get_attribute("name_as_sort_order")
  o.sort_separator = node:get_attribute("sort-separator")
  o:get_affixes_attributes(node)
  o:get_formatting_attributes(node)
  return o
end

function Name:build_ir(variable, et_al, label, engine, state, context)
  local name_variables = context:get_variable(variable)
  if not name_variables then
    return nil
  end

  local ir = IrNode:new("name")
  ir.children = {}

  for _, name_variable in ipairs(name_variables) do
    if name_variable.family then
      local text = name_variable.family
      if name_variable.given then
        text = text .. ", " .. name_variable.given
      end
      local child_ir = IrNode:new(nil, text)
      table.insert(ir.children, child_ir)
    elseif name_variable.literal then
      local child_ir = IrNode:new(nil, name_variable.literal)
      table.insert(ir.children, child_ir)
    end
  end

  ir = self:_apply_formatting(ir)
  ir = self:_apply_affixes(ir)
  return ir
end


Name._default_options = {
  ["delimiter"] = ", ",
  ["delimiter-precedes-et-al"] = "contextual",
  ["delimiter-precedes-last"] = "contextual",
  ["et-al-min"] = nil,
  ["et-al-use-first"] = nil,
  ["et-al-subsequent-min"] = nil,
  ["et-al-subsequent-use-first "] = nil,
  ["et-al-use-last"] = false,
  ["form"] = "long",
  ["initialize"] = true,
  ["initialize-with"] = false,
  ["name-as-sort-order"] = false,
  ["sort-separator"] = ", ",
  ["prefix"] = "",
  ["suffix"] = "",
}

function Name:render (names, context)
  self:debug_info(context)
  context = self:process_context(context)

  local and_ = context.options["and"]
  local delimiter = context.options["delimiter"]
  local delimiter_precedes_et_al = context.options["delimiter-precedes-et-al"]
  local delimiter_precedes_last = context.options["delimiter-precedes-last"]
  local et_al_min = context.options["et-al-min"]
  local et_al_use_first = context.options["et-al-use-first"]
  local et_al_subsequent_min = context.options["et-al-subsequent-min"]
  local et_al_subsequent_use_first = context.options["et-al-subsequent-use-first "]
  local et_al_use_last = context.options["et-al-use-last"]

  -- sorting
  if context.options["names-min"] then
    et_al_min = context.options["names-min"]
  end
  if context.options["names-use-first"] then
    et_al_use_first = context.options["names-use-first"]
  end
  if context.options["names-use-last"] ~= nil then
    et_al_use_last = context.options["names-use-last"]
  end

  local form = context.options["form"]

  local et_al_truncate = et_al_min and et_al_use_first and #names >= et_al_min
  local et_al_last = et_al_use_last and et_al_use_first <= et_al_min - 2

  if form == "count" then
    if et_al_truncate then
      return et_al_use_first
    else
      return #names
    end
  end

  local output = nil

  local res = nil
  local inverted = false

  for i, name in ipairs(names) do
    if et_al_truncate and i > et_al_use_first then
      if et_al_last then
        if i == #names then
          output = richtext.concat(output, delimiter)
          output = output .. util.unicode["horizontal ellipsis"]
          output = output .. " "
          res = self:render_single_name(name, i, context)
          output = output .. res
        end
      else
        if not self:_check_delimiter(delimiter_precedes_et_al, i, inverted) then
          delimiter = " "
        end
        if output then
          output = richtext.concat_list({output, context.et_al:render(context)}, delimiter)
        end
        break
      end
    else
      if i > 1 then
        if i == #names and context.options["and"] then
          if self:_check_delimiter(delimiter_precedes_last, i, inverted) then
            output = richtext.concat(output, delimiter)
          else
            output = output .. " "
          end
          local and_term = ""
          if context.options["and"] == "text" then
            and_term = self:get_term("and"):render(context)
          elseif context.options["and"] == "symbol" then
            and_term = self:escape("&")
          end
          output = output .. and_term .. " "
        else
          output = richtext.concat(output, delimiter)
        end
      end
      res, inverted = self:render_single_name(name, i, context)

      if res and res ~= "" then
        res = richtext.new(res)
        if context.build.first_rendered_names then
          table.insert(context.build.first_rendered_names, res)
        end

        if output then
          output = richtext.concat(output, res)
        else
          output = res
        end
      end
    end
  end

  local ret = self:format(output, context)
  ret = self:wrap(ret, context)
  return ret
end

function Name:_check_delimiter (delimiter_attribute, index, inverted)
  -- `delimiter-precedes-et-al` and `delimiter-precedes-last`
  if delimiter_attribute == "always" then
    return true
  elseif delimiter_attribute == "never" then
    return false
  elseif delimiter_attribute == "contextual" then
    if index > 2 then
      return true
    else
      return false
    end
  elseif delimiter_attribute == "after-inverted-name" then
    if inverted then
      return true
    else
      return false
    end
  end
  return false
end

function Name:render_single_name (name, index, context)
  local form = context.options["form"]
  local initialize = context.options["initialize"]
  local initialize_with = context.options["initialize-with"]
  local name_as_sort_order = context.options["name-as-sort-order"]
  if context.sorting then
    name_as_sort_order = "all"
  end
  local sort_separator = context.options["sort-separator"]

  local demote_non_dropping_particle = context.options["demote-non-dropping-particle"]

  -- TODO: make it a module
  local function _strip_quotes(str)
    if str then
      str = string.gsub(str, '"', "")
      str = string.gsub(str, "'", util.unicode["apostrophe"])
    end
    return str
  end

  local family = _strip_quotes(name["family"]) or ""
  local given = _strip_quotes(name["given"]) or ""
  local dp = _strip_quotes(name["dropping-particle"]) or ""
  local ndp = _strip_quotes(name["non-dropping-particle"]) or ""
  local suffix = _strip_quotes(name["suffix"]) or ""
  local literal = _strip_quotes(name["literal"]) or ""

  if family == "" then
    family = literal
    if family == "" then
      family = given
      given = ""
    end
    if family ~= "" then
      return family
    else
      error("Name not avaliable")
    end
  end

  if initialize_with then
    given = self:initialize_name(given, initialize_with, context)
  end

  local demote_ndp = false  -- only active when form == "long"
  if demote_non_dropping_particle == "display-and-sort" or
  demote_non_dropping_particle == "sort-only" and context.sorting then
    demote_ndp = true
  else  -- demote_non_dropping_particle == "never"
    demote_ndp = false
  end

  local family_name_part = nil
  local given_name_part = nil
  for _, child in ipairs(self:get_children()) do
    if child:is_element() and child:get_element_name() == "name-part" then
      local name_part = child:get_attribute("name")
      if name_part == "family" then
        family_name_part = child
      elseif name_part == "given" then
        given_name_part = child
      end
    end
  end

  local res = nil
  local inverted = false
  if form == "long" then
    local order
    local suffix_separator = sort_separator
    if not util.has_romanesque_char(name["family"]) then
      order = {family, given}
      inverted = true
      sort_separator = ""
    elseif name_as_sort_order == "all" or (name_as_sort_order == "first" and index == 1) then

      -- "Alan al-One"
      local hyphen_parts = util.split(family, "%-", 1)
      if #hyphen_parts > 1 then
        local particle
        particle, family = table.unpack(hyphen_parts)
        particle = particle .. "-"
        ndp = richtext.concat(ndp, particle)
      end

      if family_name_part then
        family = family_name_part:format_name_part(family, context)
        ndp = family_name_part:format_name_part(ndp, context)
      end
      if given_name_part then
        given = given_name_part:format_name_part(given, context)
        dp = family_name_part:format_name_part(dp, context)
      end

      if demote_ndp then
        given = richtext.concat_list({given, dp, ndp}, " ")
      else
        family = richtext.concat_list({ndp, family}, " ")
        given = richtext.concat_list({given, dp}, " ")
      end

      if family_name_part then
        family = family_name_part:wrap_name_part(family, context)
      end
      if given_name_part then
        given = given_name_part:wrap_name_part(given, context)
      end

      order = {family, given, suffix}
      inverted = true
    else
      if family_name_part then
        family = family_name_part:format_name_part(family, context)
        ndp = family_name_part:format_name_part(ndp, context)
      end
      if given_name_part then
        given = given_name_part:format_name_part(given, context)
        dp = family_name_part:format_name_part(dp, context)
      end

      family = richtext.concat_list({dp, ndp, family}, " ")
      if name["comma-suffix"] then
        suffix_separator = ", "
      else
        suffix_separator = " "
      end
      family = richtext.concat_list({family, suffix}, suffix_separator)

      if family_name_part then
        family = family_name_part:wrap_name_part(family, context)
      end
      if given_name_part then
        given = given_name_part:wrap_name_part(given, context)
      end

      order = {given, family}
      sort_separator = " "
    end
    res = richtext.concat_list(order, sort_separator)

  elseif form == "short" then
    if family_name_part then
      family = family_name_part:format_name_part(family, context)
      ndp = family_name_part:format_name_part(ndp, context)
    end
    family = util.concat({ndp, family}, " ")
      if family_name_part then
        family = family_name_part:wrap_name_part(family, context)
      end
    res = family
  else
    error(string.format('Invalid attribute form="%s" of "name".', form))
  end
  return res, inverted
end

function Name:initialize_name(given, terminator, context)
  if not given or given == "" then
    return ""
  end

  local initialize = context.options["initialize"]
  if context.options["initialize-with-hyphen"] == false then
    given = string.gsub(given, "-", " ")
  end

  -- Split the given name to name_list (e.g., {"John", "M." "E"})
  -- Compound names are splitted too but are marked in punc_list.
  local name_list = {}
  local punct_list = {}
  local last_position = 1
  for name, pos in string.gmatch(given, "([^-.%s]+[-.%s]+)()") do
    table.insert(name_list, string.match(name, "^[^-%s]+"))
    if string.match(name, "%-") then
      table.insert(punct_list, "-")
    else
      table.insert(punct_list, "")
    end
    last_position = pos
  end
  if last_position <= #given then
    table.insert(name_list, util.strip(string.sub(given, last_position)))
    table.insert(punct_list, "")
  end

  for i, name in ipairs(name_list) do
    local is_particle = false
    local is_abbreviation = false

    local first_letter = utf8.char(utf8.codepoint(name))
    if util.is_lower(first_letter) then
        is_particle = true
    elseif #name == 1 then
      is_abbreviation = true
    else
      local abbreviation = string.match(name, "^([^.]+)%.$")
      if abbreviation then
        is_abbreviation = true
        name = abbreviation
      end
    end

    if is_particle then
      name_list[i] = name .. " "
      if i > 1 and not string.match(name_list[i-1], "%s$") then
        name_list[i-1] = name_list[i-1] .. " "
      end
    elseif is_abbreviation then
      name_list[i] = name .. terminator
    else
      if initialize then
        if util.is_upper(name) then
          name = first_letter
        else
          -- Long abbreviation: "TSerendorjiin" -> "Ts."
          local abbreviation = ""
          for _, c in utf8.codes(name) do
            local char = utf8.char(c)
            local lower = unicode.utf8.lower(char)
            if lower == char then
              break
            end
            if abbreviation == "" then
              abbreviation = char
            else
              abbreviation = abbreviation .. lower
            end
          end
          name = abbreviation
        end
        name_list[i] = name .. terminator
      else
        name_list[i] = name .. " "
      end
    end

    -- Handle the compound names
    if i > 1 and punct_list[i-1] == "-" then
      if is_particle then  -- special case "Guo-ping"
        name_list[i] = ""
      else
        name_list[i-1] = util.rstrip(name_list[i-1])
        name_list[i] = "-" .. name_list[i]
      end
    end
  end

  local res = util.concat(name_list, "")
  res = util.strip(res)
  return res

end


-- [Name-part](https://docs.citationstyles.org/en/stable/specification.html#name-part-formatting)
local NamePart = Element:derive("name-part")

function NamePart:from_node(node)
  local o = NamePart:new()
  o.name = node:get_attribute("name")
  o:get_affixes_attributes(node)
  o:get_text_case_attribute(node)
  return o
end

function NamePart:format_name_part(name_part, context)
  context = self:process_context(context)
  local res = self:case(name_part, context)
  res = self:format(res, context)
  return res
end

function NamePart:wrap_name_part(name_part, context)
  context = self:process_context(context)
  local res = self:wrap(name_part, context)
  return res
end


-- [Et-al](https://docs.citationstyles.org/en/stable/specification.html#et-al)
local EtAl = Element:derive("et-al")

EtAl.term = "et-al"

function EtAl:from_node(node)
  local o = EtAl:new()
  o.term = node:get_attribute("term")
  o:get_formatting_attributes(node)
  return o
end

EtAl._default_options = {
  term = "et-al",
}

EtAl.render = function (self, context)
  self:debug_info(context)
  context = self:process_context(context)
  local res = self:get_term(context.options["term"]):render(context)
  res = self:format(res, context)
  return res
end


local Substitute = Element:derive("substitute")

function Substitute:render (item, context)
  self:debug_info(context)

  if context.suppressed_variables then
    -- true in layout, not in sort
    context.suppress_subsequent_variables = true
  end

  for i, child in ipairs(self:get_children()) do
    if child:is_element() then
      local result = child:render(item, context)
      if result and result ~= "" then
        return result
      end
    end
  end
  return nil
end


-- [Names](https://docs.citationstyles.org/en/stable/specification.html#names)
local Names = Element:derive("names")
Names.name = nil
Names.et_al = nil
Names.substitute = nil
Names.label = nil

function Names:from_node(node)
  local o = Names:new()
  o.variable = node:get_attribute("variable")
  o.name = nil
  o.et_al = nil
  o.substitute = nil
  o.label = nil
  o:get_delimiter_attribute(node)
  o:get_affixes_attributes(node)
  o:get_display_attribute(node)
  o:get_formatting_attributes(node)
  o:get_text_case_attribute(node)
  return o
end

function Names:process_children_nodes(node)
  for _, child in self.children do
    local element_name = child.element_name
    if element_name == "name" then
      self.name = child
    elseif element_name == "et-al" then
      self.et_al = child
    elseif element_name == "substitute" then
      self.substitute = child
    elseif element_name == "label" then
      self.label = child
      if self.name then
        child.after_name = true
      end
    else
      util.warning(string.format('Unkown element "{}".', element_name))
    end
  end
  if not self.name then
    self.name = Name:new()
  end
  if not self.et_al then
    self.name = EtAl:new()
  end
end

function Names:build_ir(engine, state, context)
  local ir = IrNode:new()
  ir.children = {}
  for _, variable in ipairs(util.split(self.variable)) do
    local name_ir = self.name:build_ir(variable, self.et_al, self.label, engine, state, context)
    table.insert(ir.children, name_ir)
  end
  ir = self:_apply_delimiter(ir)
  ir = self:_apply_formatting(ir)
  ir = self:_apply_affixes(ir)
  ir = self:_apply_display(ir)
  return ir
end


function Names:render (item, context)
  self:debug_info(context)
  context = self:process_context(context)

  local names_delimiter = context.options["names-delimiter"]
  if names_delimiter then
    context.options["delimiter"] = names_delimiter
  end

  -- Inherit attributes of parent `names` element
  local names_element = context.names_element
  if names_element then
    for key, value in pairs(names_element._attr) do
      context.options[key] = value
    end
    for key, value in pairs(self._attr) do
      context.options[key] = value
    end
  else
    context.names_element = self
    context.variable = context.options["variable"]
  end

  local name, et_al, label
  -- The position of cs:label relative to cs:name determines the order of
  -- the name and label in the rendered text.
  local label_position = nil
  for _, child in ipairs(self:get_children()) do
    if child:is_element() then
      local element_name = child:get_element_name()
      if element_name == "name" then
        name = child
        if label then
          label_position = "before"
        end
      elseif element_name == "et-al" then
        et_al = child
      elseif element_name == "label" then
        label = child
        if name then
          label_position = "after"
        end
      end
    end
  end
  if label_position then
    context.label_position = label_position
  else
    label_position = context.label_position or "after"
  end

  -- local name = self:get_child("name")
  if not name then
    name = context.name_element
  end
  if not name then
    name = self:create_element("name", {}, self)
    Name:set_base_class(name)
  end
  context.name_element = name

  -- local et_al = self:get_child("et-al")
  if not et_al then
    et_al = context.et_al
  end
  if not et_al then
    et_al = self:create_element("et-al", {}, self)
    EtAl:set_base_class(et_al)
  end
  context.et_al = et_al

  -- local label = self:get_child("label")
  if label then
    context.label = label
  else
    label = context.label
  end

  local sub_str = nil
  if context.mode == "bibliography" and not context.sorting then
    sub_str = context.options["subsequent-author-substitute"]
  --   if sub_str and #context.build.preceding_first_rendered_names == 0 then
  --     context.rendered_names = {}
  --   else
  --     sub_str = nil
  --     context.rendered_names = nil
  --   end
  end

  local variable_names = context.options["variable"] or context.variable
  local ret = nil

  if variable_names then
    local output = {}
    local num_names = 0
    for _, role in ipairs(util.split(variable_names)) do
      local names = self:get_variable(item, role, context)

      table.insert(context.variable_attempt, names ~= nil)

      if names then
        local res = name:render(names, context)
        if res then
          if type(res) == "number" then  -- name[form="count"]
            num_names = num_names + res
          elseif label and not context.sorting then
            -- drop name label in sorting
            local label_result = label:render(role, context)
            if label_result then
              if label_position == "before" then
                res = richtext.concat(label_result, res)
              else
                res = richtext.concat(res, label_result)
              end
            end
          end
        end
        table.insert(output, res)
      end
    end

    if num_names > 0 then
      ret = tostring(num_names)
    else
      ret = self:concat(output, context)
      if ret and sub_str and context.build.first_rendered_names then
        ret = self:substitute_names(ret, context)
      end
    end
  end

  if ret then
    ret = self:format(ret, context)
    ret = self:wrap(ret, context)
    ret = self:display(ret, context)
    return ret
  else
    local substitute = self:get_child("substitute")
    if substitute then
      ret = substitute:render(item, context)
    end
    if ret and sub_str then
      ret = self:substitute_single_field(ret, context)
    end
    return ret
  end
end

function Names:substitute_single_field(result, context)
  if not result then
    return nil
  end
  if context.build.first_rendered_names and #context.build.first_rendered_names == 0 then
    context.build.first_rendered_names[1] = result
  end
  result = self:substitute_names(result, context)
  return result
end

function Names:substitute_names(result, context)
  if not context.build.first_rendered_names then
     return result
  end
  local name_strings = {}
  local match_all

  if #context.build.first_rendered_names > 0 then
    match_all = true
  else
    match_all = false
  end
  for i, text in ipairs(context.build.first_rendered_names) do
    local str = text:render(context.engine.formatter, context)
    name_strings[i] = str
    if context.build.preceding_first_rendered_names and str ~= context.build.preceding_first_rendered_names[i] then
      match_all = false
    end
  end

  if context.build.preceding_first_rendered_names then
    local sub_str = context.options["subsequent-author-substitute"]
    local sub_rule = context.options["subsequent-author-substitute-rule"]

    if sub_rule == "complete-all" then
      if match_all then
        if sub_str == "" then
          result = nil
        else
          result.contents = {sub_str}
        end
      end

    elseif sub_rule == "complete-each" then
      -- In-place substitution
      if match_all then
        for _, text in ipairs(context.build.first_rendered_names) do
          text.contents = {sub_str}
        end
        result = self:concat(context.build.first_rendered_names, context)
      end

    elseif sub_rule == "partial-each" then
      for i, text in ipairs(context.build.first_rendered_names) do
        if name_strings[i] == context.build.preceding_first_rendered_names[i] then
          text.contents = {sub_str}
        else
          break
        end
      end
      result = self:concat(context.build.first_rendered_names, context)

    elseif sub_rule == "partial-first" then
      if name_strings[1] == context.build.preceding_first_rendered_names[1] then
        context.build.first_rendered_names[1].contents = {sub_str}
      end
      result = self:concat(context.build.first_rendered_names, context)
    end
  end

  if #context.build.first_rendered_names > 0 then
    context.build.first_rendered_names = nil
  end
  context.build.preceding_first_rendered_names = name_strings
  return result
end

names_module.Names = Names
names_module.Name = Name
names_module.NamePart = NamePart
names_module.EtAl = EtAl
names_module.Substitute = Substitute

return names_module

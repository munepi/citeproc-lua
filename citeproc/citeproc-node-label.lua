--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local label = {}

local Element = require("citeproc-element").Element
local IrNode = require("citeproc-ir-node").IrNode
local util = require("citeproc-util")


-- [Label](https://docs.citationstyles.org/en/stable/specification.html#label)
local Label = Element:derive("label")

Label.form = "long"
Label.plural = "contextual"

function Label:from_node(node)
  local o = Label:new()
  o.variable = node:get_attribute("variable")
  o.form = node:get_attribute("form") or "long"
  o.plural = node:get_attribute("plural") or "contextual"
  o:get_affixes_attributes(node)
  o:get_formatting_attributes(node)
  o:get_text_case_attribute(node)
  o:get_strip_periods_attribute(node)
  return o
end

function Label:build_ir(engine, state, context)
  -- local variable = context:get_variable(self.variable, self.form)

  local is_plural = false
  if self.plural == "always" then
    is_plural = true
  elseif self.plural == "never" then
    is_plural = false
  elseif self.plural == "contextual" then
    is_plural = self:_is_variable_plural(self.variable)
  end

  local text = context:get_term(self.term, self.form, is_plural)
  if not text then
    return nil
  end

  text = self._apply_strip_periods(text)
  text = self._apply_text_case(text)

  local ir = IrNode:new("label", text)
  ir = self:_apply_formatting(ir)
  ir = self:_apply_affixes(ir)
  return ir
end

function Label:_is_variable_plural(variable, context)
  local value = context:get_variable(self.variable)
  if not value then
    return false
  end
  -- TODO
  return false
end

function Label:render (item, context)
  self:debug_info(context)
  context = self:process_context(context)

  local variable_name
  if context.names_element then
    -- The `variable` attribute of names may hold multiple roles.
    -- Each of them may call `Label:render()` to render the term.
    -- When used in `names` element, the role name is the first argument
    -- and the item is accessed via `context.item`.
    -- Bad design
    -- TODO: Redesign the arguments of render()
    variable_name = item
  else
    variable_name = context.options["variable"]
  end

  local form = context.options["form"]
  local plural = context.options["plural"] or "contextual"

  if not context.names_element then
    local variable_type = util.variable_types[variable_name]
    -- variable must be or one of the number variables.
    if variable_type ~= "number" then
      return nil
    end
    -- The term is only rendered if the selected variable is non-empty
    local variable = item[variable_name]
    if not variable then
      return nil
    end
    if type(variable) == "string" then
      if not (string.match(variable, "^%d") or util.is_numeric(variable)) then
        return nil
      end
    end
  end

  local term
  if variable_name == "locator" then
    local locator_type = item.label or "page"
    term = self:get_term(locator_type, form)
  else
    term = self:get_term(variable_name, form)
  end

  local res = nil
  if term then
    if plural == "contextual" and self:_is_plural(variable_name, context) or plural == "always" then
      res = term:render(context, true)
    else
      res = term:render(context, false)
    end

    res = self:apply_strip_periods(res, context)
    res = self:case(res, context)
    res = self:format(res, context)
    res = self:wrap(res, context)
  end
  return res
end

function Label:_is_plural (variable_name, context)
  local variable_type = util.variable_types[variable_name]
  -- Don't use self:get_variable here
  local variable = context.item[variable_name]
  local res = false
  if variable_type == "name" then
    -- Label inside `names`
    res = #variable > 1

  elseif variable_type == "number" then
    if util.startswith(variable_name, "number-of-") then
      res = tonumber(variable) > 1
    else
      variable = tostring(variable)
      variable = string.gsub(variable, "\\%-", "")
      if #util.split(variable, "%s*[,&-]%s*") > 1 then
        -- check if contains multiple numbers
        -- "i–ix": true
        -- res = string.match(tostring(variable), "%d+%D+%d+") ~= nil
        res = true
      elseif string.match(variable, "%Aand%A") or string.match(variable, "%Aet%A") then
        res = true
      else
        res = false
      end
    end
  else
    util.warning("Invalid attribute \"variable\".")
  end
  return res
end


label.Label = Label

return label

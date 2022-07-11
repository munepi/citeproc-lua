--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local irnode = {}

local util = require("citeproc-util")


local IrNode = {
  _element = nil,
  _type = "IrNode",
  _base_class = "IrNode",
  text = nil,
  formatting = nil,
  affixes = nil,
  children = nil,
  delimiter = nil,
}

function IrNode:new(children, element)
  local o = {
    _element = element.element_name,
    _type = self._type,
    children = children,
    group_var = "plain",
  }

  o.group_var = "missing"
  for _, child_ir in ipairs(children) do
    if child_ir.group_var == "important" then
      o.group_var = "important"
      break
    elseif child_ir.group_var == "plain" then
      o.group_var = "plain"
    end
  end

  o.person_name_irs = {}
  if children then
    for _, child in ipairs(children) do
      if child.person_name_irs then
        util.extend(o.person_name_irs, child.person_name_irs)
      end
    end
  end

  setmetatable(o, self)
  self.__index = self
  return o
end

function IrNode:derive(type)
  local o = {
    _type = type,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function IrNode:flatten(format)
  if self.group_var == "missing" then
    return {}
  end
  local inlines
  if self._type == "SeqIr" or self._type == "NameIr" then
    inlines = self:flatten_seq(format)
  else
    inlines = format:affixed_quoted(self.inlines, self.affixes, self.quotes);
    inlines = format:with_display(inlines, self.display);
  end
  return inlines
end

function IrNode:flatten_seq(format)
  local inlines_list = {}
  if not self.children then
    print(debug.traceback())
  end
  for _, child in ipairs(self.children) do
    if child.group_var ~= "missing" then
      if not child.flatten then
        print(debug.traceback())
        util.debug(child)
      end
      table.insert(inlines_list, child:flatten(format))
    end
  end

  local inlines = format:group(inlines_list, self.delimiter, self.formatting)
  -- assert self.quotes == localized quotes
  inlines = format:affixed_quoted(inlines, self.affixes, self.quotes);
  inlines = format:with_display(inlines, self.display);
  return inlines
end

function IrNode:capitalize_first_term()
  -- util.debug(self)
  if self._type == "Rendered" and self.element and (self.element.term == "ibid" or self.element.term == "and") then
    self.inlines[1]:capitalize_first_term()
  elseif self._type == "SeqIr" and self.children[1] then
    self.children[1]:capitalize_first_term()
  end
end



local Rendered = IrNode:derive("Rendered")

function Rendered:new(inlines, element)
  local o = {
    _element = element.element_name,
    _type = self._type,
    element = element,  -- required for capitalizing first term
    inlines = inlines,
    group_var = "plain",
  }

  setmetatable(o, self)
  self.__index = self
  return o
end


local YearSuffix = IrNode:derive("YearSuffix")

function YearSuffix:new(inlines, element)
  local o = {
    _element = element.element_name,
    _type = self._type,
    element = element,
    inlines = inlines,
    group_var = "plain",
  }

  setmetatable(o, self)
  self.__index = self
  return o
end


local NameIr = IrNode:derive("NameIr")


local PersonNameIr = IrNode:derive("PersonNameIr")

function PersonNameIr:new(inlines, element)
  local o = {
    _element = element.element_name,
    _type = self._type,
    inlines = inlines,
    group_var = "plain",
  }
  setmetatable(o, self)
  self.__index = self
  return o
end


local SeqIr = IrNode:derive("SeqIr")

-- function SeqIr:new(children)
--   o = IrNode.new(self, children)
--   local o = {
--     children = children,
--     group_var = "plain",
--   }
--   setmetatable(o, self)
--   self.__index = self
--   return o
-- end



irnode.IrNode = IrNode
irnode.Rendered = Rendered
irnode.YearSuffix = YearSuffix
irnode.NameIr = NameIr
irnode.PersonNameIr = PersonNameIr
irnode.SeqIr = SeqIr

return irnode

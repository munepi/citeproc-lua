--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local layout = {}

local Element = require("citeproc-element").Element
local SeqIr = require("citeproc-ir-node").SeqIr
local util = require("citeproc-util")


local Layout = Element:derive("layout")

function Layout:from_node(node)
  local o = Layout:new()
  o:set_affixes_attributes(node)
  o:set_formatting_attributes(node)
  o:get_delimiter_attribute(node)

  o:process_children_nodes(node)

  return o
end

function Layout:build_ir(engine, state, context)
  local ir = self:build_children_ir(engine, state, context)
  if not ir then
    return nil
  end
  if context.in_bibliography then
    ir.delimiter = self.delimiter

    -- Move affixes of `bibliography > layout` into the right-inline element
    -- bugreports_SmallCapsEscape.txt
    local has_right_inline = false
    if self.affixes or self.formatting then
      for i, child_ir in ipairs(ir.children) do
        if child_ir.display == "right-inline" then
          has_right_inline = true
          local right_inline_with_affixes = SeqIr:new({child_ir}, self)
          right_inline_with_affixes.affixes = util.clone(self.affixes)
          right_inline_with_affixes.formatting = util.clone(self.formatting)
          child_ir.display = nil
          right_inline_with_affixes.display = "right-inline"
          ir.children[i] = right_inline_with_affixes
          break
        end
      end
    end

    if not has_right_inline then
      ir.affixes = util.clone(self.affixes)
      ir.formatting = util.clone(self.formatting)
    end
  end
  return ir
end


layout.Layout = Layout

return layout

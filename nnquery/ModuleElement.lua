local classic = require 'classic'

local nnquery = require 'nnquery'

--[[
Abstract class that adds manual parent tracking to `Element`.
To be used by `nn.Module`'s, with extra functionality added for
returning children. See also `ChildlessElement` for modules with
no children.
]]
local MPE, super = classic.class(..., nnquery.Element)

function MPE:_init(...)
  super._init(self, ...)
  self._parents = {}
end

--[[
Returns an `ElementList` for parents of this element.
Parents must be specified by `:add_parent()`.
]]
function MPE:parents()
  return nnquery.ElementList.fromtable(self._parents)
end

--[[
Sets parent, intended to be used by `ContainerElement` only.
]]
function MPE:_set_parents(parents)
  self._parents = parents
end

return MPE

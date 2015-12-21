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
Adds a parent, intended to be used by `ContainerElement` and the like.
]]
function MPE:add_parent(elem)
  if not elem:class():isSubclassOf(nnquery.Element) then
    error('added parent must be (subclass of) Element')
  end
  table.insert(self._parents, elem)
end

return MPE

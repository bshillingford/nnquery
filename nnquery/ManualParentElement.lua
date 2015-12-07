local classic = require 'classic'

local ElementList = require 'nnquery.ElementList'
local Element = require 'nnquery.Element'
local Context = require 'nnquery.Context'

--[[
Abstract class that adds manual parent tracking to `Element`.
]]
local MPE = classic.class(..., Element)

--[[
Returns an `ElementList` for parents of this element.
Parents must be specified by `:add_parent()`.
]]
function MPE:parents()
  return ElementList.fromtable(self._parents)
end

--[[
Adds a parent, intended to be used by `ContainerElement` and the like.
]]
function MPE:add_parent(elem)
  if not elem:class():isSubclassOf(Element) then
    error('added parent must be (subclass of) Element')
  end
  table.insert(self._parents, elem)
end

return MPE

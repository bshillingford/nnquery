local classic = require 'classic'

local ElementList = require 'nnquery.ElementList'
local ManualParentElement = require 'nnquery.ManualParentElement'
local Context = require 'nnquery.Context'

--[[
Concrete class with no children, using manually added parents.

Note: `:parents()` already impl'd by `ManualParentElement`; this just makes
`:children()` return an empty `ElementList`.
]]
local ChildlessElement = classic.class("ChildlessElement", ManualParentElement)

--[[
Returns children, in this case empty `ElementList`.
]]
function ChildlessElement:children()
  return ElementList.create_empty()
end

return ChildlessElement

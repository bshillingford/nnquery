local classic = require 'classic'

local nnquery = require 'nnquery'

--[[
Concrete class with no children, using manually added parents.

Note: `:parents()` already impl'd by `ModuleElement`; this just makes
`:children()` return an empty `ElementList`.
]]
local ChildlessElement, super = classic.class(..., nnquery.ModuleElement)

--[[
Returns children, in this case empty `ElementList`.
]]
function ChildlessElement:children()
  return nnquery.ElementList.create_empty()
end

return ChildlessElement

local classic = require 'classic'

require 'nngraph'
local nnquery = require 'nnquery'

--[[
`Element` for an nngraph node (`nngraph.Node`).
]]
local NE, super = classic.class(..., nnquery.Element)

function NE:_init()
  self._parents = {}
end

function NE:_add_parent(e)
  table.insert(self._parents, e)
end

--[[
Returns an `ElementList` for parent nngraph nodes of this element.
]]
function NE:parents()
  return nnquery.ElementList.fromtable(self._parents)
end

--[[
Returns an `ElementList` for children nngraph nodes of this element.
]]
function NE:children()
  local childelems = self._ctx:wrapall(self:val().children)
  for _, child in ipairs(childelems) do
    assert(child:class() == NE)
    child:_add_parent(self)
  end
  return childelems
end

function NE.static.isNode(m)
  return torch.isTypeOf(m, nngraph.Node)
end

return NE

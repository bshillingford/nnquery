local classic = require 'classic'

require 'nngraph'
local nnquery = require 'nnquery'

--[[
`nn.gModule` element. Children are input node(s).
]]
local NNGGME, super = classic.class(..., nnquery.ModuleElement)

--[[
Returns `ElementList` consisting of input nodes.
]]
function NNGGME:children()
  -- Root is always a single node, and root's children is a split/identity node
  local rootelem = self._ctx:wrapall(self:val().innode.children)
  assert(#rootelem == 1)
  rootelem[1]:_add_parent(self)
  return nnquery.ElementList.fromtable(rootelem)
end

function NNGGME.static.isGmodule(m)
  return torch.isTypeOf(m, nn.gModule)
end

return NNGGME

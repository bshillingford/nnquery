local classic = require 'classic'

local nnquery = require 'nnquery'

--[[
`nn.gModule` element. Children are input node(s).
]]
local NNGGME, super = classic.class(..., nnquery.ModuleElement)

--[[
Returns `ElementList` consisting of input nodes of module's forward graph.
]]
function NNGGME:children()
  return self:inputs()
end

--[[
Returns `ElementList` consisting of modules in graph, in the order that
nngraph evaluates them on a forwards pass.
]]
function NNGGME:modules()
  local mods = {}
  for _, node in ipairs(self:val().forwardnodes) do
    if node.data.module then
      table.insert(mods, node.data.module)
    end
  end

  local wrappeds = self._ctx:wrapall(mods)
  for _, wrapped in ipairs(wrappeds) do
    wrapped:add_parent(self)
  end
  return nnquery.ElementList.fromtable(wrappeds)
end

--[[
Returns `ElementList` consisting of input nodes of module's **forward graph**.
]]
function NNGGME:inputs()
  -- Find root node first
  local mod = self:val()
  local nInputs = mod.nInputs or #mod.innode.children
  local node = mod.innode
  if nInputs ~= #node.children then
    assert(#node.children == 1, "expected single child root nngraph node")
    node = node.children[1]
  end
  assert(nInputs == #node.children, "at this point, # children should equal # nngraph inputs")

  -- Sort children if needed:
  local innodes = node.children
  if innodes[1].data.selectindex and #innodes > 1 then
    table.sort(innodes, function(x, y)
      assert(x.data.selectindex and y.data.selectindex, "selectindex should exist for all nodes")
      return x.data.selectindex < y.data.selectindex
    end)
  end

  -- Wrap in elements and create element list as usual
  local inputs = self._ctx:wrapall(innodes)
  for _, input in ipairs(inputs) do
    input:_add_parent(self)
  end
  return nnquery.ElementList.fromtable(inputs)
end

--[[
Returns `ElementList` consisting of output nodes of module's **forward graph**.
]]
function NNGGME:outputs()
  error('not yet implemented')
end

function NNGGME.static.isGmodule(m)
  -- require in here so that the default context can be constructed without nngraph installed
  require 'nngraph'
  return torch.isTypeOf(m, nn.gModule)
end

return NNGGME

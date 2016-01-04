local classic = require 'classic'

local nnquery = require 'nnquery'

--[[
`nn.gModule` element. Children are input node(s).
]]
local NNGGME, super = classic.class(..., nnquery.ModuleElement)

function NNGGME:_init(...)
  super._init(self, ...)

  -- Find root node first
  local mod = self:val()
  local nInputs = mod.nInputs or #mod.innode.children
  local node = mod.innode
  if nInputs ~= #node.children then
    assert(#node.children == 1, "expected single child root nngraph node")
    node = node.children[1]
  end
  assert(nInputs == #node.children, "at this point, # children should equal # nngraph inputs")
  self._root = node

  -- Sort children if needed:
  local innodes = node.children
  if innodes[1].data.selectindex and #innodes > 1 then
    table.sort(innodes, function(x, y)
      assert(x.data.selectindex and y.data.selectindex, "selectindex should exist for all nodes")
      return x.data.selectindex < y.data.selectindex
    end)
  end
  self._innodes = innodes

  -- Pre-build Elements for nodes and mapping of fg node -> Element
  self._node2el = {}
  -- Wrap all nodes and set their gModule references:
  for _, node in ipairs(mod.fg.nodes) do
    -- this is the only place we should ever wrap a node using ctx
    local el = self._ctx:wrap(node)
    el:_set_gmod(mod, self)
    self._node2el[node] = el
  end

  -- Initialize the parents of all the nodes, now that _node2el is ready:
  for node, el in pairs(self._node2el) do
    el:_init_parents(mod, self)
  end
  -- Override parent of inputs to be this gmodule element:
  for _, innode in ipairs(innodes) do
    self._node2el[innode]._parents = {self}
  end
end

-- not the version in ctx: this uses the cached elements in the GModule element
function NNGGME:_wrap(x)
  return assert(self._node2el[x], 'internal error: node not found')
end

function NNGGME:_wrapall(tbl)
  local result = {}
  for k, v in ipairs(tbl) do
    result[k] = self:_wrap(v)
  end
  return result
end

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

  return nnquery.ElementList.fromtable(self:_wrapall(mods))
end

--[[
Returns `ElementList` consisting of input nodes of module's **forward graph**.
]]
function NNGGME:inputs()
  return nnquery.ElementList.fromtable(self:_wrapall(self._innodes))
end

--[[
Returns `ElementList` consisting of output nodes of module's **forward graph**.
]]
function NNGGME:outputs()
  local mod = self:val()
  local leaves = mod.fg:leaves()
  assert(#leaves == 1, "gmodule forward graph should have a single leaf")
  local leaf = leaves[1]

  -- Get node objects in order of output:
  local outnodes = {}
  for _, mi in ipairs(leaf.data.mapindex) do
    table.insert(outnodes, mod.fg.nodes[mi.forwardNodeId])
  end

  return nnquery.ElementList.fromtable(self:_wrapall(outnodes))
end

function NNGGME.static.isGmodule(m)
  -- require in here so that the default context can be constructed without nngraph installed
  require 'nngraph'
  return torch.isTypeOf(m, nn.gModule)
end

return NNGGME

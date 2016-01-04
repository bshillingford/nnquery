local classic = require 'classic'

local nnquery = require 'nnquery'

--[[
`Element` for an nngraph node (`nngraph.Node`).
]]
local NE, super = classic.class(..., nnquery.Element)

function NE:_init(...)
  super._init(self, ...)
end

function NE:_set_gmod(gmod, gmod_el)
  assert(not self._gmod and not self._gmod_el)
  self._gmod = gmod
  self._gmod_el = gmod_el
end

function NE:_init_parents()
  assert(self._gmod and self._gmod_el, "internal error: don't wrap a gmodule node directly")

  -- Find all the parents:
  self._parents = {}
  for i, mi in ipairs(self:val().data.mapindex) do
    self._parents[i] = self._gmod_el:_wrap(self._gmod.fg.nodes[mi.forwardNodeId])
  end
end

--[[
Alias for `:val().data.module`.
]]
function NE:module()
  return self:val().data.module
end

--[[
Alias for `:val().data.annotations.name`.
]]
function NE:name()
  return self:val().data.annotations.name
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
  local childelems = self._gmod_el:_wrapall(self:val().children)
  for _, child in ipairs(childelems) do
    -- at this point, should have all parents set by the ctor, incl ourself
    assert(child:classIs(NE), 'All wrappers for nodes should be NodeElements')
  end
  return nnquery.ElementList.fromtable(childelems)
end

function NE:__tostring()
  local val = self:val()
  local prints = {}
  for _, key in ipairs{'module', 'nSplitOutputs'} do
    if val.data[key] then
      table.insert(prints, string.format('d.%s=%s', key, tostring(val.data[key])))
    end
  end
  if val.data.annotations then
    for k, v in pairs(val.data.annotations) do
      table.insert(prints, string.format('d.a.%s=%s', k, v))
    end
  end
  return string.format('%s[%s]', 
                       self:class():name(),
                       table.concat(prints, ', '))
end

function NE.static.isNode(m)
  -- require in here so that the default context can be constructed without nngraph installed
  require 'nngraph'
  return torch.isTypeOf(m, nngraph.Node)
end

return NE

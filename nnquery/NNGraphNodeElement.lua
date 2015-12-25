local classic = require 'classic'

local nnquery = require 'nnquery'

--[[
`Element` for an nngraph node (`nngraph.Node`).
]]
local NE, super = classic.class(..., nnquery.Element)

function NE:_init(...)
  super._init(self, ...)
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
    assert(child:classIs(NE))
    child:_add_parent(self)
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

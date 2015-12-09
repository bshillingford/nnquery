local torch = require 'torch'
local classic = require 'classic'
local nn = require 'nn'

local nnquery = require 'nnquery'

local ContainerElement, super = classic.class(..., nnquery.ManualParentElement)

function ContainerElement:children()
  local wrappeds = self._ctx:wrapall(self._val.modules)
  for _, wrapped in ipairs(wrappeds) do
    wrapped:add_parent(self)
  end
  return nnquery.ElementList.fromtable(wrappeds)
end

function ContainerElement.static.isContainer(m)
  return torch.isTypeOf(m, nn.Container)
end

return ContainerElement

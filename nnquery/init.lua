local classic = require 'classic'

local M = classic.module(...)

M:class('Context')

M:class('Element')
M:class('ChildlessElement')
M:class('ContainerElement')
M:class('ModuleElement')
M:class('NNGraphGModuleElement')
M:class('NNGraphNodeElement')

M:class('ElementList')

-- TODO: maybe lightweight hierarchy (via classic) for exceptions, instead of string errors.

-- Create a default context with some good default settings:
local ctx = M.Context()
ctx:reg(M.NNGraphGModuleElement, M.NNGraphGModuleElement.isGmodule)
ctx:reg(M.NNGraphNodeElement, M.NNGraphNodeElement.isNode)
ctx:reg(M.ContainerElement, M.ContainerElement.isContainer) -- after since gModule IS_A Container
ctx:default(M.ChildlessElement)
M.default = ctx

-- Copy the classic module metatable, and forward __call to default ctx
local mt = {}
for k,v in pairs(getmetatable(M)) do mt[k] = v end
setmetatable(M, mt)

mt.__call = function(M, ...) return M.default(...) end

return M


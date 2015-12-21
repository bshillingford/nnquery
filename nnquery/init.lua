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

return M


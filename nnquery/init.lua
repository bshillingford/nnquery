local classic = require 'classic'

local M = classic.module(...)

M:class('Context')

M:class('Element')
M:class('ChildlessElement')
M:class('ContainerElement')
M:class('ManualParentElement')

M:class('ElementList')

-- TODO: impl/test Element etc for nn.Container, then add querying
-- TODO: lightweight hierarchy (via classic) for exceptions, instead of string errors.

return M


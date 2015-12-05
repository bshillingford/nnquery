local classic = require 'classic'

local M = classic.module(...)
M:class('Element')
M:class('ElementList')

-- TODO: impl/test Element etc for nn.Container, then add querying

return M


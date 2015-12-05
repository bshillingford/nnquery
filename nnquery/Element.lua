local classic = require 'classic'

--[[
Abstract base class for all elements. Provides an interface for search and 
querying, though their implementations are elsewhere.

Note a few design differences from languages such as XPath.

  1. Modules are best described as a DAG rather than a tree. Hence, there can the multiple 
     parents (i.e. inputs) rather than just one.
  2. Since the API is OOP rather than XPath or the CSS query selection language, operations
     such as `//SomeTag[position() mod 2 = 0]` are implemented as calls to an `ElementList`.

The API is inspired by a mix of XPath and .NET's LINQ.
]]
local Element = classic.class(...)

function Element:_init()
end

--[[
Returns an `ElementList` for children of this element.

Pure virtual method; must be implemented by the concrete `Element`.
]]
Element:mustHave('children')

--[[
Returns an `ElementList` for parents of this element.
Note that an element can have more than one parent, such as the input nodes to
an nngraph node. The precise definition of "parent" is implementation-dependent.

Pure virtual method; must be implemented by the concrete `Element`.
]]
Element:mustHave('parents')

--[[
Returns an `ElementList` for following siblings of this element.
]]
-- TODO

--[[
Returns an `ElementList` for preceding siblings of this element, where
the first sibling is the one immediately preceding this element and subsequent
siblings are further away.
]]
-- TODO


local classic = require 'classic'

local nnquery = require 'nnquery'

--[[
Abstract base class for all elements.
Provides an interface and various common functionality for search and querying.

Note a few notable design features and/or differences from XPath and CSS queries.

  1. Modules are best described as a DAG rather than a tree. Hence, there can the multiple 
     parents (i.e. inputs) rather than just one.
  2. Since the API is OOP rather than XPath or the CSS query selection language, operations
     such as `//SomeTag[position() mod 2 = 0]` are implemented as calls to an `ElementList`.
  3. There is no true "root" node, unlike an XML/HTML document; the root is simply the place
     where the query begins. Therefore, one cannot search for the root's parents, even if
     the root module is contained in another context.

The API is inspired in part by XPath and .NET's LINQ.
]]
local Element = classic.class(...)

--[[
Constructor called by the execution context. Can be overridden.
Argument `ctx` is a `Context` instance, and `val` specifies the 
contents of this element; usually an nn module.
]]
function Element:_init(ctx, val)
  assert(ctx and ctx:classIs(nnquery.Context), 'a Context ctx must be given')
  assert(val, 'val must be given')
  self._ctx = ctx
  self._val = val
end

--[[
Returns the object that this `Element` wraps.
]]
function Element:val()
  return self._val
end

--[[
Returns true if the `Element` instances refer to the same element.

Defaults to comparing (by reference) `val` property, but can be overridden.
]]
function Element:equals(other)
  return self._val == other._val
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
Alias for `:parents():only()`.
]]
function Element:parent()
  return self:parents():only()
end
Element:final('parent')

--[[
Alias for `:children():nth()`.
]]
function Element:nth_child(...)
  return self:children():nth(...)
end
Element:final('nth_child')

--[[
Alias for `:children():first()`.
]]
function Element:first_child()
  return self:children():first()
end
Element:final('first_child')

--[[
Alias for `:children():last()`.
]]
function Element:last_child()
  return self:children():last()
end
Element:final('last_child')

--[[
Returns an `ElementList` for following siblings of this element.

Raises an error if this element has multiple parents.
]]
function Element:following_siblings()
  local parents = self:parents():totable()
  if #parents ~= 1 then
    error('finds siblings only for elements with precisely one parent')
  end
  local all_siblings = parents[1]:children()
  -- after is exclusive, which is what we want
  return all_siblings:after(function(el)
    return el:equals(self)
  end)
end
Element:final('following_siblings')

--[[
Returns an `ElementList` for preceding siblings of this element, where
the first sibling is first child of the parent, and subsequent elements
are progressively closer, where the last is the immediately preceding
element.
]]
function Element:preceding_siblings()
  local parents = self:parents():totable()
  if #parents ~= 1 then
    error('finds siblings only for elements with precisely one parent')
  end
  local all_siblings = parents[1]:children()
  -- before is exclusive, which is what we want
  return all_siblings:before(function(el)
    return el:equals(self)
  end)
end
Element:final('preceding_siblings')

--[[
Returns an `ElementList` of all descendants.
]]
function Element:descendants()
  local descs = {}
  self:dfs(function(el) table.insert(descs, el) end)
  return nnquery.ElementList.fromtable(descs)
end

--[[
Returns an `ElementList` of all ancestors.
]]
function Element:ancestors()
  local descs = {}
  self:dfs(function(el) table.insert(descs, el) end, 'parents')
  return nnquery.ElementList.fromtable(descs)
end

--[[
Recurses down the DAG below this `Element` in DFS order, calling the callback 
at each `Element`. Note that DFS order is not unique, both due to ordering of
children and the structure being a DAG rather than a tree.

If `children_func_name` is set to `parents`, performs a DFS with the graph's
edges flipped. Defaults to `children`, i.e. a normal DFS.
]]
function Element:dfs(func_visit, children_func_name)
  children_func_name = children_func_name or 'children'
  local visited_table = {}
  local function traverse(el)
    for child in el[children_func_name](el):iter() do
      if not visited_table[child:val()] then
        visited_table[child:val()] = true
        func_visit(child)
        traverse(child)
      end
    end
  end
  traverse(self)
end

-- TODO: get a queue and implement BFS

function Element:__tostring()
  return string.format('%s[val=%s]', self:class():name(), tostring(self:val()))
end

return Element

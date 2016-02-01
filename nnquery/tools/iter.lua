local classic = require 'classic'
local M = classic.module(...)

--[[
Returns true iff **all** items given by iterator or table `iter` evaluate to true.
]]
function M.all(iter_or_tbl)
  local b = true
  if type(iter_or_tbl) == 'table' then
    for k,v in pairs(iter_or_tbl) do
      b = b and v
    end
  else
    for v in iter_or_tbl do
      b = b and v
    end
  end
  return b and true -- ensure it's a bool
end

--[[
Returns true iff **any** item given by iterator or table `iter` evaluates to true.
]]
function M.any(iter_or_tbl)
  local b = false
  if type(iter_or_tbl) == 'table' then
    for k,v in pairs(iter_or_tbl) do
      b = b or v
    end
  else
    for v in iter_or_tbl do
      b = b or v
    end
  end
  return b or false -- ensure it's a bool
end


--[[
Returns true if the given predicate is true for every item given
by the iterator, false otherwise.

To use with `ElementList`, call as `nnq.tools.iter.all(element_list:iter(), pred)`.

Returns true for an empty iterator.

Predicate arguments: element, index.
]]
function M.all_pred(iter, pred)
  local b = true
  local idx = 1
  for el in iter do
    b = b and pred(el, idx)
    idx = idx + 1
  end
  return b
end

--[[
Returns true if the given predicate is true for ***any*** item
given by the iterator. If it is not true for all, returns false.

Returns false for an empty iterator.

Predicate arguments: element, index.
]]
function M.any_pred(iter, pred)
  local b = false
  local idx = 1
  for el in iter do
    b = b or pred(el, idx)
    idx = idx + 1
  end
  return b
end


return M

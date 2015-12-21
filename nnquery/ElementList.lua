local classic = require 'classic'

--[[
Stores sequences of elements as returned by querying operations, and provides various filtering
and aggregation operations on them.

Most functions either return a single `Element`, a new `ElementList`, or a number (for `:count()`).

### Boring details and implementation decisions:
Makes the assumption that traversing an iterator is cheap, so we sometimes perform multiple 
passes. This allows future use for large data structures. Some small results are cached, but 
most things are constructed on demand, and some large things are not cached as performance
is not an issue: the library is intended mostly to be a debugging tool and for tasks
not part of a hotloop like a training loop, besides when query results are saved and used in
such a loop of course.
Performance optimizations may come later, if needed.
]]
local EL = classic.class(...)

--[[
Constructor meant to be called by an `Element` instance, not by the user.
 - new_elem_iter:  Constructs an iterator that returns the next element in the sequence. 
              May be called multiple times to construct multiple iterators.
              In some cases, this will be used to construct a full table, but
              most operations on the `ElementList` don't need to (like `nth` and similar ops).
]]
function EL:_init(new_elem_iter)
  assert(type(new_elem_iter) == 'function', 'expected iterator factory')
  self._newiter = new_elem_iter
end

--[[
Factory for constructing `ElementList`s from tables of `Element`s.
]]
function EL.static.fromtable(elements)
  assert(type(elements) == 'table', 'expected table')

  -- returns ElementList w/ iterator factory:
  return EL(function()
    local pos = 0
    return function()
      pos = pos + 1
      -- Terminates properly since table[count+1] == nil
      return elements[pos]
    end
  end)
end

--[[
Factory for constructing an empty `ElementList`.
]]
function EL.static.create_empty()
  return EL(function()
    return function() return nil end
  end)
end

--[[
Returns a new iterator over elements of this sequence.
]]
function EL:iter()
  -- . not : because it's a variable, not a method
  return self._newiter()
end

--[[
Returns the `n`th `Element` of the sequence. 
If `n` is negative, counts backward from the end.
The first element is at index 1, and the last is -1.
]]
function EL:nth(n)
  if type(n) ~= 'number' or n == 0 or math.floor(n) ~= n then
    error('expected positive or negative int as argument to :nth()')
  end
  -- Make the index a positive one
  if n < 0 then
    -- e.g. -1 + count + 1 = count
    n = n + self:count() + 1
  end
  
  -- Use a new iterator find the n'th
  i = 1
  for e in self:iter() do
    if i == n then
      return e
    end
    i = i + 1
  end
  error('n out of range')
end

--[[
First `Element`.
]]
function EL:first()
  return self:nth(1)
end

--[[
Last `Element`.
]]
function EL:last()
  return self:nth(-1)
end

--[[
Return a subsequence as an `ElementList`, using the index range given, where
both `from` and `to` are ***inclusive***; `to` may be `nil` to indicate slicing to the end,
and both indices can be negative with the same semantics as `nth`.
]]
function EL:slice(from, to)
  if type(from) ~= 'number' or from == 0 or math.floor(from) ~= from then
    error('expected negative or positive int index for from')
  end
  if (to ~= nil and type(to) ~= 'number') or to == 0 or math.floor(to) ~= to then
    error('expected negative or positive int index for to')
  end
  if to ~= nil and (to < from or (to < 0 and from > 0)) then
    error('range must satisfy to <= from (unless to is nil or negative but from is positive)')
  end

  -- Make all indices positive (relative to start)
  if from < 0 then
    from = from + self:count() + 1
  end
  if to ~= nil and to < 0 then
    to = to + self:count() + 1
  end

  -- Since the slice may be small, in which case iterating every time would be inefficient,
  -- we explicitly construct the result table.
  local results = {}
  local i = 1
  for e in self:iter() do
    if to ~= nil and i > to then
      break
    end
    if i >= from then
      table.insert(results, e)
    end
    i = i + 1
  end
  return EL.fromtable(results)
end

--[[
Returns the number of elements produced by the query.
]]
function EL:count()
  if self._count == nil then
    local count = 0
    for e in self:iter() do
      count = count + 1
    end
    self._count = count
  end
  return self._count
end

--[[
With the given predicate, produces an EL with only the elements 
***after*** (***exclusively*** unless `incl` is `true`) the 
first time `pred` returns true. The predicate will not longer 
be calle the first time it returns true.

Predicate has the same form as `:where()`.
]]
function EL:after(pred, incl)
  local true_yet = false
  return self:where(function(...)
    if not true_yet and pred(...) then
      true_yet = true
      if incl then
        return true
      else
        return false
      end
    end
    return true_yet
  end, true)  -- doesn't construct intermediate table
end

--[[
Similar to `after`, except inclusive.
]]
function EL:iafter(pred)
  return self:after(pred, true)
end

--[[
With the given predicate, produces an EL with only the elements 
***before*** (***exclusively***) the first time 'pred' returns true.
The predicate will not longer be calle the first time it returns true.

Predicate has the same form as in `:where()`.
]]
function EL:before(pred, incl)
  local true_yet = false
  return self:where(function(...)
    if not true_yet and pred(...) then
      true_yet = true
      if incl then
        return false
      else
        return true
      end
    end
    return not true_yet
  end, true)  -- doesn't construct intermediate table
end

--[[
Similar to `before`, except inclusive.
]]
function EL:ibefore(pred)
  return self:before(pred, true)
end

--[[
Returns a table of the `Element`s.

Tables are not cached, so the table can be safely modified and not affect subsequent calls.
]]
function EL:totable()
  local result = {}
  for e in self:iter() do
    table.insert(result, e)
  end
  return result
end

--[[
Filters by the given predicate function: each `Element` in the `ElementList`
is passed to the sequence and must be return true iff it is meant to kept.
Returns a new `ElementList`.

If `no_table` is true, doesn't construct a table. This is ideal for when the result of
the `:where()` will only be used once or chained. Used frequently to implement the
other filters.

The function is passed two args: the `Element`, and its index into the `ElementList`.
The index argument needn't be given for lua functions, which ignore extra args.
]]
function EL:where(pred, no_table)
  if type(pred) ~= 'function' then
    error('expected function as argument to :where()')
  end

  if no_table then
    return EL(function()
      local pos = 0
      local iter = self:iter()
      return function()
        local el
        -- fetch the next matching element, if any, and return if found, else nil
        pos = pos + 1
        el = iter()
        while el do
          if pred(el, pos) then
            return el
          end
          pos = pos + 1
          el = iter()
        end
      end
    end)
  else
    -- Here, we don't construct on the fly, in case pred() is rarely or never true, in which
    -- case caching is a better idea.
    local results = {}
    local pos = 1
    for e in self:iter() do
      if pred(f, pos) then
        table.insert(results, e)
      end
      pos = pos + 1
    end
    return EL.fromtable(results)
  end
end

--[[
Given a table mapping `Element` property names to values, returns only the
elements where ***all*** properties equal (using `==`) the provided values.

Each property can be a simple instance variable or a getter method that takes
no arguments.
]]
function EL:props(props)
  if type(props) ~= 'table' then
    error('props must be a table of properties to check')
  end
  return self:where(function(el)
    local all_true = true
    for k, v in pairs(props) do
      local prop_val 
      if type(el[k]) == 'function' then
        prop_val = el[k](el)  -- getter method needs implicit self
      else
        prop_val = el[k]
      end
      all_true = all_true and (prop_val == v)
    end
    return all_true
  end)
end

--[[
Same as `:props()` except ***any*** property must match rather than all.
]]
function EL:props_any(props)
  if type(props) ~= 'table' then
    error('props must be a table of properties to check')
  end
  return self:where(function(el)
    for k, v in pairs(props) do
      local prop_val 
      if type(el[k]) == 'function' then
        prop_val = el[k](el)  -- getter method needs implicit self
      else
        prop_val = el[k]
      end
      if prop_val == v then
        return true
      end
    end
    return false
  end)
end

function EL:__tostring()
  local strs = {}
  for e in self:iter() do
    table.insert(strs, tostring(e))
  end
  return string.format('%s{\n  %s\n}',
                       self:class():name(),
                       table.concat(strs, ',\n  '))
end

return EL

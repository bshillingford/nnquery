--[[
Represents a query execution context, which keeps track of a registry of 
`Element` types and provides a mechanism for constructing an `Element`
given the registry.

Caches `Element` instances for wrapped values, guaranteeing that two calls
to `:wrap()` in the same context always return the same `Element`. Note that
this means a reference will be retained and seemingly deleted objects
will not be freed until the cache is clear. In that case, call `:clear()`.

Note that cacheing does not affect mutating children of a value, at least
in the case of `ContainerElement`, which builds up children lists on the 
fly every time it is called. For `nngraph` `Element`s, these are not (easily)
mutable, so that implementation caches its nodes and wrapped nodes.
]]

local classic = require 'classic'

local nnquery = require 'nnquery'

local Context = classic.class(...)

--[[
single_match: if true, only allows one handler to match. 
    Otherwise, the first matching handler is used.
    Defaults to false.
]]
function Context:_init(single_match)
  self.single_match = single_match or false
  self._reg = {}
  -- Cache table mapping vals to Elements, guaranteeing only one Element exists per val
  self._wrapcache = {}
end

--[[
Clears `Element` cache.
]]
function Context:clear()
  self._wrapcache = {}
end

--[[
Register the provided `Element` to handle the cases specified by the 
match-checking predicate. Note that only one registered handle can return
true for a given object.
]]
function Context:reg(cls, check_match)
  if type(check_match) ~= 'function' then
    error('Match-checking predicate must be a function')
  end
  if not cls:isSubclassOf(nnquery.Element) then
    error('Can only register Element subclasses')
  end
  table.insert(self._reg, {cls=cls, check_match=check_match})
  return self
end

--[[
Registers a default `Element` implementation in case no registered handlers match.
If not specified, `:wrap()` will raise an error.
]]
function Context:default(elem_class)
  if not elem_class:isSubclassOf(nnquery.Element) then
    error('Can only register Element subclasses')
  end
  self._default_cls = elem_class
  return self
end

--[[
As specified by the registered handlers, wraps the given object in an 
instance of `Element` (or subclass).

Behaviour depends on value of `single_match` provided to ctor.
]]
function Context:wrap(val)
  if self._wrapcache[val] then
    return self._wrapcache[val]
  end

  local wrapped_reg
  local wrapped
  for _, reg in ipairs(self._reg) do
    if reg.check_match(val) then
      if wrapped then
        error('More than one handler matched, first ' 
            .. tostring(wrapped_reg or reg.cls:name())
            .. ', now ' .. tostring(reg.name or reg.cls:name()))
      end
      wrapped_reg = reg
      -- first arg to ctor is ctx, second is the wrapee
      wrapped = reg.cls(self, val)
      -- if we're only allowing a single matching handler, keep going
      -- to check that no other handlers match
      if not self.single_match then
        break
      end
    end
  end
  if not wrapped_reg then
    if self._default_cls then
      return self._default_cls(self, val)
    else
      error('No handlers matched, and no default class provided')
    end
  end
  self._wrapcache[val] = wrapped
  return wrapped
end

--[[
Applies `:wrap()` over a table, returns a table of wrapped objects.
]]
function Context:wrapall(vals)
  local wrappeds = {}
  for _,v in ipairs(vals) do
    table.insert(wrappeds, self:wrap(v))
  end
  return wrappeds
end

--[[
Convenient alias for `:wrap()`.
Intended to be used by the user, not by internal code for the sake
of cleanliness.
]]
function Context:__call(val)
  return self:wrap(val)
end

return Context


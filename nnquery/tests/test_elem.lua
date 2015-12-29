--[[
Tests the following classes (not all in isolation, TODO: write real unit tests w/ mocks):
 * Element (abstract base class)
 * ModuleElement (abstract base class)
 * ContainerElement
 * ChildlessElement
]]

local totem = require 'totem'
local nn = require 'nn'

-- path hack for running in src dir without nnquery installed:
package.path = package.path .. ';../../?/init.lua;../?/init.lua'
                            .. ';../../?.lua;../?.lua'
local nnq = require 'nnquery'

local tester = totem.Tester()
local tests = {}

-- Constructs container- and childless-only context
local function newctx()
  local ctx = nnq.Context()
  ctx:reg(nnq.ContainerElement, nnq.ContainerElement.isContainer)
  ctx:default(nnq.ChildlessElement)
  return ctx
end

function tests.Val()
  local ctx = newctx()
  local mod = nn.Identity()
  tester:asserteq(ctx(mod):val(), mod, 'wrong val')
end

function tests.FollowingSiblingsPrecedingSiblings()
  local ctx = newctx()
  local before = nn.Sigmoid()
  local idn = nn.Tanh()
  local after = nn.ReLU()
  local mod = nn.Container()
        :add(nn.Identity())
        :add(before)
        :add(idn)
        :add(after)
        :add(nn.Identity())
        :add(nn.Identity())

  -- make sure we grab the right one:
  tester:asserteq(ctx(mod):children():nth(3):val(), idn, 'wrong val?')
  -- test sibling behaviour
  tester:asserteq(ctx(mod):children():nth(3):following_siblings():count(), 3, 'should be 3 siblings after')
  tester:asserteq(ctx(mod):children():nth(3):following_siblings():first():val(), after, 'wrong element after')
  tester:asserteq(ctx(mod):children():nth(3):preceding_siblings():count(), 2, 'should be 2 siblings before')
  tester:asserteq(ctx(mod):children():nth(3):preceding_siblings():last():val(), before, 'wrong element before')
end

-- Mostly for the before/after tests below...
local function new_ctx_simple_container1()
  local ctx = newctx()
  local mod = nn.Container()
        :add(nn.Identity())
        :add(nn.ReLU())
        :add(nn.ReLU())
        :add(nn.Identity())
        :add(nn.Identity())
  return ctx, mod, ctx(mod):children()
end

--[[ Tests basic filtering by predicate. ]]
function tests.Where()
  local ctx, mod, children = new_ctx_simple_container1()

  -- returns iterator:
  local result = children:where(
      function(x, i) return torch.isTypeOf(x:val(), nn.Identity) end, true)
  tester:asserteq(result:count(), 3, 'expect 3 nn.Identitys')
  tester:asserteq(#result:totable(), 3, 'expect 3 nn.Identitys')
  tester:asserteq(#result:totable(), 3, 'expect 3 nn.Identitys again')
  -- returns table:
  local result = children:where(
      function(x, i) return torch.isTypeOf(x:val(), nn.Identity) end, false)
  tester:asserteq(result:count(), 3, 'expect 3 nn.Identitys')
  tester:asserteq(#result:totable(), 3, 'expect 3 nn.Identitys')
end

--[[ Tests getting elements in a list before/after a predicate is true.
Edge cases: empty/full.
]]
function tests.BeforeAfterEmptyFull()
  local ctx, mod, children = new_ctx_simple_container1()

  -- empty 'before' (i.e. returns true on first iter):
  tester:asserteq(
      children:before(function() return true end):count(),
      0,
      'should be an empty result')
  -- full 'before' (i.e. returns false on all iter)
  tester:asserteq(
      children:before(function() return false end):count(),
      #mod.modules,
      'should be a full result')

  -- empty 'after' (i.e. returns false on all iter):
  tester:asserteq(
      children:after(function() return false end):count(),
      0,
      'should be an empty result')
  -- *almost* full 'after' (i.e. returns true on first iter),
  -- returns all elements except first
  tester:asserteq(
      children:after(function() return true end):count(),
      #mod.modules - 1,
      'should be an ALMOST full result')
end

--[[ Tests getting elements in a list before/after a predicate is true.
Typical case.
]]
function tests.BeforeAfterTypical()
  local ctx, mod, children = new_ctx_simple_container1()

  -- get elements before the 2nd (of 5) element:
  local result = children:before(function(x, i) return i == 2 end)
  tester:asserteq(result:count(), 1, 'should be 1 element before')
  tester:asserteq(result:first():val(), mod.modules[1], 'and it should be just the identity')

  -- get elements after the 2nd (of 5) element:
  local result = children:after(function(x, i) return i == 2 end)
  tester:asserteq(result:count(), 3, 'should be 3 elements after')
end

--[[ Tests getting elements in a list before/after a predicate is true, inclusive version.
Edge cases.
]]
function tests.BeforeAfterInclEmptyFull()
  local ctx, mod, children = new_ctx_simple_container1()

  -- empty 'before' (i.e. returns true on first iter):
  tester:asserteq(
      children:ibefore(function() return true end):count(),
      1,
      'should be a singleton result')
  -- full 'before' (i.e. returns false on all iter)
  tester:asserteq(
      children:ibefore(function() return false end):count(),
      #mod.modules,
      'should be a full result')

  -- empty 'after' (i.e. returns false on all iter):
  tester:asserteq(
      children:iafter(function() return false end):count(),
      0,
      'should be an empty result')
  -- full 'after' (i.e. returns true on first iter),
  tester:asserteq(
      children:iafter(function() return true end):count(),
      #mod.modules,
      'should be a full result')
end

--[[ Tests getting elements in a list before/after a predicate is true, inclusive version.
Edge cases.
]]
function tests.BeforeAfterIncl()
  local ctx, mod, children = new_ctx_simple_container1()

  -- get elements before the 2nd (of 5) element:
  local result = children:ibefore(function(x, i) return i == 2 end)
  tester:asserteq(result:count(), 2, 'should be 2 element before')
  tester:asserteq(result:first():val(), mod.modules[1], 'and it should be just the identity')

  -- get elements after the 2nd (of 5) element:
  local result = children:iafter(function(x, i) return i == 2 end)
  tester:asserteq(result:count(), 4, 'should be 4 elements after')
end

--[[ Tests depth first search on an element's descendants. ]]
function tests.DescendantsAndDFS()
  -- Create a context and tree-shaped container
  local ctx = newctx()
  local mod = nn.Container()
      :add(nn.Identity())
      :add(nn.Sequential()
          :add(nn.ParallelTable()
              :add(nn.Identity())
              :add(nn.Sequential()))
          :add(nn.Identity()))
  -- Number of descendants = number of lines of code above = 6
  tester:asserteq(ctx(mod):descendants():count(), 6, 'should be 6 descendants')

  ctx(mod):dfs(function(el)
    -- Each nn module should be visited precisely once:
    tester:assert(not el:val().test_visited, 'should visit each element precisely once')
    el:val().test_visited = true
    -- Check that parent is set correctly:
    local found_self = false
    for i in el:parents():only():children():iter() do
      if el:equals(i) then
        found_self = true
      end
    end
    tester:assert(found_self, "parent set incorrectly: cannot find self in parent's children")
  end)
end

return tester:add(tests):run()

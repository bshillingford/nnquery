--[[
Tests the nngraph classes, also needs ChildlessElement:
 * NNGraphNodeElement
 * NNGraphGModuleElement
 * ChildlessElement
]]

local totem = require 'totem'
require 'nn'
require 'nngraph'

-- path hack for running in src dir without nnquery installed:
package.path = package.path .. ';../../?/init.lua;../?/init.lua'
                            .. ';../../?.lua;../?.lua'
local nnq = require 'nnquery'

local tester = totem.Tester()
local tests = {}

-- Constructs context: NNGraphNodeElement, NNGraphGModuleElement, ChildlessElement
local function newctx()
  local ctx = nnq.Context()
  ctx:reg(nnq.NNGraphGModuleElement, nnq.NNGraphGModuleElement.isGmodule)
  ctx:reg(nnq.NNGraphNodeElement, nnq.NNGraphNodeElement.isNode)
  ctx:default(nnq.ChildlessElement)
  return ctx
end

function tests.Val()
  local ctx = newctx()
  local mod = nn.Identity()
  tester:asserteq(ctx(mod):val(), mod, 'wrong val')
end

-- Helper function to generate one timestep of an LSTM:
-- (source: Oxford practical 6)
-- Modified for test purposes (e.g. is_i2h), rnn_size=1, etc.
function create_lstm()
  local rnn_size = 1 -- for testing purposes
  local x = nn.Identity()()
  local prev_c = nn.Identity()()
  local prev_h = nn.Identity()()

  function new_input_sum()
    -- transforms input
    local i2h            = nn.Linear(rnn_size, rnn_size)(x):annotate{is_i2h=true}
    -- transforms previous timestep's output
    local h2h            = nn.Linear(rnn_size, rnn_size)(prev_h):annotate{is_h2h=true}
    return nn.CAddTable()({i2h, h2h})
  end
  local in_gate          = nn.Sigmoid()(new_input_sum())
  local forget_gate      = nn.Sigmoid()(new_input_sum())
  local out_gate         = nn.Sigmoid()(new_input_sum())
  local in_transform     = nn.Tanh()(new_input_sum())

  local next_c           = nn.CAddTable()({
    nn.CMulTable()({forget_gate, prev_c}),
    nn.CMulTable()({in_gate,     in_transform})
  })
  local next_h           = nn.CMulTable()({out_gate, nn.Tanh()(next_c)})

  nngraph.annotateNodes()
  return nn.gModule({x, prev_c, prev_h}, {next_c, next_h})
end

--[[
Some basic operations on the above LSTM module.

Serves as documentation.
]]
function tests.LSTM()
  local ctx = newctx()
  local lstm = create_lstm()

  -- Get an Element for forget_gate: (twice)
  local forget_gate = ctx(lstm):descendants()
      :where(function(e) return e:val().data.annotations.name == 'forget_gate' end):only()
  local forget_gate_2 = ctx(lstm):descendants():attr{name='forget_gate'}:only()
  tester:asserteq(forget_gate:val(), forget_gate_2:val(), 'both ways should find same node')

  -- Only one parent: input_sum. In turn has two parents: i2h and h2h nn.Linear's
  local input_sum = forget_gate:parent() -- error if more than one, in which case use :parents()
  tester:asserteq(#input_sum:parents(), 2, 'wrong number of parents to input_sum')
  -- These names i2h and h2h aren't automatically set by annotateNodes(), since in closure:
  local i2h, h2h = unpack(input_sum:parents():totable())
  tester:assert(i2h:val().data.annotations.is_i2h, 'is not i2h')
  tester:assert(h2h:val().data.annotations.is_h2h, 'is not h2h')

  -- Get the output nodes, verify they are next_c and next_h, resp.
  tester:asserteq(ctx(lstm):outputs():count(), 2, 'should have 2 outputs')
  tester:asserteq(ctx(lstm):outputs():first():name(), 'next_c')
  tester:asserteq(ctx(lstm):outputs():last():name(), 'next_h')
end

return tester:add(tests):run()

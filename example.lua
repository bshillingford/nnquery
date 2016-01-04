require 'nn'
require 'nngraph'
local nnq = require 'nnquery'

-- nngraph implementation of LSTM timestep, from Oxford course's practical #6
function create_lstm(opt)
    local x = nn.Identity()()
    local prev_c = nn.Identity()()
    local prev_h = nn.Identity()()

    function new_input_sum()
        -- transforms input
        local i2h            = nn.Linear(opt.rnn_size, opt.rnn_size)(x)
        -- transforms previous timestep's output
        local h2h            = nn.Linear(opt.rnn_size, opt.rnn_size)(prev_h)
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
    local mod = nn.gModule({x, prev_c, prev_h}, {next_c, next_h})
    mod.name = "LSTM"
    return mod
end

-- Example network
local foo = nn.Sequential()
    :add(nn.Module())
    :add(create_lstm{rnn_size=3})
    :add(nn.ReLU())
    :add(nn.ReLU())
    :add(nn.Linear(3, 4))

-- Find the LSTM in a few different ways:
local lstm = nnq(foo)   -- Wrap the module in an Element object using the default context
                        -- which allows querying nn containers and nngraph's gmodules.
    :descendants()      -- Get all descendants below this node in the graph
    :where(function(e)  -- Filter Elements by the given predicate
      return e:classIs(nnq.NNGraphGModuleElement)
    end)
    :only()             -- Returns the first element in the returned sequence, and
                        -- asserts that it is the only element in the sequence.
                        -- (shortcut for list:first() and assert(list:count() == 1))
local lstm2 = nnq(foo)
    :children()         -- Returns the contained modules of the nn.Sequential object as an
                        -- ElementList
    :nth(2)             -- Grabs the 2nd child of the nn.Sequential
                        -- (alternate shorthand syntax: nnq(foo):children()[2])
local lstm3 = nnq(foo)
    :descendants()      -- <same as above>
    :attr{name='LSTM'}  -- Get only the objects with a name attribute set to 'LSTM',
                        -- where it'll check both raw attributes and attempt to call
                        -- the function assuming it's a getter method, i.e. check 
                        -- module:name() == 'LSTM'.
assert(lstm:val() == lstm2:val() and lstm2:val() == lstm3:val(),
    'they should all return the same LSTM gmodule')

-- Get the output nodes of the nngraph gmodule as an ElementList:
local outputs = lstm:outputs()
-- Two ways to get the count for an ElementList:
print('The LSTM gmodule has '..outputs:count()..' outputs, they are:' outputs)
print('The LSTM gmodule has '..#outputs..' outputs, they are:', outputs)
assert(outputs:first():name() == 'next_c')  -- :name() is available on NNGraphNodeElements,
                                            -- as a shortcut for:
assert(outputs:first():val().data.annotations.name == 'next_c') 

-- Let's find the forget gate:
local forget_gate = lstm:descendants():attr{name='forget_gate'}:only()
print(forget_gate)
-- But it's the sigmoid, not the gate's pre-activations, so let's get the sum:
local input_sum = forget_gate:parent() -- This is an alias for :parents():only().
                                       -- Note: nngraph nodes can have multiple parents (i.e.
                                       -- inputs 
assert(torch.isTypeOf(input_sum:val().data.module, nn.CAddTable))
assert(torch.isTypeOf(input_sum:module(), nn.CAddTable)) -- alias for :val().data.module


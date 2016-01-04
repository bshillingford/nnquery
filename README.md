# `nnquery`: query large neural network graph structures in Torch
NN modules in Torch are often complex graph structures, like `nn.Container`s and its subclasses and `nn.gModules` (`nngraph`), arbitrarily nested. This makes it tedious to extract nn modules when debugging, monitoring training progress, or testing.

`nnquery` provides a facility to query these arbitrarily complex DAGs. XPath and CSS are designed to handle trees, whereas this library supports querying DAGs like neural nets.
The API is loosely inspired by a mix of XPath, CSS queries, and .NET's LINQ.

See below for a simple example, and a more complete example of extracting things from an LSTM.

## Installation
Install `classic` (a class library from DeepMind) first:
```
luarocks install https://raw.githubusercontent.com/deepmind/classic/master/rocks/classic-scm-1.rockspec
```
Install `nnquery`:
```
luarocks install https://raw.githubusercontent.com/bshillingford/nnquery/master/rocks/nnquery-scm-1.rockspec
```
Totem is optional, and used for unit tests.

# Usage
There are two important base classes that nearly everything is derived from:

 * `Element` (full name: `nnquery.Element`)
 * `ElementList`

Every object you wish to query is wrapped in an `Element`, and sequences/collections of these
are represented using `ElementList`s.

To wrap an object in an `Element` so you can query it:
```lua
local nnq = require 'nnquery'
local seq = nn.Sequential()
	:add(nn.Tanh())
	:add(nn.ReLU())

local tanh = nnq(seq):children():first()
```
In the code: `nnq(seq)` wraps `seq` into an `Element`; `:children()` returns an `ElementList` of two `Elements` for `seq`'s children; `:first()` returns the first `Element` in the `ElementList`.

## Details:
Wrapping objects into elements and similar operations only make sense relative to a **context**, an instance of `nnquery.Context`, which contains a list of `Element` types and conditions on which to instantiate depending on what type is provided to it. Additionally, the context caches `Element`s, so that wrapping the same object twice returns the same instance of the `Element` subclass.
`nnquery/init.lua` contains the construction of a default context (accessible as `nnquery.default`) that contains all the implemented `Element` types, similarly to this:
```lua
local ctx = nnq.Context()
ctx:reg(nnq.NNGraphGModuleElement, nnq.NNGraphGModuleElement.isGmodule)
ctx:reg(nnq.NNGraphNodeElement, nnq.NNGraphNodeElement.isNode)
ctx:reg(nnq.ContainerElement, nnq.ContainerElement.isContainer) -- after since gModule IS_A Container
ctx:default(nnq.ChildlessElement)
```

Note that there is no true "root" node, unlike an XML/HTML document; the root is simply the place where the query begins. Therefore, one cannot[*] search for the root's parents, even if the root module is contained in (for example) a container.

[*] Usually. Unless an element's parents are pre-populated from a previous query.

## Further Documentation
Further documentation can be found in doc comment style before class definitions and method definitions in the code itself.

***TODO: extract these into markdown format and put links here***

# Realistic example with an LSTM:
This is an example of using various functions in `Element` and `ElementList`:
```lua
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
    :only()
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
```

# Developing
## Extending
You may have your own `nn` modules that are not handled by the existing handlers. In this case,
you can implement your own `Element` object (see the existing ones for examples), and create your own context that adds a handler for this `Element`. See the default context (see above) for details.
## Contributing
Bug reports are appreciated, preferably with a pull request for a test that breaks existing code and a patch that fixes it. If you do, please adhere to the (informal) code style in the existing code where appropriate.


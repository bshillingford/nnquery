package.path = package.path .. ';./?/init.lua'

require 'nn'
require 'env'
nnq = require 'nnquery'

ctx = nnq.Context()
ctx:reg(nnq.ContainerElement, nnq.ContainerElement.isContainer) -- nn.Container s
--ctx:default(nnq.ChildlessElement) -- root nodes
ctx:reg(nnq.ChildlessElement, function(x) return not nnq.ContainerElement.isContainer(x) end)

seq = nn.Sequential()
  :add(nn.Linear(3,4))
  :add(nn.Container():add(nn.ReLU()):add(nn.Tanh()))

e = ctx(seq)


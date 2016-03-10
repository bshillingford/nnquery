package = 'nnquery'
version = 'scm-1'

source = {
  url = 'git://github.com/bshillingford/nnquery.git',
  branch = 'master'
}

description = {
  summary = 'Query complex graph structures in neural networks',
  detailed = 'Traverse complex neural netwrok graph structures as easily as XPath or CSS',
  homepage = 'https://github.com/bshillingford/nnquery',
  license = 'BSD'
}

dependencies = {
  'lua >= 5.1',
  'torch',
  'classic'
}

build = {
  type = 'builtin',
  modules = {
    nnquery = 'nnquery/init.lua',
    ['nnquery.Element'] = 'nnquery/Element.lua',
    ['nnquery.ChildlessElement'] = 'nnquery/ChildlessElement.lua',
    ['nnquery.ContainerElement'] = 'nnquery/ContainerElement.lua',
    ['nnquery.Context'] = 'nnquery/Context.lua',
    ['nnquery.Element'] = 'nnquery/Element.lua',
    ['nnquery.ElementList'] = 'nnquery/ElementList.lua',
    ['nnquery.ModuleElement'] = 'nnquery/ModuleElement.lua',
    ['nnquery.NNGraphGModuleElement'] = 'nnquery/NNGraphGModuleElement.lua',
    ['nnquery.NNGraphNodeElement'] = 'nnquery/NNGraphNodeElement.lua',
  }
}


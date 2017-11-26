# Auto-generated selectors for direct state subtrees.
# You shouldn't touch this.

{at, head} = require 'lodash'

# Programmatically create accessors.
reducerReq = require.context 'reducers', false, /^\.\/[^.]*$/
module.exports = reducerReq.keys().reduce ((a, n) ->
  if n isnt './index'
    field = n.slice 2
    a["$#{field}"] = (state) -> state[field]
  a
),
  # Selector for GraphQL.
  sgql: (path) -> (state) -> head at state.data, path

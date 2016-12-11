# Asynchronous actions.

{API_URL} = require 'constants'
actions = require 'actions'

module.exports =
  fetchLibs: -> (dispatch) ->
    dispatch actions.requestLibs()
    fetch "#{API_URL}/libs"
      .then (r) -> r.json()
      .then (libs) -> dispatch actions.receiveLibs libs
      .catch (e) -> dispatch actions.errorLibs()

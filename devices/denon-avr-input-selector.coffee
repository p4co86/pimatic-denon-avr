module.exports = (env) ->

  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)

  # Device class representing the power switch of the Denon AVR
  class DenonAvrInputSelector extends env.devices.ButtonsDevice

    # Create a new DenonAvrInputSelector device
    # @param [Object] config    device configuration
    # @param [DenonAvrPlugin] plugin   plugin instance
    # @param [Object] lastState state information stored in database
    constructor: (@config, @plugin, lastState) ->
      @_base = commons.base @, @config.class
      @id = @config.id
      @name = @config.name
      @interval = @_base.normalize @config.interval, 10
      @debug = @plugin.debug || false
      for b in @config.buttons
        b.text = b.id unless b.text?
      @plugin.on 'response', @_onResponseHandler()
      super(@config)
      process.nextTick () =>
        @_requestUpdate()

    _requestUpdate: () ->
      @_base.cancelUpdate()
      @_base.debug "Requesting update"
      @plugin.connect().then =>
        @plugin.sendRequest 'SI', '?'
      .catch (error) =>
        @_base.error "Error:", error
      .finally () =>
        @_base.scheduleUpdate @_requestUpdate, @interval * 1000

    _onResponseHandler: () ->
      return (response) =>
        @_base.debug "Response", response.matchedResults
        if response.command is 'SI' and response.param isnt @_lastPressedButton
          @_lastPressedButton = response.param
          @emit 'button', response.param

    buttonPressed: (buttonId) ->
      for b in @config.buttons
        if b.id is buttonId
          @_lastPressedButton = b.id
          @emit 'button', b.id
          return @plugin.connect().then =>
            @plugin.sendRequest 'SI', b.id
      throw new Error("No button with the id #{buttonId} found")

    getState: () ->
      return Promise.resolve @_state

module Hermann
  class Result
    attr_reader :reason, :state

    STATES = [:pending,
              :rejected,
              :fulfilled,
              :unfulfilled,
              ].freeze

    def initialize(producer)
      @producer = producer
      @reason = nil
      @value = nil
      @state = :unfulfilled
    end

    STATES.each do |state|
      define_method("#{state}?".to_sym) do
        return @state == state
      end
    end

    # @return [Boolean] True if this child can be reaped
    def reap?
      return true if rejected? || fulfilled?
      return false
    end

    # INTERNAL METHOD ONLY. Do not use
    #
    # This method will be invoked by the underlying extension to indicate set
    # the actual value after a callback has completed
    #
    # @param [Object] value The actual resulting value
    # @param [Boolean] is_error True if the result was errored for whatever
    #   reason
    def set_internal_value(value, is_error)
      @value = value
    end
  end
end
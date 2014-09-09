require 'hermann'
require 'hermann/result'
require 'hermann/timeout'
require 'hermann_lib'

module Hermann
  class Producer
    attr_reader :topic, :brokers, :internal, :children

    def initialize(topic, brokers)
      @topic = topic
      @brokers = brokers
      @internal = Hermann::Lib::Producer.new(topic, brokers)
      # We're tracking children so we can make sure that at Producer exit we
      # make a reasonable attempt to clean up outstanding result objects
      @children = []
    end

    # Push a value onto the Kafka topic passed to this +Producer+
    #
    # @param [Array] value An array of values to push, will push each one
    #   separately
    # @param [Object] value A single object to push
    # @return [Hermann::Result] A future-like object which will store the
    #   result from the broker
    def push(value)
      result = create_result

      if value.kind_of? Array
        return value.map do |element|
          self.push(element)
        end
      else
        @internal.push_single(value, result)
      end

      return result
    end

    # Create a +Hermann::Result+ that is tracked in the Producer's children
    # array
    #
    # @return [Hermann::Result] A new, unused, result
    def create_result
      @children << Hermann::Result.new(self)
      return @children.last
    end

    # Tick the underlying librdkafka reacter and clean up any unreaped but
    # reapable children results
    #
    # @param [FixNum] timeout Seconds to block on the internal reactor
    # @return [FixNum] Number of +Hermann::Result+ children reaped
    def tick_reactor(timeout=0)
      timeout = rounded_timeout(timeout)

      if timeout == 0
        @internal.tick(0)
      else
        (timeout * 2).times do
          # We're going to Thread#sleep in Ruby to avoid a
          # pthread_cond_timedwait(3) inside of librdkafka
          events = @internal.tick(0)
          # If we find events, break out early
          break if events > 0
          sleep 0.5
        end
      end

      return reap_children
    end

    # @return [FixNum] number of children reaped
    def reap_children
      # Filter all children who are no longer pending/fulfilled
      total_children = @children.size
      @children = @children.reject { |c| c.reap? }
      reaped = total_children - children.size
    end


    private

    def rounded_timeout(timeout)
      # Handle negative numbers, those can be zero
      return 0 if (timeout < 0)
      # Since we're going to sleep for each second, round any potential floats
      # off
      return timeout.round if timeout.kind_of?(Float)
      return timeout
    end
  end
end

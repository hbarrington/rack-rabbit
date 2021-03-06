module RackRabbit
  class Signals

    # The RackRabbit server process has a single primary thread, but it doesn't
    # actually need to do any work once it has spun up the worker processes. I
    # need it to hibernate until one (or more) signal event's occurs.
    #
    # Originally I tried to use the standard Thread::Queue, it uses a Mutex to
    # perform a blocking pop on the Queue. However Ruby (2.x) won't let the last
    # active thread hibernate (it's overly aggressive at deadlock prevention)
    #
    # So, instead of using a Mutex based Queue, I can use a blocking select
    # on an IO pipe, then when the signal handler pushes into the Queue
    # it can also write to the pipe in order to "awaken" the primary thread.
    #
    # FYI: this is the same underlying idea that is used by the Unicorn master
    #      process, I've just encapsulated it in a Signals class
    #

    def initialize
      @reader, @writer = IO.pipe
      @queue = []
    end

    def close
      @reader.close
      @writer.close
      @reader = @writer = nil
    end

    def closed?
      @reader.nil?
    end

    def push(item)
      raise RuntimeError, "closed" if closed?
      @queue << item
      awaken
    end

    def pop(options = {})
      raise RuntimeError, "closed" if closed?
      if @queue.empty? && (:timeout == hibernate(options[:timeout]))
        :timeout
      else
        @queue.shift
      end
    end

  private

    def awaken
      @writer.write '.'
    end

    def hibernate(seconds = nil)
      return :timeout unless IO.select([@reader], nil, nil, seconds)
      @reader.readchar 
    end

  end
end

require 'time'

module TinyRl
  # this class offers a rate limiter that accepts method calls to make over a
  # period of time, and a strategy to handle what happens when you exceed that
  # limit
  #
  # Usage:
  #    > rl = TinyRl.new(5, TinyRl::MINUTE, :drop)
  #   => <a rate limiter that will drop method calls over a rate of 5 per minute>
  #    > 10.times{ rl.do(api, :auth, auth_token) }
  #   => <the first 5 will go through, and the subsequent 5 will be dropped>
  class Exec
    STRATEGIES = %i(drop error queue)

    SECOND  = 1
    MINUTE  = SECOND * 60
    HOUR    = MINUTE * 60
    DAY     = HOUR * 24
    WEEK    = DAY * 7
    MONTH   = DAY * 30
    YEAR    = DAY * 365

    # rate: number of requests per unit time
    # per: unit of time (one of SECOND, MINUTE, etc.)
    #   you can pass any integer in as the `per' parameter and it will be
    #   interpreted as a number of seconds
    # strategy: what to do when you're over the rate limit
    #   drop: drop the request, never perform the method call
    #   error: raise an exception when rate exceeded
    #   queue: enqueue the method call to be executed later when there's time
    def initialize(limit, per, strategy)
      @total_calls = 0
      @dropped_calls = 0
      @errored_calls = 0
      @limit = limit
      @per = per
      @strategy = strategy

      case @strategy
      when :queue
        @queue = Queue.new
        Thread.new do
          loop do
            sleep 1 if 
          end
        end
      end
      @jobs = []
    end

    # this method enqueues a TinyRl::Job to be executed. if the job can be
    # executed immediately it will skip the queue.
    #
    # job: the TinyRl::Job to be executed
    def <<(job)
      @total_calls += 1

      # remove calls beyond the @per threshold
      loop do
        if @jobs.length > 0 && @jobs.first < (Time.now - @per)
          @jobs.shift
        else
          break
        end
      end

      if @jobs.length == @limit
        case @strategy
        when :drop
          @dropped_calls += 1
        when :error
          @errored_calls += 1
          raise ExceededRateLimitError.new("Rate limit of #{@limit} per #{@per} sec exceeded")
        when :queue
          @queue << [Time.now.to_i, object, method, notify, args]
        end

        @errored_calls
      else
        @jobs << Time.now
        notify.notify(object.send(method, args))
      end
    end

    # returns true if the number of calls records is equal to the max limit
    # configured, false otherwise
    def at_capaticy?
      
    end

    def to_s
      <<~TO_S
              usage: #{@cals.length} of #{@rate} per #{@per} sec
           strategy: #{@strategy}
        total calls: #{@total_calls}
         drop calls: #{@strategy == :drop ? @dropped_calls : 'N/A'}
        error calls: #{@strategy == :error ? @errored_calls : 'N/A'}
      TO_S
    end
  end
end

class TinyRl::ExceededRateLimitError < RuntimeError; end
class TinyRl::InvalidStrategyError < RuntimeError; end

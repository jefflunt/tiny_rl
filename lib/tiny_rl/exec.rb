require 'time'

module TinyRl
  # this class offers a rate limiter that accepts instances of TinyRl::Jobs to
  # execute over period of time, and a strategy to handle what happens when you
  # exceed that limit
  #
  # Usage:
  #    > rl = TinyRl::Exec.new(5, TinyRl::Exec::MINUTE, :drop)
  #   => <a rate limiter that will drop method calls over a rate of 5 per minute>
  #    > 10.times{ rl.exec(TinyRl::Job.new(->(base){ base ** 2 }, nil, rand(10)) }
  #   => <the first 5 jobs that square the random integer will execute, and the subsequent 5 will be dropped without being executed>
  #
  # if you use the :error strategy an instance of TinyRl::ExceededRateLimitError
  # will be raised when you exceed the limit instead of the TinyRl::Job being
  # silently dropped.
  #
  # if you want to be cautious and not try to run a TinyRl::Job that will
  # error/drop, then you can check TinyRl::Exec#at_capacity? before trying to
  # run it.
  class Exec
    STRATEGIES = %i(drop error)

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
    def initialize(limit, per, strategy)
      raise TinyRl::InvalidStrategyError.new("Strategy `#{strategy.inspect}' is not one of the allowed strategies") unless STRATEGIES.include?(strategy)
      @total_jobs = 0
      @dropped_jobs = 0
      @errored_jobs = 0
      @limit = limit
      @per = per
      @strategy = strategy

      @job_call_times = []
    end

    # this method attempts to run the specified job if we're not over the rate
    # limit. if we are over the rate limit then the behavior depends on the
    # strategy parameter passed into the initializer
    #
    # job: the TinyRl::Job to be executed
    #
    # for strategy :drop
    #   returns true if the job was run, false if it was dropped
    # for strategy :error
    #   returns true if the job was run, raises an exception otherwise
    def exec(job)
      @total_jobs += 1

      if at_capacity?
        case @strategy
        when :drop
          @dropped_jobs += 1
        when :error
          @errored_jobs += 1
          raise ExceededRateLimitError.new("Rate limit of #{@limit} per #{@per} sec exceeded")
        end
        false
      else
        @job_call_times << Time.now
        job.exec
        true
      end
    end

    # returns true if the rate limit has currently been reached, false otherwise
    def at_capacity?
      _clear_old_jobs
      @job_call_times.length == @limit
    end

    # useful for monitoring by consuming programs, and for issuing warnings when
    # you're close, but not over, your limit
    def used_capacity
      _clear_old_jobs
      @job_call_times.length
    end

    # removes old jobs before. used before checking capacity
    def _clear_old_jobs
      loop do
        break if (@job_call_times.length == 0) || (@job_call_times.first >= (Time.now - @per))
        @job_call_times.shift
      end
    end

    # for debugging, really
    def to_s
      <<~TO_S
               limit: #{@limit} per #{@per} seconds
          total_jobs: #{@total_jobs}
        dropped_jobs: #{@dropped_jobs}
        errored_jobs: #{@errored_jobs}
      TO_S
    end
  end
end

class TinyRl::ExceededRateLimitError < RuntimeError; end
class TinyRl::InvalidStrategyError < RuntimeError; end

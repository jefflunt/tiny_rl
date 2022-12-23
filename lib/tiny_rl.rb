require 'time'

# this class simply tracks a rate limit, the timestamps of things you want to
# limit, and allows you the check both the used capacity and whether or not the
# rate limit has been reached. there's some additional tracking of the total
# number of jobs, dropped jobs, and errored jobs, just for some simple
# accounting.
#
# Usage:
#    > rl = TinyRl.new(5, TinyRl::MINUTE, :drop)
#   => <a rate limiter that will drop method calls over a rate of 5 per minute>
#    > 10.times{ rl.track }
#    > rl.used_capacity
#   => 5
#    > rl.at_capacity?
#   => true
#
# if you use the :error strategy, then an instance of
# TinyRl::ExceededRateLimitError will be raised when you exceed the rate limit
# when calling #track.
#
# if you'd like to check the capacity of the TinyRl before taking some action,
# then check either TinyRl#at_capacity? or TinyRl#used_capacity as appropriate.
class TinyRl
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
    raise TinyRlInvalidStrategyError.new("Strategy `#{strategy.inspect}' is not one of the allowed strategies") unless STRATEGIES.include?(strategy)
    @total_jobs = 0
    @dropped_jobs = 0
    @errored_jobs = 0
    @limit = limit
    @per = per
    @strategy = strategy

    @job_call_times = []
  end

  # this method will track the timestamp of something that you want to rate
  # limit. this is generic so that you cand rate limit a bunch of things
  # collectively with a single TinyRl instance.
  #
  # for strategy :drop
  #   returns true if the job was run, false if it was dropped
  # for strategy :error
  #   returns true if the job was run, raises an exception otherwise
  def track
    @total_jobs += 1

    if at_capacity?
      case @strategy
      when :drop
        @dropped_jobs += 1
      when :error
        @errored_jobs += 1
        raise TinyRlExceededRateLimitError.new("Rate limit of #{@limit} per #{@per} sec exceeded")
      end
      false
    else
      @job_call_times << Time.now
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
      at_capacity?: #{at_capacity?}
     used_capacity: #{used_capacity}
        total_jobs: #{@total_jobs}
      dropped_jobs: #{@dropped_jobs}
      errored_jobs: #{@errored_jobs}
    TO_S
  end
end

class TinyRlExceededRateLimitError < RuntimeError; end
class TinyRlInvalidStrategyError < RuntimeError; end

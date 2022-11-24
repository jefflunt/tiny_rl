module TinyRl
  # this class represents a job to be executed by an instance or TinyRl::Exec.
  #
  # Usage:
  #   Let's say we wanted to define a job that squares the number being passed
  #   into it. Let's also assume that we define a class that prints the outcome
  #   of the job when it's run.
  #
  #   class Printer
  #     def notify(val)
  #       puts "job value: #{val}"
  #     end
  #   end
  #
  #     > printer = Printer.new
  #     > squarer = TinyRl::Job.new(->(base){ base ** 2 }, printer, 7)
  #     > squarer.exec
  #       job value: 49
  #    => true              # the job returns true after it's run
  #     > squarer.exec
  #    => false             # subsequent executions return false
  #
  # You can pass any valid Proc into the initializer for TinyRl::Job, and setup
  # its parameters. The code is only executed when the job is eventually
  # executed.
  class Job
    # procedure: the Proc to call as part of this Job
    # notify: the object to notify of the return value. NOTE: ths object must
    #   respond to #notify(val), or be `nil' you don't need to be notified
    # args: the arguments to the procedure
    def initialize(procedure, notify, *args)
      raise TinyRl::InvalidJobError.new("The procedure cannot be nil") if procedure.nil?
      raise TinyRl::InvalidJobError.new("Notify receiver does not respond to #notify") unless notify.nil? || notify.respond_to?(:notify)

      @procedure = procedure
      @notify = notify
      @args = args
      @ran = false
    end

    # executes the job with its arguments. NOTE: the job will only be executed
    # and generate a notification one time. if this method is called multiple
    # times then it will return early.
    #
    # returns true if the job was run, false if it's already been run before
    def exec
      return false if @ran

      output = @procedure.call(*@args)
      @notify.notify(output) if @notify
      @ran = true
    end
  end
end

class TinyRl::InvalidJobError < RuntimeError; end

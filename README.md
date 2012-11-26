
LSpace, named after the Discworld's [L-Space](http://en.wikipedia.org/wiki/L-Space), is a
way to maintain application context throughout a section of code.

In the old days, you'd do something like:

```ruby
def with_master_database(&block)
  Thread.local[:database_connection] = master_connection
  block.call
ensure
  Thread.local[:database_connection] = nil
end
```

This works well until you're using a framework like eventmachine, or splitting
CPU-intensive parts off into a threadpool, because your one logical section of code may
involve lots of separate stack frames.

So instead, for eventmachine, you can do:

```ruby
require 'lspace/eventmachine'
def with_master_database(&block)
  LSpace.update(:database_connection => master_connection) do
    block.call
  end
end
```

Now, when you do anything eventmachiney, like `EM::defer` or create a new connection, or
do an em-http-request, the LSpace will be preserved.

```ruby
def update_users
  with_master_database do
    EM::defer{ users.each(&:update) }
  end
end
```

How does this work?

Every time that a new connection is created, the current LSpace is stored on it, and
every time an event loop event fires, that LSpace is re-activated, along with all
its state. This also happens for each callback or errback you add to a deferrable; so when
the callback fires you'll be in the original LSpace.

Around filters
==============

In addition to just storing variables across call-stacks, LSpace allows you to wrap each
re-entry to your code with `around_filters`. This lets you do things like maintain state
in libraries like log4r that don't support LSpace.

```ruby
LSpace.around_filter do |&block|
  previous_context = Log4r::MDC.get :context
  begin
    Log4r::MDC.put :context, LSpace[:log_context]
    block.call
  ensure
    Log4r::MDC.put :context, previous_context
  end
end
```

You can also use this to log any unhandled exceptions that happen while your job is
running without hitting the eventmachine default error handler:

```ruby
LSpace.around_filter do |&block|
  begin
    block.call
  rescue => e
    puts "Got exception running #{LSpace[:job_id]}: #{e}"
  end
end
```

Integrating with new libraries
================================

There are two kinds of integration. Firstly, the simple case, where you have an API that
takes a block, and may end up running that block in a different stack frame, you should
call `.in_lspace` on that block:

```ruby
def enqueue_task(&block)
  $todo << block.in_lspace
end
```

This will ensure that the user's current LSpace is re-activated when the block is run. You
can automate this by using the `in_lspace` wrapper function at the module level:

```ruby
class Scheduler
  def enqueue_task(&block)
    $todo << block
  end
  in_lspace :enqueue_task
end
```

Secondly, if you have an object that runs callbacks at various different times, you should
store a new LSpace when the object is created, and then re-activate it before calling the
user's callbacks:

```ruby
class Job
  def initialize
    @lspace = LSpace.new
  end

  def run_internal
    LSpace.enter(@lspace) { run }
  end
end
```

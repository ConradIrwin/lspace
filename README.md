LSpace, named after the Discworld's [L-Space](http://en.wikipedia.org/wiki/L-Space), is an
implementation of dynamic scoping for Ruby.

Dynamic scope is a fancy term for a variable which changes its value depending on the
current context that your application is running in. i.e. the same function can see a
different value for a dynamically scoped variable depending on the code-path taken to
reach that function.

This is particularly useful for implementing many utility functions in applications. For
example, let's say I want to use the master database connection for some database
operations. I don't want to have to pass a reference to the database connection all the
way throughout my code, so I just push it into the LSpace:

```ruby
require 'lspace'
class DatabaseConnection
  def get_connection
    LSpace[:preferred_connection] || any_free_connection
  end

  def self.use_master(&block)
    LSpace.update(:preferred_connection => master_connection) do
      block.call
    end
  end
end

DatabaseConnection.use_master do
  very_important_transactions!
end
```

Everything that happens in the `very_important_transactions!` block will use
`LSpace[:preferred_connection]`, which is set to be the master database.

This is useful for a whole host of stuff, we use it to ensure that every line logged by a
given Http request is prefixed by a unique value, so we can tie them back together again.
We also use it for generating trees of performance metrics.

All of these concerns have one thing in common: they're not important to what your program
is trying to do, but they are important for the way your program is trying to do things.
It doesn't make sense to stuff everything into `LSpace`, though early versions of Lisp
essentialy did that, because it makes your code harder to understand.

Eventmachine
============

LSpace also comes with optional eventmachine integration. This adds a few hooks to
Eventmachine to ensure that the current LSpace is preserved, even if your code has
asynchronous callbacks; or runs things in eventmachine's threadpool:

```ruby
require 'lspace/eventmachine'
require 'em-http-request'

class Fetcher
  lspace_reader :log_prefix

  def log(str)
    puts "#{log_prefix}\t#{str}"
  end

  def fetch(url)
    log "Fetching #{url}"
    EM::HttpRequest.new(url).get.callback do
      log "Fetched #{url}"
    end
  end
end

EM::run do
  LSpace.update(:log_prefix => rand(50000)) do
    Fetcher.new.fetch("http://www.google.com")
    Fetcher.new.fetch("http://www.yahoo.com")
  end
  LSpace.update(:log_prefix => rand(50000)) do
    Fetcher.new.fetch("http://www.microsoft.com")
  end
end
```

Around filters
==============

In addition to just storing variables across call-stacks, LSpace allows you to wrap each
re-entry to your code with around filters. This lets you do things like maintain
thread-local state in libraries like log4r that don't support LSpace.

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

If you are using a Thread-pool, or an actor system, or an event loop, you will need to
teach it about LSpace in order to get the full benefit of the system.

There are two kinds of integration. Firstly, when your library accepts blocks from the
programmer's code, and proceeds to run them on a different call-stack, you should call
`Proc#in_lspace`:

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

Secondly, when your library creates objects that call out to the user's code, it's polite
to re-use the same `LSpace` across each call:

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

A new `LSpace` will by default inherit everything from its parent, so it's better to store
`LSpace.new` than `LSpace.current`, so that if the user mutates their LSpace in a
callback, the change does not propagate upwards.

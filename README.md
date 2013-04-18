LSpace, named after the Discworld's [L-Space](http://en.wikipedia.org/wiki/L-Space), is an
implementation of dynamic scoping for Ruby.

Dynamic scope
=============

Variables that are stored inside an LSpace are dynamically scoped, this means that they
take effect only for the duration of a block:

```ruby
LSpace.with(:user_id => 5) do
  LSpace[:user_id] == 5
end
LSpace[:user_id] == nil
```

You can enter a new LSpace as many times as you need, to add as much state as you need:

```ruby
LSpace.with(:user_id => 5) do
  LSpace.with(:database_shard => 7) do
    LSpace[:user_id] == 5
    LSpace[:database_shard] == 7
  end
end
```

Operation safety
================

LSpace is thread-safe, so entering a new LSpace on one thread won't affect any of the
other Threads. In addition, LSpace also comes with extensions for
[eventmachine](https://github.com/eventmachine/eventmachine) and
[celluloid](http://celluloid.io/) which extends the notion of thread-safety to
operation-safety.

This means that even if you're doing multiple things on one thread, or one thing using
many threads, the changes you make to LSpace will still be local to that thing.

```ruby
require 'lspace/eventmachine'
EM::run
  LSpace.with(:user_id => 5) do
    EM::defer{ LSpace[:user_id] == 5; EM::stop }
  end
end
```

See also [examples/eventmachine.rb](https://github.com/ConradIrwin/lspace/tree/master/examples/eventmachine.rb).


```ruby
require 'lspace/celluloid'
class Actor
  include Celluloid
  def example
    LSpace[:user_id] == 5
  end
end

LSpace.with(:user_id => 5) do
  Actor.new.example!
end
```

See also [examples/celluloid.rb](https://github.com/ConradIrwin/lspace/tree/master/examples/celluloid.rb).

`lspace_reader`
===============

Because reading from the current LSpace is the most common thing to do, you can define an
accessor function that lets you do this:

```ruby
class Task
  lspace_reader :user_id

  def process
    puts "Running #{self} for User##{user_id}"
  end
end

LSpace.with(:user_id => 7) do
  Task.new.process
end
```

Around filters
==============

The ability of LSpace to be operation-local instead of merely thread local also enables
you to add around filters to your code. Whenever your operation jumps between threads,
or fires a callback, the around filters are called so that code running in the context of
your operation is always wrapped.

This is useful for maintaining operation-local state in libraries that only support
thread-local state (like Log4r):

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
You can also use this to log any unhandled exceptions that happen while your operation is
running without hitting the default error handler for your thread-pool or event loop. This
makes tracking down the causes of unexpected exceptions much easier:

```ruby
LSpace.around_filter do |&block|
  begin
    block.call
  rescue => e
    puts "Got exception running #{LSpace[:job_id]}: #{e}"
  end
end
```

Use cases
=========

LSpace is good for the parts of your application that are not directly relevant to what
you're actually trying to do, but are important to the manner in which your application is
written.

For example, when showing a user's page, it's normally fine to use a database slave. If
the user is looking at their own page, then it's important to use a master database in
case they've just edited their profile. To implement this without LSpace you have to push
the `use_master_database` flag down through all of your page-rendering logic. With LSpace
you can make this change in a much less brittle way:

```ruby
require 'lspace'
class DatabaseConnection
  def get_connection
    LSpace[:preferred_connection] || any_free_connection
  end

  def self.use_master(&block)
    LSpace.with(:preferred_connection => master_connection) do
      block.call
    end
  end
end

DatabaseConnection.use_master do
  very_important_transactions!
end
```

Another good example is logging. We want to prefix log messages involved with handling one
particular web request with the same unique string every time, so that we can tie all of
those message together despite a large number of concurrent requests being handled.
Without LSpace this would be a nightmare, as we'd have to push the `log_prefix` down into
all parts of our code, with LSpace it becomes simple.

Because the changes to LSpace are only visible within the current operation, or current
block, it's much safer than global state; though it has many of the same benefits.

Integrating with new libraries
================================

If you are using a Thread-pool, or an actor system, or an event loop, you will need to
teach it about LSpace in order to get the correct operation-local semantics.

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

Testing
=======

If you're using `LSpace`, you probably want each test case to run in its own `LSpace` so
that tests cannot pollute each other. If you're using rspec you can do this with:

```ruby
require 'lspace/rspec'
```

If not, you'll have to add an around filter yourself.

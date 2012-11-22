*in progress*

LSpace — Safe operation-local storage.

Global variables are awesome. Unfortunately they become a bit useless when you have
multiple threads because you often want different "global" state per-thread...

Thread-local variables are even more awesome! Unfortunately they become a bit useless when
you are doing multiple things on the same thread because you often want different
"thread-local" state per operation...

Operation-local variables are most awesome!

`LSpace`, named after the Discworld's [L-Space](http://en.wikipedia.org/wiki/Other_dimensions_of_the_Discworld#L-space)
gives you effective, safe operation-local variables.

It does this by following your operation as it jumps between thread-pools, or fires
callbacks on your event-loop; and makes sure to clean up after itself so that no state
accidentally leaks.

If you're using this on EventMachine, you should be ready to rock by requiring 'lspace/eventmachine'.
If you've got your own thread-pool, or are doing something fancy, you'll need to do some
manual work.

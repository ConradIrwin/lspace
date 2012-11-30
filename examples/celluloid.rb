require 'lspace/celluloid'
module Logging
  lspace_reader :log_prefix
  def log(str)
    puts "INFO #{log_prefix}: #{str}"
  end
end
class Customer
  include Logging
  include Celluloid
  def initialize(bob)
    @bob = bob
  end

  def eat_lunch
    consume @bob.make_sandwich
  end

  def consume(sandwich)
    log "eating a #{sandwich}"
  end
end

class Caterer
  include Logging
  include Celluloid
  def make_sandwich
    choice = ["Bacon", "Lettuce", "Tomato", "Ham", "Cheese", "Pickle", "Nutella"].sample
    log "making a #{choice} sandwich"
    sleep rand
    "#{choice} sandwich"
  end
end

bob = Caterer.new

LSpace.with(:log_prefix => "Table 1") do
  Customer.new(bob).eat_lunch!
  Customer.new(bob).eat_lunch!
end
LSpace.with(:log_prefix => "Table 2") do
  Customer.new(bob).eat_lunch!
end

sleep 1

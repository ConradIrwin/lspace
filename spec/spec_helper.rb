require_relative '../lib/lspace'
RSpec.configure do |c|
  c.around(:each) do |example|
    LSpace.new do
      example.run
    end
  end
end

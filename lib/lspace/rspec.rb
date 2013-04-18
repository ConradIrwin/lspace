RSpec.configure do |c|
  c.around(:each) do |example|
    LSpace.clean do
      example.run
    end
  end
end

class << Thread
  in_lspace :new, :start, :fork
end

module Kernel
  in_lspace :fork
end

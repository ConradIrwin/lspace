#!/usr/bin/env ruby
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
  LSpace.with(:log_prefix => rand(50000)) do
    Fetcher.new.fetch("http://www.google.com")
    Fetcher.new.fetch("http://www.yahoo.com")
  end
  LSpace.with(:log_prefix => rand(50000)) do
    Fetcher.new.fetch("http://www.microsoft.com")
  end
end

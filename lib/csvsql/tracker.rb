# frozen_string_literal: true

require 'logger'

class Csvsql::Tracker
  attr_reader :stats, :logger

  def self.tracker
    @tracker ||= new
  end

  def self.tracker=(t)
    @tracker = t
  end

  def self.commit(*args, &block)
    tracker.commit(*args, &block)
  end

  def initialize(logger = Logger.new('/dev/null'))
    @stats = {}
    @logger = logger
  end

  def commit(id, output: true, &block)
    id = id.to_s
    old = stats[id]
    stats[id] = get_stat

    if block
      block.call.tap { commit(id) }
    elsif output && old
      logger.info("[#{id}] #{compare_stat(old, stats[id])}")
    end
  end

  private

  def get_stat
    { time: Time.now }
  end

  def compare_stat(old, new)
    "Time cost: #{((new[:time] - old[:time]) * 1000000).to_i / 1000}ms"
  end
end

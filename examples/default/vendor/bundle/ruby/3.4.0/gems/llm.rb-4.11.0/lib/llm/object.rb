# frozen_string_literal: true

##
# The {LLM::Object LLM::Object} class encapsulates a Hash object. It is
# similar in spirit to OpenStruct, and it was introduced after OpenStruct
# became a bundled gem rather than a default gem in Ruby 3.5.
class LLM::Object < BasicObject
  require_relative "object/builder"
  require_relative "object/kernel"

  extend Builder
  include Kernel
  include ::Enumerable
  defined?(::PP) ? include(::PP::ObjectMixin) : nil

  ##
  # @param [Hash] h
  # @return [LLM::Object]
  def initialize(h = {})
    @h = h || {}
  end

  ##
  # Yields a key|value pair to a block.
  # @yieldparam [Symbol] k
  # @yieldparam [Object] v
  # @return [void]
  def each(&)
    @h.each(&)
  end

  ##
  # @param [Symbol, #to_sym] k
  # @return [Object]
  def [](k)
    @h[key(k)]
  end

  ##
  # @param [Symbol, #to_sym] k
  # @param [Object] v
  # @return [void]
  def []=(k, v)
    @h[k.to_s] = v
  end

  ##
  # @return [String]
  def to_json(...)
    to_h.to_json(...)
  end

  ##
  # @return [Boolean]
  def empty?
    @h.empty?
  end

  ##
  # @return [Hash]
  def to_h
    @h.dup
  end

  ##
  # @return [Hash]
  def to_hash
    @h.transform_keys(&:to_sym)
  end

  ##
  # @return [Array<String>]
  def keys
    @h.keys
  end

  ##
  # @return [Array]
  def values
    @h.values
  end

  ##
  # @param [String, Symbol] k
  # @return [Boolean]
  def key?(k)
    @h.key?(key(k))
  end
  alias_method :has_key?, :key?

  ##
  # @param [String, Symbol] k
  # @return [Object]
  def fetch(k, *args, &b)
    @h.fetch(key(k), *args, &b)
  end

  ##
  # @return [Integer]
  def size
    @h.size
  end
  alias_method :length, :size

  ##
  # @yieldparam [String, Object]
  def each_pair(&)
    @h.each(&)
  end

  ##
  # @return [Object, nil]
  def dig(...)
    @h.dig(...)
  end

  ##
  # @return [Hash]
  def slice(...)
    @h.slice(...)
  end

  private

  def method_missing(m, *args, &b)
    if m.to_s.end_with?("=")
      self[m[0..-2]] = args.first
    elsif k = key(m)
      @h[k]
    else
      nil
    end
  end

  def key(k)
    if @h.key?(k.to_s)
      k.to_s
    elsif @h.key?(k.to_sym)
      k.to_sym
    else
      nil
    end
  end
end

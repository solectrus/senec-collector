# To not depend on ActiveSupport, we copy the following methods from ActiveSupport:
# https://github.com/rails/rails/blob/v7.1.3/activesupport/lib/active_support/core_ext/object/blank.rb

class Object
  def blank?
    respond_to?(:empty?) ? !!empty? : !self
  end

  def present?
    !blank?
  end

  def presence
    self if present?
  end
end

class String
  BLANK_RE = /\A[[:space:]]*\z/

  def blank?
    empty? || BLANK_RE.match?(self)
  end
end

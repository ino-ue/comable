require 'devise'
require 'enumerize'
require 'state_machine'
require 'ancestry'
require 'acts_as_list'
require 'carrierwave'
require 'cancancan'
require 'comma'
require 'axlsx_rails'
require 'roo'

require 'comable/core/configuration'
require 'comable/core/engine'

require 'comable/payment_provider'
require 'comable/state_machine_patch'
require 'comable/deprecator'

require 'comma_extractor_extentions'

module Comable
  class << self
    def setup(&_)
      yield Comable::Config
    end

    def translate(key, options = {})
      I18n.translate("comable.#{key}", options)
    end

    alias_method :t, :translate
  end
end

# Rails 4.1.0.rc1 and StateMachine don't play nice
# https://github.com/pluginaweek/state_machine/issues/295

require 'state_machine/version'

if StateMachine::VERSION != '1.2.0'
  # If you see this message, please test removing this file
  # If it's still required, please bump up the version above
  Rails.logger.warn 'Please remove me, StateMachine version has changed'
end

if Rails.version =~ /^4.1./
  module StateMachine::Integrations::ActiveModel
    public :around_validation
  end
end
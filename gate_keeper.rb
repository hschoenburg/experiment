module Experiment
  class GateKeeper
    # note this will break at 800 million users
    class InvalidGate < RuntimeError; end
    class InvalidUser < RuntimeError; end
    class MissingGateKey < RuntimeError; end

    attr_reader :gate, :user

    def initialize(gate:, user:)
      raise InvalidGate unless gate.respond_to?(:to_str)
      raise InvalidUser unless user.is_a?(User)
      raise InvalidGate unless !GATE_KEEPER_GATES_AND_SCOPES_AND_WEIGHTS[gate].nil?
      initialize_gate(gate)
      @gate = gate
      @user = user
    end

    def experiment?
      cohort! == :experiment
    end

    def control?
      cohort! == :control
    end

    def cohort!
      @cohort ||= GateConfig.new(gate: gate, user: user).cohort!
    end

    private

    def initialize_gate(gate)
      $redis.with do |conn|
        conn.setbit(gate, 0, 0) unless conn.exists(gate)
      end
    end
  end
end

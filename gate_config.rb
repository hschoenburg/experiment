module Experiment
  class GateConfig

    ARRIVED = 0
    SCOPE = 1
    EXPERIMENT = 2
    GROUP_A = 3
    GROUP_B = 4
    GROUP_C = 5
    TOTAL_OFFSET = 6

    attr_reader :gate, :user, :scope, :parsed_config

    def self.stats_for_user(user:)
      GATE_KEEPER_GATES_AND_SCOPES_AND_WEIGHTS.keys.map do |key|
        config = new(gate: key, user: user)
        config.cohort_name
      end.compact.join(',')
    end

    def initialize(gate:, user:)
      @gate = gate
      @user = user
      @scope = GATE_KEEPER_GATES_AND_SCOPES_AND_WEIGHTS[gate][:scope]
      @parsed_config = get_config_for_user
    end

    def cohort_name
      if parsed_config[:scope]
        parsed_config[:experiment] ? "#{gate}:experiment" : "#{gate}:control"
      end
    end

    def cohort!
      assign_to_cohorts if !arrived?
      case
      when !in_scope?
        :not_in_scope
      when in_experiment?
        :experiment
      else
        :control
      end
    end

    private

    def in_experiment?
      parsed_config[:experiment]
    end

    def arrived?
      parsed_config[:arrived]
    end

    def in_scope?
      parsed_config[:scope]
    end

    def assign_to_cohorts
      assigner = Assigner.new(gate: gate, scope: scope, user: user)
      range = assigner.build_range_for_new_user
      set_range_for_user(range)
      @parsed_config = parse_config_from_range(range)
    end

    def get_config_for_user
      range =
        $redis.with do |conn|
          conn.getrange(gate, user_key_start, user_key_end)
        end
      parse_config_from_range(range)
    end

    def parse_config_from_range(range)
      {
        arrived:    range[ARRIVED] == "1",
        scope:      range[SCOPE] == "1",
        experiment: range[EXPERIMENT] == "1",
        group_a:    range[GROUP_A] == "1",
        group_b:    range[GROUP_B] == "1",
        group_c:    range[GROUP_C] == "1"
      }
    end

    def set_range_for_user(range)
      $redis.with do |conn|
        conn.setrange(gate, user_key_start, range)
      end
    end

    def user_key_start
      user.id * TOTAL_OFFSET
    end

    def user_key_end
      user_key_start + TOTAL_OFFSET
    end
  end
end

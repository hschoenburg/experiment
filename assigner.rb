module Experiment
  class Assigner
    attr_reader :gate, :scope, :user, :settings

    def initialize(gate:, scope:, user:)
      @gate = gate
      @scope = scope
      @user = user
      @settings = GATE_KEEPER_GATES_AND_SCOPES_AND_WEIGHTS[gate]
    end

    def build_range_for_new_user
      if scope.exists?(user.id)
        in_scope = 1
        in_experiment = segment_user_for_experiment
        groups = segment_user_for_groups
      else
        in_scope = 0
        in_experiment = 0
        groups = [0,0,0]
      end
      {
        arrived: 1,
        scope: in_scope,
        experiment: in_experiment,
        group_a: groups[0],
        group_b: groups[1],
        group_c: groups[2]
      }.values.join()
    end

    private

    def segment_user_for_groups
      #for later more complicated experiments
      [0,0,0]
    end

    def segment_user_for_experiment
      rand(100) < settings[:weights][:experiment] ? 1 : 0
    end
  end
end

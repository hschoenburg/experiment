require 'rails_helper'

describe Experiment::GateConfig do
  let(:user)  { FactoryGirl.create(:user) }
  let(:gate)  { 'test_experiment' }
  let(:gate_two) { 'super_test_experiment' }
  let(:scope) { User.where(lapsed_at: nil) }
  let(:experimental_weight) { 50 }

  let(:gates_and_scopes_and_weights) do
    {
      gate => {
        scope: scope,
        weights: {
          experiment: experimental_weight,
          experimental_groups: false
        }
      },
      gate_two => {
        scope: scope,
        weights: {
          experiment: experimental_weight,
          experimental_groups: false
        }
      }
    }
  end

  before do
    stub_const(
      "GATE_KEEPER_GATES_AND_SCOPES_AND_WEIGHTS",
      gates_and_scopes_and_weights
    )
  end

  describe '.stats_for_user' do
    def user_stats
      described_class.stats_for_user(user: user)
    end

    subject { described_class.stats_for_user(user: user) }

    context 'not having entered any experiments' do
      it 'returns an empty array' do
        expect(user_stats).to eq('')
      end
    end

    context 'having entered an experiment' do
      it 'looks up and recalls user cohort for a given gate' do
        cohort = Experiment::GateKeeper.new(gate: gate, user: user).cohort!

        expect(user_stats).to eq("#{gate}:#{cohort}")
      end
    end

    context 'having entered multiple experiments' do
      it 'looks up and recalls user cohort for a given gate' do
        cohort = Experiment::GateKeeper.new(gate: gate, user: user).cohort!
        cohort_two = Experiment::GateKeeper.new(
          gate: gate_two,
          user: user
        ).cohort!
        expect(user_stats).to(
          eq("#{gate}:#{cohort},#{gate_two}:#{cohort_two}")
        )
      end
    end
  end
end

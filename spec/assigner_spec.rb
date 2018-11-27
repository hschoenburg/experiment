require 'rails_helper'

describe Experiment::Assigner do
  let(:user) { FactoryGirl.create(:user) }

  before do
    stub_const(
      'GATE_KEEPER_GATES_AND_SCOPES_AND_WEIGHTS',
      { 'test_experiment' => {
        gate: 'test',
        weights: { experiment: 100 }
      } }
    )
  end

  describe '#build_range_for_new_user' do
    subject do
      described_class.
        new(gate: 'test_experiment', scope: scope, user: user).
        build_range_for_new_user
    end

    context 'when the user is not in scope' do
      let(:scope) { User.where('id <> ?', user.id) }

      it 'returns arrived but out of scope and not in experiment' do
        expect(subject).to eq("100000")
      end
    end

    context 'when the user is in scope' do
      let(:scope) { User.where(id: user.id) }

      context 'when the user is assigned to the experimental group' do
        let(:percent_in_experiment) { 100 }

        it 'returns arrived in scope and in experiment' do
          expect(subject).to eq("111000")
        end
      end

      context 'when the user is assigned to the experimental group' do
        before do
          stub_const(
            'GATE_KEEPER_GATES_AND_SCOPES_AND_WEIGHTS',
            { 'test_experiment' => {
              gate: 'test',
              weights: { experiment: 0 }
            } }
          )
        end

        it 'returns arrived, in scope and not in experiment' do
          expect(subject).to eq("110000")
        end
      end
    end
  end
end

require 'rails_helper'

describe Experiment::GateKeeper do

  let(:user)  { FactoryGirl.create(:user) }
  let(:gate)  { 'test_experiment' }
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
      }
    }
  end

  before do
    stub_const("GATE_KEEPER_GATES_AND_SCOPES_AND_WEIGHTS", gates_and_scopes_and_weights)
  end

  describe 'instantiation' do

    let(:gates_and_scopes) do
      {
        gate => scope,
        'broken_gate' => []
      }
    end

    it 'raises if gate doesnt match those setup on initialization' do
      expect {
        described_class.new(
          gate: 'not a real gate',
          user: user
        )
      }.to raise_error(described_class::InvalidGate)
    end

    it 'raises if provided user quacks wrongly' do
      expect {
        described_class.new(
          gate: gate,
          user: 456
        )
      }.to raise_error(described_class::InvalidUser)
    end

    it 'creates a new key in redis if not present' do
      $redis.with { |conn| conn.del(gate) }
      described_class.new(
        gate: gate,
        user: user
      )
      new_key_set = $redis.with { |conn| conn.exists(gate) }
      expect(new_key_set).to eq(true)
    end
  end

  describe '#cohort!' do
    subject(:gate_keeper) {
      described_class.new(
        gate: gate,
        user: user
      )
    }

    context 'arriving for the first time' do

      context 'with a user not in scope' do
        let!(:scope) { User.where("email != ?", user.email) }

        it "returns 'not_in_scope'" do
          expect(gate_keeper.cohort!).to eq(:not_in_scope)
        end

        context 'returning for a second time, now in scope' do

          it 'retains the not_in_scope' do
            orig_cohort = gate_keeper.cohort!
            expect(orig_cohort).to eq(:not_in_scope)
            user.update!(email: 'somethingelse@heythere.com')
            expect(scope.exists?(user.reload.id)).to eq(true)
            new_cohort = gate_keeper.cohort!
            expect(new_cohort).to eq(orig_cohort)
          end
        end
      end

      context 'with a user in scope' do
        let(:scope) { User.where(lapsed_at: nil) }

        it "returns symbols :experiment or :control" do
          expect(scope.exists?(user.id)).to eq(true)
          expect([:experiment,:control].include?(gate_keeper.cohort!)).to eq(true)
        end

        context 'with experimental_weight set to 100' do
          let(:experimental_weight) { 100 }

          it 'always returns :experiment' do
            3.times do
              expect(
                described_class.new(
                  gate: gate,
                  user: FactoryGirl.create(:user)
                ).cohort!
              ).to eq(:experiment)
            end
          end
        end

        it 'does not reassign cohort after first visit' do
          cohort = gate_keeper.cohort!
          5.times do
            expect(gate_keeper.cohort!).to eq(cohort)
          end
        end

        context 'when was in scope but is not longer' do
          let(:scope) { User.where("first_name != 'hans'") }

          it 'never changes the original scope setting' do
            orig_cohort = gate_keeper.cohort!
            expect(scope.exists?(user.id)).to eq(true)

            user.update!(first_name: 'hans')
            expect(scope.exists?(user.reload.id)).to eq(false)
            new_cohort = gate_keeper.cohort!

            expect(new_cohort).to eq(orig_cohort)
          end
        end
      end
    end
  end

  describe '#cohort! with adjacent users' do
    let(:second_user) { FactoryGirl.create(:user) }

    let(:first_gate_keeper) {
      described_class.new(
        gate: gate,
        user: user
      )
    }

    let(:second_gate_keeper) {
      described_class.new(
        gate: gate,
        user: second_user
      )
    }

    let(:scope) { User.where(lapsed_at: nil) }

    it 'assigns and remembers each users appropriate configs idempotently' do
      second_user.update!(lapsed_at: Time.current)

      first_user_cohort = first_gate_keeper.cohort!
      second_user_cohort = second_gate_keeper.cohort!

      expect(first_user_cohort).not_to eq(:not_in_scope)
      expect(second_user_cohort).to eq(:not_in_scope)

      expect(first_user_cohort).to(
        eq(described_class.new(gate: gate, user: user).cohort!)
      )

      expect(second_user_cohort).to(
        eq(described_class.new(gate: gate, user: second_user).cohort!)
      )

    end
  end
end


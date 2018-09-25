require 'rails_helper'

RSpec.describe BalanceActivity, type: :model do

  describe "associations" do
    it "belongs_to account" do
      ba_belongs_to_account_helper
    end
    it "polymorphic belongs_to itemable" do
      ba_belongs_to_itemable_helper
    end
    it "itemable is optional" do
      ba_belongs_to_itemable_isnt_needed_helper
    end
  end

  describe "validations" do
    describe "valid" do
      it "should be valid" do
        ba_should_be_valid_helper
      end
    end
    describe "presence" do
      it "for required fields when deposit" do
        fields = %w(transaction_hash account_id activity_type amount
                    credit_or_debit block_number gas_used transaction_status
                    confirmation_status)
        options = { field: "activity_type", value: "deposit" }
        common_validates_presence_for_fields_helper(:balance_activity, fields,
                                                    options)
      end
      it "for required fields" do
        fields = %w(account_id activity_type amount credit_or_debit)
        options = { field: "activity_type", value: "charge" }
        common_validates_presence_for_fields_helper(:balance_activity, fields,
                                                    options)
      end
    end
    describe "uniqueness" do
      it "transaction_hash" do
        ba_validates_uniqueness_transaction_hash_helper
      end
      it "transaction_hash allows blank" do
        ba_validates_uniqueness_transaction_hash_allows_blank_helper
      end
    end
    describe "numbericality" do
      it "block_number greater than 0 if a deposit" do
        ba_block_number_greater_than_0_helper
      end
      it "not block_number greater than 0 if not a deposit" do
        ba_block_doesnt_check_for_number_greater_than_0_helper
      end
    end
  end

  describe "enums" do
    it "allows correct options for" do
      enums_with_values = [
        { activity_type: [:deposit, :charge] },
        { credit_or_debit: [:credit, :debit] },
        { transaction_status: [:revert, :success] },
        { confirmation_status: [:pending, :confirmed, :failed] }
      ]
      common_confirm_enums_with_values_helper(:balance_activity, enums_with_values)
    end
  end

  describe "scopes" do
    describe "calls correct methods for" do
      it "deposits" do
        ba_scopes_deposits_helper
      end
      it "valid" do
        ba_scopes_valid_helper
      end
      it "valid_deposits" do
        ba_scopes_valid_deposits_helper
      end
    end
  end

  describe ".create_charge_ba_and_charge_account_for_goal_fail" do
    it "creates a ba with correct data" do
      ba_create_charge_ba_creates_ba_helper
    end
    it "updates account with new balance and returns response from update" do
      ba_updates_account_balance_and_returns_response_helper
    end
  end

  describe "#update_if_confirmed" do
    it "when confirmed calls and returns update with correct params" do
      ba_update_if_confirmed_calls_update_helper
    end
    it "when not confirmed does not call and return update" do
      ba_update_if_confirmed_does_not_call_update_helper
    end
    it "updates new and old balance with correct values when success" do
      ba_update_if_confirmed_updates_balances_helper
    end
    it "doesnt update new and old balance when fail" do
      ba_update_if_confirmed_does_not_update_balances_helper
    end
  end

  describe ".create_deposit" do
    it "calls create with correct values" do
      ba_create_deposit_calls_create_helper
    end
    it "calls update_if_confirmed with correct params" do
      ba_create_deposit_calls_update_if_confirmed_helper
    end
    it "returns deposit" do
      ba_create_deposit_returns_deposit_helper
    end
  end

  describe ".create_or_update_deposit" do
    it "calls find_by with correct filter" do
      ba_create_or_update_deposit_calls_find_by_helper
    end
    it "calls update_if_confirmed if deposit found" do
      ba_create_or_update_deposit_calls_update_if_confirmed_helper
    end
    it "doesnt call update_if_confirmed if no deposit found" do
      ba_create_or_update_deposit_doesnt_call_update_if_confirmed_helper
    end
    it "calls create_deposit if no deposit found" do
      ba_create_or_update_deposit_calls_create_deposit_helper
    end
    it "doesnt call create_deposit if deposit found" do
      ba_create_or_update_deposit_doesnt_call_create_deposit_helper
    end
    it "returns newly created deposit when no deposit found" do
      ba_create_or_update_deposit_returns_new_deposit_helper
    end
    it "returns updated deposit when deposit found" do
      ba_create_or_update_deposit_returns_new_deposit_helper
    end
  end

  describe ".txn_is_already_confirmed?" do
    it "calls and returns find_by with correct params" do
      ba_txn_is_already_confirmed_helper
    end
  end

  describe ".update_account_balance_if_should" do
    it "calls and returns update! with correct params when valid" do
      ba_update_account_balance_if_should_updates_helper
    end
    it "doesnt call update! with correct params when not confirmed" do
      ba_update_account_balance_if_should_doesnt_update_confirmed_helper
    end
    it "doesnt call update! with correct params when not success" do
      ba_update_account_balance_if_should_doesnt_update_success_helper
    end
  end

  describe ".create_or_update_deposit_and_account" do
    it "calls .txn_is_already_confirmed" do
      ba_create_or_update_dep_and_acc_calls_tx_is_confirmed_helper
    end
    it "returns nil and doesn't call other methods if txn already confirmed" do
      ba_create_or_update_dep_and_acc_returns_nil_if_confirmed_helper
    end
    it "calls find_or_create_account when not confirmed" do
      ba_create_or_update_dep_and_acc_calls_find_or_create_account_helper
    end
    it "doesnt call find_or_create_account when confirmed" do
      ba_create_or_update_dep_and_acc_doesnt_call_find_or_create_account_helper
    end
    it "calls create_or_update_deposit with correct data when not confirmed" do
      ba_create_or_update_dep_and_acc_calls_create_or_update_deposit_helper
    end
    it "doesnt call create_or_update_deposit when confirmed" do
      ba_create_or_update_dep_and_acc_calls_create_or_update_deposit_helper
    end
    it "calls and returns update_account_balance when not confirmed" do
      ba_create_or_update_dep_and_acc_calls_calls_update_account_balance_helper
    end
    it "doesnt call update_account_balance when not confirmed" do
      ba_create_or_update_dep_and_acc_calls_doesnt_call_update_account_balance_helper
    end
  end

  describe ".get_from_block" do
    it "calls where with correct filter then order and last" do
      ba_get_from_block_returns_correct_deposit_helper
    end
    it "returns correct block number if deposit found" do
      ba_get_from_block_returns_correct_block_number_helper
    end
    it "returns 0 if no deposit found" do
      ba_get_from_block_returns_0_helper
    end
  end

  describe ".update_deposits_from_logs" do
    it "calls .get_from_block" do
      ba_update_deposits_from_logs_calls_get_from_block_helper
    end
    it "calls get_logs with correct args" do
      ba_update_deposits_from_logs_calls_get_logs_helper
    end
    it "calls create_or_update_deposit_and_account for each log" do
      ba_update_deposits_from_logs_calls_create_or_udpate_helper
    end
  end
end

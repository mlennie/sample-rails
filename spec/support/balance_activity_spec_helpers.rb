module BalanceActivitySpecHelpers
  ##################################################
  # ASSOCIATIONS
  ##################################################
  def ba_belongs_to_itemable_helper
    account = create(:account)
    goal = create(:goal, account: account)
    expect(goal).to_not be_nil
    ba = create(:balance_activity, account: account, itemable: goal)
    expect(ba.itemable).to eq(goal)
  end
  def ba_belongs_to_itemable_isnt_needed_helper
    ba = build(:balance_activity)
    expect(ba.valid?).to eq(true)
  end
  def ba_belongs_to_account_helper
    expect(Account.count).to eq(0)
    ba = create(:balance_activity)
    expect(Account.count).to eq(1)
    expect(ba.account).to eq(Account.first)
  end

  ##################################################
  # VALIDATIONS
  ##################################################
  def ba_should_be_valid_helper
    expect(build(:balance_activity).valid?).to be true
  end
  def ba_validates_uniqueness_transaction_hash_allows_blank_helper
    ba_1 = create(:balance_activity, transaction_hash: nil, activity_type: "charge")
    expect(ba_1[:id]).to_not be false
    ba = build(:balance_activity, transaction_hash: nil, activity_type: "charge")
    expect(ba.valid?).to be true
  end
  def ba_validates_uniqueness_transaction_hash_helper
    create(:balance_activity, transaction_hash: "0xabc")
    ba = build(:balance_activity, transaction_hash: "0xabc")
    expect(ba.valid?).to be false
    ba.transaction_hash = "0xabcd"
    expect(ba.valid?).to be true
  end
  def ba_block_doesnt_check_for_number_greater_than_0_helper
    ba = build(:balance_activity, block_number: 0, activity_type: "charge")
    expect(ba.valid?).to be true
  end
  def ba_block_number_greater_than_0_helper
    ba = build(:balance_activity, block_number: 0, activity_type: "deposit")
    expect(ba.valid?).to be false
  end
  ##################################################
  # SCOPES
  ##################################################
  def ba_scopes_valid_deposits_helper
    # invalid
    create(:balance_activity, transaction_status: "revert",
                     confirmation_status: "pending")
    # success
    create(:balance_activity, transaction_status: "success",
                     confirmation_status: "pending")
    # confirmed
    create(:balance_activity, transaction_status: "revert",
                     confirmation_status: "confirmed")
    # valid
    create(:balance_activity, transaction_status: "success",
                     confirmation_status: "confirmed", activity_type: "charge")
    valid_deposit = create(:balance_activity, transaction_status: "success",
                     confirmation_status: "confirmed", activity_type: "deposit")


    result = BalanceActivity.valid_deposits
    expect(result.count).to eq(1)
    expect(result.first).to eq(valid_deposit)
  end
  def ba_scopes_valid_helper
    # invalid
    create(:balance_activity, transaction_status: "revert",
                     confirmation_status: "pending")
    # success
    create(:balance_activity, transaction_status: "success",
                     confirmation_status: "pending")
    # confirmed
    create(:balance_activity, transaction_status: "revert",
                     confirmation_status: "confirmed")
    valid = create(:balance_activity, transaction_status: "success",
                     confirmation_status: "confirmed")

    result = BalanceActivity.valid
    expect(result.count).to eq(1)
    expect(result.first).to eq(valid)
  end

  def ba_scopes_deposits_helper
    deposit = create(:balance_activity, activity_type: "deposit")
    create(:balance_activity, activity_type: "charge")
    result = BalanceActivity.deposits
    expect(result.count).to eq(1)
    expect(result.first).to eq(deposit)
  end
  ##################################################
  # .CREATE_CHARGE_BA_AND_CHARGE_ACCOUNT_FOR_GOAL_FAIL
  ##################################################
  def ba_updates_account_balance_and_returns_response_helper
    account = create(:account, balance: 300)
    goal = create(:goal, amount: 100, account: account)
    result = BalanceActivity.create_charge_ba_and_charge_account_for_goal_fail(goal)
    account.reload
    expect(account[:balance]).to eq(200)
    expect(result).to be true
  end
  def ba_create_charge_ba_creates_ba_helper
    account = create(:account, balance: 100)
    goal = create(:goal, amount: 10, account: account)
    expect(BalanceActivity.count).to eq(0)
    BalanceActivity.create_charge_ba_and_charge_account_for_goal_fail(goal)
    expect(BalanceActivity.count).to eq(1)
    ba = BalanceActivity.first
    expect(ba[:account_id]).to eq(account[:id])
    expect(ba[:activity_type]).to eq("charge")
    expect(ba[:amount]).to eq(10.0)
    expect(ba[:new_balance]).to eq(100 - ba[:amount])
    expect(ba[:old_balance]).to eq(100)
    expect(ba[:credit_or_debit]).to eq("debit")
    expect(ba.itemable).to eq(goal)
  end

  ##################################################
  # .UPDATE_DEPOSITS_FROM_LOGS
  ##################################################
  def ba_update_deposits_from_logs_stubs_helper
    allow(BalanceActivity).to receive(:get_from_block).and_return(5)
    allow(Contract).to receive(:get_logs).and_return(["log"])
    allow(BalanceActivity).to receive(:create_or_update_deposit_and_account)
  end
  def ba_update_deposits_from_logs_calls_create_or_udpate_helper
    ba_update_deposits_from_logs_stubs_helper
    expect(BalanceActivity).to receive(:create_or_update_deposit_and_account)
                           .with("log")
    BalanceActivity.update_deposits_from_logs
  end
  def ba_update_deposits_from_logs_calls_get_from_block_helper
    ba_update_deposits_from_logs_stubs_helper
    expect(BalanceActivity).to receive(:get_from_block)
    BalanceActivity.update_deposits_from_logs
  end
  def ba_update_deposits_from_logs_calls_get_logs_helper
    ba_update_deposits_from_logs_stubs_helper
    expect(Contract).to receive(:get_logs).with({from_block: 5})
    BalanceActivity.update_deposits_from_logs
  end

  ##################################################
  # .GET_FROM_BLOCK
  ##################################################
  def ba_get_from_block_stubs_helper
    create(:balance_activity, activity_type: "charge")
    create(:balance_activity, confirmation_status: "pending")
    create(:balance_activity, activity_type: "deposit",
                              confirmation_status: "confirmed",
                              block_number: 4)
    create(:balance_activity, activity_type: "deposit",
                              confirmation_status: "confirmed",
                              block_number: 2)
  end
  def ba_get_from_block_returns_0_helper
    create(:balance_activity, activity_type: "charge")
    create(:balance_activity, confirmation_status: "pending")
    result = BalanceActivity.get_from_block
    expect(result).to eq("0x0")
  end
  def ba_get_from_block_returns_correct_block_number_helper
    ba_get_from_block_stubs_helper
    result = BalanceActivity.get_from_block
    expect(result).to eq("0x5")
  end
  def ba_get_from_block_returns_correct_deposit_helper
    ba_get_from_block_stubs_helper
    filter = {
      activity_type: "deposit",
      confirmation_status: "confirmed"
    }

    balance_activities = BalanceActivity.where(filter)
    other_balance_activities = BalanceActivity.where(filter)
    expect(BalanceActivity).to receive(:where).with(filter)
                           .and_return(balance_activities)
    expect(balance_activities).to receive(:order).with('block_number ASC')
                              .and_return(other_balance_activities)
    expect(other_balance_activities).to receive(:last)

    BalanceActivity.get_from_block
  end

  ##################################################
  # .CREATE_OR_UPDATE_DEPOSIT_AND_ACCOUNT
  ##################################################
  def ba_create_or_update_dep_and_acc_stubs_helper(options={})
    confirmed = options[:confirmed] || false
    allow(BalanceActivity).to receive(:txn_is_already_confirmed?)
                          .and_return(confirmed)
    allow(Account).to receive(:find_or_create_account).and_return("account")
    allow(BalanceActivity).to receive(:create_or_update_deposit)
                          .and_return("deposit")
    allow(BalanceActivity).to receive(:update_account_balance_if_should)
                          .and_return("result")
  end
  def ba_create_or_update_dep_and_acc_calls_doesnt_call_update_account_balance_helper
    ba_create_or_update_dep_and_acc_stubs_helper(confirmed: true)
    log = { transaction_hash: "txn" }
    expect(BalanceActivity).not_to receive(:update_account_balance_if_should)
    result = BalanceActivity.create_or_update_deposit_and_account(log)
    expect(result).to eq(nil)
  end
  def ba_create_or_update_dep_and_acc_calls_calls_update_account_balance_helper
    ba_create_or_update_dep_and_acc_stubs_helper(confirmed: false)
    log = { transaction_hash: "txn" }
    expect(BalanceActivity).to receive(:update_account_balance_if_should)
                           .with("deposit", "account")
    result = BalanceActivity.create_or_update_deposit_and_account(log)
    expect(result).to eq("result")
  end
  def ba_create_or_update_dep_and_acc_calls_create_or_update_deposit_helper
    ba_create_or_update_dep_and_acc_stubs_helper(confirmed: true)
    log = { transaction_hash: "txn" }
    expect(BalanceActivity).not_to receive(:create_or_update_deposit)
    result = BalanceActivity.create_or_update_deposit_and_account(log)
    expect(result).to eq(nil)
  end
  def ba_create_or_update_dep_and_acc_calls_create_or_update_deposit_helper
    ba_create_or_update_dep_and_acc_stubs_helper(confirmed: false)
    log = { transaction_hash: "txn" }
    expect(BalanceActivity).to receive(:create_or_update_deposit)
                           .with(log, "account")
    result = BalanceActivity.create_or_update_deposit_and_account(log)
    expect(result).to eq("result")
  end
  def ba_create_or_update_dep_and_acc_doesnt_call_find_or_create_account_helper
    ba_create_or_update_dep_and_acc_stubs_helper(confirmed: true)
    log = { transaction_hash: "txn" }
    expect(Account).not_to receive(:find_or_create_account)
    result = BalanceActivity.create_or_update_deposit_and_account(log)
    expect(result).to eq(nil)
  end
  def ba_create_or_update_dep_and_acc_calls_find_or_create_account_helper
    ba_create_or_update_dep_and_acc_stubs_helper(confirmed: false)
    log = { transaction_hash: "txn" }
    expect(Account).to receive(:find_or_create_account).with(log)
    result = BalanceActivity.create_or_update_deposit_and_account(log)
    expect(result).to eq("result")
  end
  def ba_create_or_update_dep_and_acc_returns_nil_if_confirmed_helper
    ba_create_or_update_dep_and_acc_stubs_helper(confirmed: true)
    log = { transaction_hash: "txn" }
    expect(Account).not_to receive(:find_or_create_account)
    result = BalanceActivity.create_or_update_deposit_and_account(log)
    expect(result).to eq(nil)
  end
  def ba_create_or_update_dep_and_acc_calls_tx_is_confirmed_helper
    ba_create_or_update_dep_and_acc_stubs_helper(confirmed: false)
    log = { transaction_hash: "txn" }
    expect(BalanceActivity).to receive(:txn_is_already_confirmed?)
                           .with(log[:transaction_hash])
    result = BalanceActivity.create_or_update_deposit_and_account(log)
    expect(result).to eq("result")
  end

  ##################################################
  # .UPDATE_ACCOUNT_BALANCE_IF_SHOULD
  ##################################################
  def ba_update_account_balance_if_should_doesnt_update_success_helper
    ba_data = {
      transaction_status: "revert",
      confirmation_status: "confirmed",
      new_balance: 2
    }
    deposit = create(:balance_activity, ba_data)
    account = deposit.account
    expect(account).not_to receive(:update!)
    result = BalanceActivity.update_account_balance_if_should(deposit, account)
    expect(result).to be nil
  end
  def ba_update_account_balance_if_should_doesnt_update_confirmed_helper
    ba_data = {
      transaction_status: "success",
      confirmation_status: "pending",
      new_balance: 2
    }
    deposit = create(:balance_activity, ba_data)
    account = deposit.account
    expect(account).not_to receive(:update!)
    result = BalanceActivity.update_account_balance_if_should(deposit, account)
    expect(result).to be nil
  end
  def ba_update_account_balance_if_should_updates_helper
    ba_data = {
      transaction_status: "success",
      confirmation_status: "confirmed",
      new_balance: 2
    }
    deposit = create(:balance_activity, ba_data)
    account = deposit.account
    expect(account).to receive(:update!).with(balance: 2).and_return(true)
    result = BalanceActivity.update_account_balance_if_should(deposit, account)
    expect(result).to be true
  end

  ##################################################
  # .TXN_IS_ALREADY_CONFIRMED?
  ##################################################
  def ba_txn_is_already_confirmed_helper
    params = {
      transaction_hash: "txn_hash",
      "confirmation_status": "confirmed"
    }
    expect(BalanceActivity).to receive(:find_by).with(params).and_return("result")
    result = BalanceActivity.txn_is_already_confirmed?("txn_hash")
    expect(result).to eq("result")
  end

  ##################################################
  # .CREATE_OR_UPDATE_DEPOSIT
  ##################################################
  def ba_create_or_update_deposit_stubs_helper(options={})
    log = { transaction_hash: "txn" }
    account = { balance: "balance" }
    allow(BalanceActivity).to receive(:create_deposit).and_return("deposit")
    return log, account
  end
  def ba_create_or_update_deposit_returns_new_deposit_helper
    log, account = ba_create_or_update_deposit_stubs_helper
    expect(BalanceActivity.count).to eq(0)
    deposit = create(:balance_activity, transaction_hash: log[:transaction_hash])
    expect(BalanceActivity.count).to eq(1)
    result = BalanceActivity.create_or_update_deposit(log, account)
    expect(result).to eq(deposit)
  end
  def ba_create_or_update_deposit_returns_new_deposit_helper
    log, account = ba_create_or_update_deposit_stubs_helper
    expect(BalanceActivity).to receive(:create_deposit)
    result = BalanceActivity.create_or_update_deposit(log, account)
    expect(result).to eq("deposit")
  end
  def ba_create_or_update_deposit_doesnt_call_create_deposit_helper
    log, account = ba_create_or_update_deposit_stubs_helper
    expect(BalanceActivity.count).to eq(0)
    create(:balance_activity, transaction_hash: log[:transaction_hash])
    expect(BalanceActivity.count).to eq(1)
    expect(BalanceActivity).not_to receive(:create_deposit)
    BalanceActivity.create_or_update_deposit(log, account)
  end
  def ba_create_or_update_deposit_calls_create_deposit_helper
    log, account = ba_create_or_update_deposit_stubs_helper
    expect(BalanceActivity).to receive(:create_deposit)
    BalanceActivity.create_or_update_deposit(log, account)
  end
  def ba_create_or_update_deposit_doesnt_call_update_if_confirmed_helper
    log, account = ba_create_or_update_deposit_stubs_helper
    expect_any_instance_of(BalanceActivity).not_to receive(:update_if_confirmed)
    BalanceActivity.create_or_update_deposit(log, account)
  end
  def ba_create_or_update_deposit_calls_update_if_confirmed_helper
    log, account = ba_create_or_update_deposit_stubs_helper
    expect(BalanceActivity.count).to eq(0)
    create(:balance_activity, transaction_hash: log[:transaction_hash])
    expect(BalanceActivity.count).to eq(1)
    expect_any_instance_of(BalanceActivity).to receive(:update_if_confirmed)
      .with(log, account[:balance])
    BalanceActivity.create_or_update_deposit(log, account)
  end
  def ba_create_or_update_deposit_calls_find_by_helper
    log, account = ba_create_or_update_deposit_stubs_helper
    find_by_params = { transaction_hash: log[:transaction_hash] }
    expect(BalanceActivity).to receive(:find_by).with(find_by_params)
    BalanceActivity.create_or_update_deposit(log, account)
  end

  ##################################################
  # .create_deposit
  ##################################################
  def ba_create_deposit_data_helper
    account = create(:account)
    deposit = create(:balance_activity, account: account)
    log = {
      transaction_hash: "0xabc",
      amount: 1,
      credit_or_debit: "credit",
      block_number: 2,
      gas_used: 3,
      transaction_status: "sucess",
      confirmation_status: "pending",
    }
    expected_params = {
      account_id: account[:id],
      transaction_hash: "0xabc",
      activity_type: "deposit",
      amount: 1,
      credit_or_debit: "credit",
      block_number: 2,
      gas_used: 3,
      transaction_status: "sucess",
      confirmation_status: "pending",
    }
    allow(BalanceActivity).to receive(:create!).and_return(deposit)
    return account, deposit, log, expected_params
  end
  def ba_create_deposit_returns_deposit_helper
    account, deposit, log = ba_create_deposit_data_helper
    expect(BalanceActivity.create_deposit(account, log)).to eq(deposit)
  end
  def ba_create_deposit_calls_update_if_confirmed_helper
    account, deposit, log = ba_create_deposit_data_helper
    expect(deposit).to receive(:update_if_confirmed).with(log, account[:balance])
                          .and_return(deposit)
    BalanceActivity.create_deposit(account, log)
  end
  def ba_create_deposit_calls_create_helper
    account, deposit, log, expected_params = ba_create_deposit_data_helper
    expect(BalanceActivity).to receive(:create!).with(expected_params)
                          .and_return(deposit)
    BalanceActivity.create_deposit(account, log)
  end

  ##################################################
  # #update_if_confirmed
  ##################################################
  def ba_update_if_confirmed_does_not_update_balances_helper
    deposit = create(:balance_activity)
    log = {
      confirmation_status: "confirmed",
      transaction_status: 0,
      amount: 1
    }
    balance = 2
    allow(deposit).to receive(:update!).and_return("updated")
    update_params = { confirmation_status: "confirmed" }
    expect(deposit).to receive(:update!).with(update_params)
    result = deposit.update_if_confirmed(log, balance)
    expect(result).to eq("updated")
  end
  def ba_update_if_confirmed_updates_balances_helper
    deposit = create(:balance_activity)
    log = {
      confirmation_status: "confirmed",
      transaction_status: 1,
      amount: 1
    }
    balance = 2
    allow(deposit).to receive(:update!).and_return("updated")
    update_params = {
      confirmation_status: "confirmed",
      new_balance: 3,
      old_balance: 2
    }
    expect(deposit).to receive(:update!).with(update_params)
    result = deposit.update_if_confirmed(log, balance)
    expect(result).to eq("updated")
  end
  def ba_update_if_confirmed_does_not_call_update_helper
    deposit = create(:balance_activity)
    log = {
      confirmation_status: "revert",
      transaction_status: 0,
      amount: 1
    }
    balance = 2
    allow(deposit).to receive(:update!).and_return("updated")
    expect(deposit).not_to receive(:update!)
    result = deposit.update_if_confirmed(log, balance)
    expect(result).to eq(nil)
  end
  def ba_update_if_confirmed_calls_update_helper
    deposit = create(:balance_activity)
    log = {
      confirmation_status: "confirmed",
      transaction_status: 0,
      amount: 1
    }
    balance = 2
    allow(deposit).to receive(:update!).and_return("updated")
    update_params = { confirmation_status: "confirmed" }
    expect(deposit).to receive(:update!).with(update_params)
    result = deposit.update_if_confirmed(log, balance)
    expect(result).to eq("updated")
  end

end

class BalanceActivity < ApplicationRecord

  belongs_to :account
  belongs_to :itemable, polymorphic: true, optional: true

  validates_presence_of :account_id, :activity_type, :amount,
                        :credit_or_debit

  validates_presence_of :transaction_hash, :block_number, :gas_used,
                        :transaction_status, :confirmation_status,
                        if: lambda { self.activity_type === "deposit" }

  validates_uniqueness_of :transaction_hash, allow_blank: true
  validates_numericality_of :block_number, greater_than: 0,
                            if: lambda {self.activity_type === "deposit"}

  enum activity_type:  { deposit: 0, charge: 1 }
  enum credit_or_debit:  { credit: 0, debit: 1 }
  enum transaction_status:  { revert: 0, success: 1 }
  enum confirmation_status:  { pending: 0, confirmed: 1, failed: 2 }

  scope :deposits, -> { where(activity_type: "deposit") }
  scope :valid, -> { where(confirmation_status: "confirmed",
                           transaction_status: "success")  }
  scope :valid_deposits, -> { deposits.valid }

  def self.create_charge_ba_and_charge_account_for_goal_fail(goal)
    ActiveRecord::Base.transaction do
      account = goal.account
      new_account_balance = account[:balance] - goal[:amount]
      ba_data = {
        account_id: account[:id],
        activity_type: "charge",
        amount: goal[:amount],
        new_balance: new_account_balance,
        old_balance: account[:balance],
        credit_or_debit: "debit",
        itemable: goal
      }
      self.create!(ba_data)
      account.update!(balance: new_account_balance)
    end
  end

  def update_if_confirmed(log, balance)
    return unless log[:confirmation_status] === "confirmed"
    update_params = { confirmation_status: "confirmed" }

    if log[:transaction_status] === 1 # success
      update_params[:new_balance] = log[:amount] + balance
      update_params[:old_balance] = balance
    end

    self.update!(update_params)
  end

  def self.create_deposit(account, log)
    deposit = self.create!({
      account_id: account[:id],
      transaction_hash: log[:transaction_hash],
      activity_type: "deposit",
      amount: log[:amount],
      credit_or_debit: "credit",
      block_number: log[:block_number],
      gas_used: log[:gas_used],
      transaction_status: log[:transaction_status],
      confirmation_status: log[:confirmation_status]
    })

    deposit.update_if_confirmed(log, account[:balance])
    deposit
  end

  def self.create_or_update_deposit(log, account)
    deposit = self.find_by(transaction_hash: log[:transaction_hash])

    if deposit
      deposit.update_if_confirmed(log, account[:balance])
    else
      deposit = self.create_deposit(account, log)
    end
    deposit
  end

  def self.txn_is_already_confirmed?(txn_hash)
    already_confirmed_transaction_filter = {
      transaction_hash: txn_hash,
      confirmation_status: "confirmed"
    }
    self.find_by(already_confirmed_transaction_filter)
  end

  def self.update_account_balance_if_should(deposit, account)
    if deposit.confirmed? && deposit.success?
      account.update!(balance: deposit[:new_balance])
    end
  end

  def self.create_or_update_deposit_and_account(log)
    return if self.txn_is_already_confirmed?(log[:transaction_hash])
    account = Account.find_or_create_account(log)
    deposit = self.create_or_update_deposit(log, account)
    self.update_account_balance_if_should(deposit, account)
  end

  def self.get_from_block
    filter = {
      activity_type: "deposit",
      confirmation_status: "confirmed"
    }

    deposit = self.where(filter).order('block_number ASC').last
    deposit ? "0x" + (deposit["block_number"] + 1).to_s(16) : '0x0'
  end

  def self.update_deposits_from_logs
    logs = Contract.get_logs({from_block: self.get_from_block})
    ActiveRecord::Base.transaction do
      logs.each { |log| self.create_or_update_deposit_and_account(log) }
    end
  end
end

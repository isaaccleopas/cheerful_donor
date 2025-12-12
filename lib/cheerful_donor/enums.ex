defmodule CheerfulDonor.Enums do
  @moduledoc false

  # Donation + Transaction status
  def donation_statuses,
    do: [:pending, :successful, :failed, :abandoned]

  def transaction_statuses,
    do: [:pending, :success, :failed, :reversed]

  # Subscription
  def subscription_intervals,
    do: [:daily, :weekly, :monthly, :quarterly, :annually]

  def subscription_statuses,
    do: [:active, :cancelled, :past_due, :expired]

  # Payout
  def payout_statuses,
    do: [:pending, :processing, :success, :failed]

  # Paystack Events
  def paystack_event_types do
    [
      # Charge events
      :charge_dispute_create,
      :charge_dispute_remind,
      :charge_dispute_resolve,
      :charge_success,

      # Customer identification
      :customeridentification_failed,
      :customeridentification_success,

      # Payment Request
      :paymentrequest_pending,
      :paymentrequest_success,

      # Refund events
      :refund_failed,
      :refund_pending,
      :refund_processed,
      :refund_processing,

      # Subscription events
      :subscription_create,
      :subscription_disable,
      :subscription_expiring_cards,
      :subscription_not_renew,

      # Transfer (Payout) events
      :transfer_failed,
      :transfer_success,
      :transfer_reversed
    ]
  end
end

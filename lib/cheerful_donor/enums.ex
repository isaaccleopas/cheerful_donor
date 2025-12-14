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

  @event_map %{
    "charge.success" => :charge_success,
    "charge.dispute.create" => :charge_dispute_create,
    "charge.dispute.remind" => :charge_dispute_remind,
    "charge.dispute.resolve" => :charge_dispute_resolve,

    "customeridentification.failed" => :customeridentification_failed,
    "customeridentification.success" => :customeridentification_success,

    "paymentrequest.pending" => :paymentrequest_pending,
    "paymentrequest.success" => :paymentrequest_success,

    "refund.failed" => :refund_failed,
    "refund.pending" => :refund_pending,
    "refund.processed" => :refund_processed,
    "refund.processing" => :refund_processing,

    "subscription.create" => :subscription_create,
    "subscription.disable" => :subscription_disable,
    "subscription.expiring_cards" => :subscription_expiring_cards,
    "subscription.not_renew" => :subscription_not_renew,

    "transfer.failed" => :transfer_failed,
    "transfer.success" => :transfer_success,
    "transfer.reversed" => :transfer_reversed
  }

  def paystack_event_types, do: Map.values(@event_map)

  def map_event_type(str) do
    Map.get(@event_map, str, nil)
  end
end

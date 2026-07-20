defmodule CheerfulDonor.Giving.ConfirmDonation.DonationConfirmedV1 do
  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :reference, String.t()
    field :amount, integer()
    field :paid_at, String.t()
    field :channel, String.t() | nil
    field :customer_code, String.t() | nil
    field :authorization_code, String.t() | nil
    field :raw, map()
  end
end

defmodule CheerfulDonor.Giving.ConfirmDonation do
  use Ash.Resource, domain: CheerfulDonor.Giving

  actions do
    create :create do
      accept [
        :reference,
        :amount,
        :paid_at,
        :channel,
        :customer_code,
        :authorization_code,
        :raw
      ]

      change {CheerfulDonor.Changes.DispatchCommand, consistency: :strong}
    end
  end

  attributes do
    attribute :reference, :string, primary_key?: true, allow_nil?: false
    attribute :amount, :integer, allow_nil?: false
    attribute :paid_at, :string, allow_nil?: false
    attribute :channel, :string
    attribute :customer_code, :string
    attribute :authorization_code, :string
    attribute :raw, :map
  end

  def build_event(cmd) do
    %CheerfulDonor.Giving.ConfirmDonation.DonationConfirmedV1{
      reference: cmd.reference,
      amount: cmd.amount,
      paid_at: cmd.paid_at,
      channel: cmd.channel,
      customer_code: cmd.customer_code,
      authorization_code: cmd.authorization_code,
      raw: cmd.raw || %{}
    }
  end
end

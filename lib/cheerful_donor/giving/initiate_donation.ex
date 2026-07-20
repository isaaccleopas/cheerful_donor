defmodule CheerfulDonor.Giving.InitiateDonation.DonationInitiatedV1 do
  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :reference, String.t()
    field :amount, integer()
    field :currency, String.t()
    field :donor_id, String.t() | nil
    field :campaign_id, String.t()
    field :church_id, String.t()
    field :guest_email, String.t() | nil
    field :guest_name, String.t() | nil
    field :type, String.t()
    field :interval, String.t() | nil
    field :initiated_at, String.t()
  end
end

defmodule CheerfulDonor.Giving.InitiateDonation do
  use Ash.Resource, domain: CheerfulDonor.Giving

  actions do
    create :create do
      accept [
        :reference,
        :amount,
        :currency,
        :donor_id,
        :campaign_id,
        :church_id,
        :guest_email,
        :guest_name,
        :type,
        :interval,
        :initiated_at
      ]

      change {CheerfulDonor.Changes.DispatchCommand, consistency: :strong}
    end
  end

  attributes do
    attribute :reference, :string, primary_key?: true, allow_nil?: false
    attribute :amount, :integer, allow_nil?: false
    attribute :currency, :string, allow_nil?: false
    attribute :donor_id, :string
    attribute :campaign_id, :string, allow_nil?: false
    attribute :church_id, :string, allow_nil?: false
    attribute :guest_email, :string
    attribute :guest_name, :string
    attribute :type, :string, allow_nil?: false, default: "one_time"
    attribute :interval, :string
    attribute :initiated_at, :string, allow_nil?: false
  end

  def build_event(cmd) do
    %CheerfulDonor.Giving.InitiateDonation.DonationInitiatedV1{
      reference: cmd.reference,
      amount: cmd.amount,
      currency: cmd.currency,
      donor_id: cmd.donor_id,
      campaign_id: cmd.campaign_id,
      church_id: cmd.church_id,
      guest_email: cmd.guest_email,
      guest_name: cmd.guest_name,
      type: cmd.type,
      interval: cmd.interval,
      initiated_at: cmd.initiated_at
    }
  end
end

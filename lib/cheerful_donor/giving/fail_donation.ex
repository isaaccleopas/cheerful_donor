defmodule CheerfulDonor.Giving.FailDonation.DonationFailedV1 do
  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :reference, String.t()
    field :reason, String.t() | nil
    field :failed_at, String.t()
  end
end

defmodule CheerfulDonor.Giving.FailDonation do
  use Ash.Resource, domain: CheerfulDonor.Giving

  actions do
    create :create do
      accept [:reference, :reason, :failed_at]
      change {CheerfulDonor.Changes.DispatchCommand, consistency: :strong}
    end
  end

  attributes do
    attribute :reference, :string, primary_key?: true, allow_nil?: false
    attribute :reason, :string
    attribute :failed_at, :string, allow_nil?: false
  end

  def build_event(cmd) do
    %CheerfulDonor.Giving.FailDonation.DonationFailedV1{
      reference: cmd.reference,
      reason: cmd.reason,
      failed_at: cmd.failed_at
    }
  end
end

defmodule CheerfulDonor.Giving.Shared.Router do
  use Commanded.Commands.Router

  dispatch(
    [
      CheerfulDonor.Giving.InitiateDonation,
      CheerfulDonor.Giving.ConfirmDonation,
      CheerfulDonor.Giving.FailDonation
    ],
    to: __MODULE__,
    identity: :reference,
    identity_prefix: "donation-"
  )

  defstruct []

  def execute(_state, command), do: command.__struct__.build_event(command)

  def apply(state, _event), do: state
end

defmodule CheerfulDonor.Payments do
  use Ash.Domain,
    otp_app: :cheerful_donor

  resources do
    resource CheerfulDonor.Payments.Transaction
  end

  def create_transaction(attrs),
    do: Ash.create(Transaction, attrs)
end

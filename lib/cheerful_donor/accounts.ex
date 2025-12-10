defmodule CheerfulDonor.Accounts do
  use Ash.Domain, otp_app: :cheerful_donor, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource CheerfulDonor.Accounts.Token
    resource CheerfulDonor.Accounts.User
    resource CheerfulDonor.Accounts.Church
    resource CheerfulDonor.Accounts.Donor
  end
end

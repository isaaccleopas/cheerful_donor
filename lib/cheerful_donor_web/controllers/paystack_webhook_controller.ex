defmodule CheerfulDonorWeb.PaystackWebhookController do
  use CheerfulDonorWeb, :controller

  alias CheerfulDonor.Payments.HandlePaystackEvent

  @doc """
  Paystack sends events to this endpoint.
  We validate the signature and pass the payload to our handler.
  """
  def handle(conn, _params) do
    secret_key = Application.get_env(:cheerful_donor, :paystack_secret_key)

    {:ok, raw_body, _conn} =
      Plug.Conn.read_body(conn, length: 1_000_000)

    received_sig =
      conn.req_headers
      |> Enum.into(%{})
      |> Map.get("x-paystack-signature")

    expected_sig =
      :crypto.mac(:hmac, :sha256, secret_key, raw_body)
      |> Base.encode16(case: :lower)

    if received_sig != expected_sig do
      conn |> send_resp(401, "invalid signature")
    else
      payload = Jason.decode!(raw_body)
      HandlePaystackEvent.process(payload)
      conn |> send_resp(200, "ok")
    end
  end
end

# defmodule CheerfulDonorWeb.PaystackWebhookController do
#   use CheerfulDonorWeb, :controller

#   require Logger

#   @paystack_secret System.get_env("PAYSTACK_SECRET_KEY")

#   def webhook(conn, _params) do
#     signature = Plug.Conn.get_req_header(conn, "x-paystack-signature") |> List.first()
#     {:ok, body, conn} = Plug.Conn.read_body(conn)

#     if verify_signature?(body, signature) do
#       event = Jason.decode!(body)
#       Logger.info("Received Paystack Webhook: #{inspect(event)}")

#       # Process webhook inside Ash domain
#       CheerfulDonor.Donations.HandlePaystackEvent.run(event)

#       conn
#       |> send_resp(200, "OK")
#     else
#       Logger.warning("Invalid Paystack webhook signature")
#       conn |> send_resp(403, "Forbidden")
#     end
#   end

#   defp verify_signature?(body, signature) do
#     expected =
#       :crypto.mac(:hmac, :sha256, @paystack_secret, body)
#       |> Base.encode16(case: :lower)

#     expected == signature
#   end
# end

defmodule CheerfulDonorWeb.PaystackWebhookController do
  use CheerfulDonorWeb, :controller

  require Logger
  require Ash.Query

  def handle(conn, _params) do
    raw_body = conn.assigns[:raw_body] || ""

    received_sig =
      conn
      |> get_req_header("x-paystack-signature")
      |> List.first()

    secret = paystack_secret_key()

    expected_sig =
      :crypto.mac(:hmac, :sha512, secret, raw_body)
      |> Base.encode16(case: :lower)

    if received_sig != expected_sig do
      Logger.warning("Paystack webhook rejected: invalid signature")
      send_resp(conn, 401, "invalid signature")
    else
      payload = Jason.decode!(raw_body)
      Logger.info("Paystack webhook received: #{payload["event"]}")

      Task.start(fn ->
        if already_processed?(payload) do
          :ok
        else
          case save_webhook_event(payload) do
            {:ok, webhook_event} ->
              CheerfulDonor.Payments.HandlePaystackEvent.process(payload, webhook_event)

            _ ->
              CheerfulDonor.Payments.HandlePaystackEvent.process(payload)
          end
        end
      end)

      send_resp(conn, 200, "ok")
    end
  rescue
    error ->
      Logger.error("Paystack webhook failed: #{Exception.message(error)}")
      send_resp(conn, 500, "error")
  end

  def ping(conn, _params) do
    send_resp(conn, 200, "Paystack webhook endpoint is reachable")
  end

  defp already_processed?(payload) do
    case CheerfulDonor.Paystack.WebhookEvent
         |> Ash.Query.filter(payload == ^payload)
         |> Ash.read_one() do
      {:ok, %{processed: true}} -> true
      _ -> false
    end
  end

  defp save_webhook_event(%{"event" => event} = payload) do
    case CheerfulDonor.Enums.map_event_type(event) do
      nil ->
        {:ignored, nil}

      event_type ->
        CheerfulDonor.Paystack.WebhookEvent
        |> Ash.Changeset.for_create(:create, %{
          event_type: event_type,
          payload: payload
        })
        |> Ash.create()
    end
  end

  defp paystack_secret_key do
    case Application.get_env(:cheerful_donor, :env, :dev) do
      :prod -> System.fetch_env!("PAYSTACK_SECRET_KEY")
      _ -> System.fetch_env!("PAYSTACK_TEST_SECRET_KEY")
    end
  end
end

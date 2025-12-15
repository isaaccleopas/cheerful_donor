defmodule CheerfulDonor.Paystack.Client do
  require Logger

  @paystack_url "https://api.paystack.co"

  # Load secret keys based on env
  env = Application.compile_env(:cheerful_donor, :env, :dev)

  case env do
    :prod -> @secret_key System.get_env("PAYSTACK_SECRET_KEY")
    _ -> @secret_key System.get_env("PAYSTACK_TEST_SECRET_KEY")
  end

  @http_headers [
    {"Content-Type", "application/json"},
    {"Authorization", "Bearer #{@secret_key}"}
  ]

  @http_options [
    timeout: 8_000,         # 8 seconds connection timeout
    recv_timeout: 10_000    # 10 seconds read timeout
  ]

  # -------------------------
  # Unified Request Handler
  # -------------------------
  defp request(method, url, body \\ nil, headers \\ []) do
    headers = headers ++ @http_headers

    response =
      case method do
        :get -> HTTPoison.get(url, headers, @http_options)
        :post -> HTTPoison.post(url, body, headers, @http_options)
      end

    case response do
      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        parse_response(code, body)

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Paystack request error: #{inspect(reason)}")
        {:error, %{error: :network_error, reason: reason}}
    end
  end

  # -------------------------
  # Safe JSON Parser
  # -------------------------
  defp parse_response(code, body) do
    case Jason.decode(body) do
      {:ok, decoded} ->
        if code in 200..299 do
          {:ok, decoded}
        else
          {:error, %{status_code: code, response: decoded}}
        end

      {:error, _} ->
        Logger.error("""
        Failed to decode Paystack JSON response:
        #{inspect(body)}
        """)

        {:error, %{status_code: code, response: :invalid_json}}
    end
  end

  # -------------------------
  # Initialize Transaction
  # -------------------------
  def initialize_transaction(params) do
    url = "#{@paystack_url}/transaction/initialize"

    # Add idempotency key to avoid duplicate charges when users click twice
    idempotency_key = params["reference"] || params[:reference] || UUID.uuid4()

    headers = [
      {"Idempotency-Key", idempotency_key}
    ]

    body = Jason.encode!(params)
    request(:post, url, body, headers)
  end

  # -------------------------
  # Verify a completed transaction
  # -------------------------
  def verify_transaction(reference) do
    url = "#{@paystack_url}/transaction/verify/#{reference}"
    request(:get, url)
  end

  # -------------------------
  # Charge saved card authorization (recurring)
  # -------------------------
  def charge_authorization(auth_code, email, amount) do
    url = "#{@paystack_url}/transaction/charge_authorization"

    body =
      Jason.encode!(%{
        "authorization_code" => auth_code,
        "email" => email,
        "amount" => amount
      })

    # Prevent duplicate subscription billing charges
    headers = [
      {"Idempotency-Key", "charge-" <> auth_code <> "-" <> to_string(amount)}
    ]

    request(:post, url, body, headers)
  end
end

defmodule App.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def load_serving do
    {:ok, model_info} = Bumblebee.load_model({:hf, "microsoft/resnet-50"})
    {:ok, featurizer} = Bumblebee.load_featurizer({:hf, "microsoft/resnet-50"})

    Bumblebee.Vision.image_classification(model_info, featurizer,
      top_k: 1,
      compile: [batch_size: 4],
      defn_options: [compiler: EXLA]
    )
  end

  @impl true
  def start(_type, _args) do
    children = [
      AppWeb.Telemetry,
      # App.Repo,
      {DNSCluster, query: Application.get_env(:app, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: App.PubSub},
      {Nx.Serving, serving: load_serving(), name: App.Serving, batch_timeout: 100},
      # Start the Finch HTTP client for sending emails
      {Finch, name: App.Finch},
      # Start a worker by calling: App.Worker.start_link(arg)
      # {App.Worker, arg},
      # Start to serve requests, typically the last entry
      AppWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: App.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

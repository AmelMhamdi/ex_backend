defmodule ExBackend.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ex_backend,
      version: get_version(),
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def blue_bird_info do
    [
      host: "https://backend.media-io.com",
      title: "Media-IO Backend",
      description: "REST API documentation for the Media-IO backend",
      contact: [
        name: "Media-IO",
        url: "https://media-io.com",
        email: "contact@media-io.com"
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {ExBackend.Application, []},
      extra_applications: [
        :amqp,
        :bamboo,
        :bcrypt_elixir,
        :blue_bird,
        :ecto_sql,
        :httpotion,
        :jason,
        :logger,
        :phauxth,
        :phoenix_ecto,
        :postgrex,
        :runtime_tools,
        :timex,
        :elixir_make,
        :parse_trans,
        :step_flow
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:amqp, "~> 1.2"},
      {:bcrypt_elixir, "~> 2.0"},
      {:bamboo, "~> 1.2"},
      {:blue_bird, "~> 0.4.1"},
      {:comeonin, "~> 5.1"},
      {:cowboy, "~> 2.6"},
      {:distillery, "~> 2.1"},
      {:ecto, "~> 3.1"},
      {:ecto_sql, "~> 3.1"},
      {:ex_aws, "~> 2.0"},
      {:ex_aws_s3, "~> 2.0"},
      {:ex_imdb_sniffer, "~> 0.1.1"},
      {:ex_mock, "~> 0.1.1", only: :test},
      {:ex_video_factory, "0.3.14"},
      {:gettext, "~> 0.14"},
      {:httpotion, "~> 3.1.0"},
      {:jason, "~> 1.1"},
      {:lager, "3.6.10"},
      {:phoenix, "~> 1.4.6"},
      {:phoenix_ecto, "~> 4.0"},
      {:phoenix_html, "~> 2.10"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_pubsub, "~> 1.0"},
      {:phauxth, "~> 2.2"},
      {:plug, "~> 1.8.0"},
      {:plug_cowboy, "~> 2.0"},
      {:postgrex, "~> 0.15.0"},
      {:ranch, "~> 1.7.1"},
      {:remote_dockers, "1.4.0"},
      {:sigaws, "~> 0.7.2"},
      {:step_flow, "~> 0.0.6"},
      {:timex, "~> 3.2"},
      {:uuid, "~> 1.1"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end

  defp get_version do
    version_from_file()
    |> handle_file_version()
    |> String.replace_leading("v", "")
  end

  defp version_from_file(file \\ "VERSION") do
    File.read(file)
  end

  defp handle_file_version({:ok, content}) do
    content
  end

  defp handle_file_version({:error, _}) do
    retrieve_version_from_git()
  end

  defp retrieve_version_from_git do
    require Logger

    Logger.debug(
      "Calling out to `git describe` for the version number. This is slow! You should think about a hook to set the VERSION file"
    )

    System.cmd("git", ~w{describe --always --tags --first-parent})
    |> elem(0)
    |> String.trim()
  end
end

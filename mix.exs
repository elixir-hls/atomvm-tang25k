defmodule AtomVMTang25K.MixProject do
  use Mix.Project

  # The base for the Sipeed Tang Primer 25K: the LiteX SoC and AtomVM on it, as a package for Mix (no Elixir of its
  # own). An application has it through its target, atomvm_tang25k_hls; `mix ehls.setup` sets a copy of it up once for
  # the machine (scripts/setup_litex.sh, setup_atomvm.sh, build_host.sh) outside the application.
  def project do
    [
      app: :atomvm_tang25k,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: [],
      erlc_paths: [],
      deps: [],
      description: "The Sipeed Tang Primer 25K's base for Elixir HLS: a LiteX SoC and AtomVM on its VexRiscv CPU",
      package: [
        licenses: ["Apache-2.0"],
        links: %{"GitHub" => "https://github.com/elixir-hls/atomvm-tang25k"},
        files: ~w(apps docs erl gateware patches scripts litex_setup.py litex_repos.py mix.exs README.md LICENSE),
        exclude_patterns: [~r/__pycache__/, ~r/\.pyc$/]
      ]
    ]
  end

  def application, do: []
end

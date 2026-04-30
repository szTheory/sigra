defmodule Sigra.OptionalDeps.MissingDependencyError do
  @moduledoc """
  Raised when an enabled Sigra feature requires an optional dependency
  that is not available in the host application.
  """

  defexception [:feature, :dependency, :spec, :evidence, :remediation, :message]

  @impl true
  def exception(opts) do
    feature = Keyword.fetch!(opts, :feature)
    dependency = Keyword.fetch!(opts, :dependency)
    spec = Keyword.fetch!(opts, :spec)
    evidence = Keyword.fetch!(opts, :evidence)
    remediation = Keyword.fetch!(opts, :remediation)

    message = """
    [Sigra] optional dependency missing for #{feature}.

    Feature: #{feature}
    Dependency: #{dependency} (#{spec})
    Evidence: #{evidence}

    #{remediation}
    """

    %__MODULE__{
      feature: feature,
      dependency: dependency,
      spec: spec,
      evidence: evidence,
      remediation: remediation,
      message: message
    }
  end
end

defmodule TokenOperator do
  def maybe(token, opts, option_name, function_or_functions, defaults \\ []) do
    opts =
      defaults
      |> Keyword.merge(opts)
      |> Enum.into(%{})

    option_value = Map.get(opts, option_name)

    process(token, option_value, opts, function_or_functions)
  end

  defp process(token, nil, _, _), do: token

  defp process(token, option_value, opts, function_or_functions)
       when is_list(function_or_functions) do
    process_list(token, option_value, opts, function_or_functions)
  end

  defp process(token, _, opts, function) do
    function.(token, opts)
  end

  defp process_list(token, option_value, opts, functions) when is_atom(option_value) do
    process_list(token, [option_value], opts, functions)
  end

  defp process_list(token, option_values, opts, functions) do
    Enum.reduce(option_values, token, fn value, token ->
      function = Keyword.fetch!(functions, value)
      function.(token, opts)
    end)
  end
end

defmodule TokenOperatorTest do
  use ExUnit.Case

  alias TokenOperator, as: Operator

  describe "maybe/5 with a single function" do
    test "does not call the corresponding option's function when the specified option is not present" do
      token = %{limit: nil}
      opts = []
      function = fn _token -> raise "should not be run" end
      assert %{limit: nil} == Operator.maybe(token, opts, :limit, function)
    end

    test "calls the corresponding function with the token and options when the option is present" do
      token = %{limit: nil}
      opts = [limit: 20]

      function = fn token, %{limit: limit} ->
        %{token | limit: limit}
      end

      assert %{limit: 20} ==
               Operator.maybe(token, opts, :limit, function)
    end

    test "supports functions with an arity of 1" do
      token = %{limit: nil}
      opts = [unlimited: true]

      function = fn token ->
        %{token | limit: 20}
      end

      assert %{limit: 20} ==
               Operator.maybe(token, opts, :unlimited, function)
    end

    test "default options are passed to the corresponding option's function" do
      token = %{limit: nil}
      opts = []
      default_opts = [limit: 50]

      function = fn token, %{limit: limit} ->
        %{token | limit: limit}
      end

      assert %{limit: 50} ==
               Operator.maybe(token, opts, :limit, function, default_opts)
    end

    test "default options may be overriden" do
      token = %{limit: nil}
      opts = [limit: 10]
      default_opts = [limit: 50]

      function = fn token, %{limit: limit} ->
        %{token | limit: limit}
      end

      assert %{limit: 10} ==
               Operator.maybe(token, opts, :limit, function, default_opts)
    end

    test "default options may be effectively cleared with nil" do
      token = %{limit: nil}
      opts = [limit: nil]
      default_opts = [limit: 50]

      function = fn token, %{limit: limit} ->
        %{token | limit: limit}
      end

      assert %{limit: nil} ==
               Operator.maybe(token, opts, :limit, function, default_opts)
    end

    test "makes all options available to the corresponding function" do
      token = %{paginate: nil, page: nil, page_size: nil}
      opts = [paginate: true, page: 7, page_size: 20]

      function = fn token, %{paginate: true, page: page, page_size: page_size} ->
        %{token | paginate: true, page: page, page_size: page_size}
      end

      assert %{paginate: true, page: 7, page_size: 20} ==
               Operator.maybe(token, opts, :paginate, function)
    end

    test "raises an error when passed a function with arity of 0" do
      token = %{limit: nil}
      opts = [limit: 10]

      function = fn -> nil end

      assert_raise RuntimeError, "Function must have an arity of either 1 or 2", fn ->
        Operator.maybe(token, opts, :limit, function)
      end
    end

    test "raises an error when passed a function with arity of 3" do
      token = %{limit: nil}
      opts = [limit: 10]

      function = fn _token, _options, _extra_arg -> nil end

      assert_raise RuntimeError, "Function must have an arity of either 1 or 2", fn ->
        Operator.maybe(token, opts, :limit, function)
      end
    end
  end

  describe "maybe/5 with multiple functions" do
    test "calls functions corresponding to only a single key present for the given option" do
      token = %{featured: nil, published: nil}
      opts = [filter: :featured]

      featured_fn = fn token ->
        %{token | featured: true}
      end

      published_fn = fn token ->
        %{token | published: true}
      end

      assert %{featured: true, published: nil} ==
               Operator.maybe(token, opts, :filter, featured: featured_fn, published: published_fn)
    end

    test "calls functions corresponding to multiple keys present for the given option" do
      token = %{featured: nil, published: nil}
      opts = [filter: [:featured, :published]]

      featured_fn = fn token ->
        %{token | featured: true}
      end

      published_fn = fn token ->
        %{token | published: true}
      end

      assert %{featured: true, published: true} ==
               Operator.maybe(token, opts, :filter, featured: featured_fn, published: published_fn)
    end

    test "supports a single default for multiple option functions" do
      token = %{featured: nil, published: nil}
      opts = []
      default_opts = [filter: :published]

      featured_fn = fn token ->
        %{token | featured: true}
      end

      published_fn = fn token ->
        %{token | published: true}
      end

      assert %{featured: nil, published: true} ==
               Operator.maybe(
                 token,
                 opts,
                 :filter,
                 [featured: featured_fn, published: published_fn],
                 default_opts
               )
    end

    test "supports multiple defaults for multiple option functions" do
      token = %{featured: nil, published: nil}
      opts = []
      default_opts = [filter: [:published, :featured]]

      featured_fn = fn token ->
        %{token | featured: true}
      end

      published_fn = fn token ->
        %{token | published: true}
      end

      assert %{featured: true, published: true} ==
               Operator.maybe(
                 token,
                 opts,
                 :filter,
                 [featured: featured_fn, published: published_fn],
                 default_opts
               )
    end

    test "default options may be overriden" do
      token = %{featured: nil, published: nil}
      opts = [filter: :published]
      default_opts = [filter: [:published, :featured]]

      featured_fn = fn token ->
        %{token | featured: true}
      end

      published_fn = fn token ->
        %{token | published: true}
      end

      assert %{featured: nil, published: true} ==
               Operator.maybe(
                 token,
                 opts,
                 :filter,
                 [featured: featured_fn, published: published_fn],
                 default_opts
               )
    end

    test "default options may be cleared with an empty list" do
      token = %{featured: nil, published: nil}
      opts = [filter: []]
      default_opts = [filter: [:published, :featured]]

      featured_fn = fn token ->
        %{token | featured: true}
      end

      published_fn = fn token ->
        %{token | published: true}
      end

      assert %{featured: nil, published: nil} ==
               Operator.maybe(
                 token,
                 opts,
                 :filter,
                 [featured: featured_fn, published: published_fn],
                 default_opts
               )
    end

    test "default options may be cleared with nil" do
      token = %{featured: nil, published: nil}
      opts = [filter: nil]
      default_opts = [filter: [:published, :featured]]

      featured_fn = fn token ->
        %{token | featured: true}
      end

      published_fn = fn token ->
        %{token | published: true}
      end

      assert %{featured: nil, published: nil} ==
               Operator.maybe(
                 token,
                 opts,
                 :filter,
                 [featured: featured_fn, published: published_fn],
                 default_opts
               )
    end

    test "raises an error when an option is passed with no corresponding function" do
      token = %{featured: nil, published: nil}
      opts = [filter: :nifty]

      featured_fn = fn token ->
        %{token | featured: true}
      end

      published_fn = fn token ->
        %{token | published: true}
      end

      assert_raise KeyError, fn ->
        Operator.maybe(token, opts, :filter, featured: featured_fn, published: published_fn)
      end
    end

    test "supports functions with an arity of 2" do
      token = %{featured: nil, published: nil}
      opts = [filter: [:featured, :published], starts_with: "a"]

      featured_fn = fn token, %{starts_with: letter} ->
        %{token | featured: letter}
      end

      published_fn = fn token, %{starts_with: letter} ->
        %{token | published: letter}
      end

      assert %{featured: "a", published: "a"} ==
               Operator.maybe(token, opts, :filter, featured: featured_fn, published: published_fn)
    end
  end
end

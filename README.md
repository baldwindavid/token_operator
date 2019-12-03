# TokenOperator

TokenOperator takes a _token_ and passes it to specified functions conditioned
upon the presence of known keyword options. It aims to make developing a consistent
keyword list-based function API simple. It provides for a simple pattern wrapped up in
about 20 lines of code.

## Installation

Add the latest release to your `mix.exs` file:

```elixir
defp deps do
  [
    {:token_operator, "~> 0.1.0"}
  ]
end
```

Then run `mix deps.get` in your shell to fetch the dependencies.

## Example: Filtering Via Multiple Functions

A common use case is for devising a keyword list-based API for a Phoenix context.

Suppose we have a blog `Posts` context with a `list_posts` function. That
function lists all posts. However, sometimes we want to view _all_ posts,
sometimes only published posts, sometimes featured, sometimes published and
featured, etc. We could create a bunch of functions such as `list_published_posts`,
`list_featured_posts`, `list_published_and_featured_posts`, etc.

There are endless ways to provide an API to this context, but one might be
something like...

```elixir
Posts.list_posts(filter: [:published, :featured])
```

Essentially, a `filter` keyword that can take zero or more of `:published` and
`:featured`. When `:filter` is missing, all posts should be returned.

Supporting this in the context is not terribly difficult, but can be cumbersome
when doing it often.

In our context, we probably have a function that looks something like...

```elixir
def list_posts do
  Repo.all(Post)
end
```

As of now, this function does not support any options, so let's provide that.

```elixir
def list_posts(opts \\ []) do
  Repo.all(Post)
end
```

Now, let's support the desired API in one go with a few functions.

```elixir
def list_posts(opts \\ []) do
  Post
  |> TokenOperator.maybe(opts, :filter, published: &published/2, featured: &featured/2)
  |> Repo.all()
end

defp published(query, _opts) do
  from(p in query, where: p.is_published)
end

defp featured(query, _opts) do
  from(p in query, where: p.is_featured)
end
```

Piping the query through the `TokenOperator.maybe/5` function sets us up with
the desired API. `maybe/5` is the only function provided by `TokenOperator`. The following is now supported:

- `Post.list_posts()` - All posts
- `Post.list_posts(filter: [])` - All posts (clears defaults had we set any)
- `Post.list_posts(filter: nil)` - All posts (clears defaults had we set any)
- `Post.list_posts(filter: :published)` - Only published posts
- `Post.list_posts(filter: :featured)` - Only featured posts
- `Post.list_posts(filter: [:published, :featured])` - Only published AND featured posts

Were we to have wanted to default to _published_ posts, we can add defaults
to the `maybe/5` function call.

```elixir
def list_posts(opts \\ []) do
  Post
  |> TokenOperator.maybe(opts, :filter, [published: &published/2, featured: &featured/2], filter: :published)
  |> Repo.all()
end
```

The `maybe/5` function takes the following arguments:

- token - The token to be operated upon. In our example above, this is an
Ecto query.
- opts - The keyword options that will have been passed to the function when
called.
- option name - The name of the keyword list option that we are looking for.
In the example above, that is `:filter`. The name is completely up to us.
- option functions - A keyword list of functions or a single function that
should be called when a corresponding key is present in `opts`. These functions
must accept two arguments: the _token_ and the _opts_.
- default options - Optional default `opts`.

## Example: Including

This same pattern can be used to conditionally _include_ associated resources.
For example, suppose we sometimes want to include an author with our post and
sometimes not. Just chain another `maybe/5` function call using a keyword
name of, say, `:include`. Again, this could be any name that makes sense for
our application.

```elixir
def list_posts(opts \\ []) do
  Post
  |> TokenOperator.maybe(opts, :include, author: &join_author/2)
  |> TokenOperator.maybe(opts, :filter, [published: &published/2, featured: &featured/2])
  |> Repo.all()
end

defp join_author(query, _opts) do
  from(p in query, left_join: a in assoc(p, :author), preload: [author: a])
end
```

Now we can request authors be included with `Posts.list_posts(include: :author)`.
This pattern can be used whether joining, preloading, grabbing deeply
nested associations, etc. Those implementation details can be cleanly and
consistently handled in simple functions within the context.


## Example: Pagination Via Single Function

In the filtering example above, we used a list of functions (`published/2`, `featured/2`).
In some cases, we don't want to call functions based upon a list, but instead
want to pass the value of a keyword directly to a single function.

Suppose we want to conditionally paginate based upon values passed as keyword
options in the controller. We want to support the following API:

```elixir
Posts.list_posts(paginate: true, page: 3, page_size: 10)
```

Let's support pagination with a default page and page size. By default, pagination
will be disabled.

```elixir
def list_posts(opts // []) do
  Post
  |> TokenOperator.maybe(opts, :include, author: &join_author/2)
  |> TokenOperator.maybe(opts, :filter, published: &published/2, featured: &featured/2)
  |> TokenOperator.maybe(opts, :paginate, &maybe_paginate/2, page: 1, page_size: 20)
end

defp maybe_paginate(query, %{paginate: true, page: page, page_size: page_size}) do
  # Repo.paginate is an example function call to our pagination library,
  # such as Scrivener.
  Repo.paginate(query, page: page, page_size: page_size)
end

defp maybe_paginate(query, _opts) do
  Repo.all(query)
end
```

Rather than providing a keyword list of functions, there is only a single `maybe_paginate/2`
function. This provides the following ways to call the function:

- `Posts.list_posts(paginate: true)` - Paginated, defaulted to page 1 and a
page size of 20.
- `Posts.list_posts(paginate: true, page: 3, page_size: 10)` - Paginated, on
page 3, with a page size of 10.
- `Posts.list_posts()` - Not paginated.

Note that `Repo.all` was removed from the chain of function calls. Our `maybe_paginate/2`
functions serve to terminate the chain either by paginating or calling `Repo.all`.

This example also demonstrates a case where using the second _opts_ argument
is beneficial. The `maybe/5` function prepares these options based upon the
passed in _opts_ and defaults. It transforms the options to a map for easy
pattern matching in our functions. The first function head matches opts in which
`paginate` is `true` and binds the `page` and `page_size`. It is up to our app
to handle the actual pagination. There are a lot of libraries for that sort of
thing.

## Multiple or Single Functions?

In the examples above, it seemed clear that the `:filter` and `:include` behaviors
were best served by selecting from a list of functions, while `:paginate` worked
best by calling a single function. It might not always be that clear. Take for
instance, ordering. The simplest way to handle this is probably using a single
function.

```elixir
def list_posts(opts \\ []) do
  Post
  |> TokenOperator.maybe(opts, :include, author: &join_author/2)
  |> TokenOperator.maybe(opts, :filter, published: &published/2, featured: &featured/2)
  |> TokenOperator.maybe(opts, :order_by, &maybe_order/2, order_by: [desc: :published_on])
  |> TokenOperator.maybe(opts, :paginate, &paginate/2, paginate: false, page: 1, page_size: 20)
end

defp maybe_order_by(query, %{order_by: order_by}) do
  from(query, order_by: ^order_by)
end
```

The nice thing about this is that we can now pass anything that the `Ecto.Query`
`:order_by` option supports. All of the following would work out-of-the-box:

```elixir
Post.list_posts(order_by: [asc: :title])
Post.list_posts(order_by: [desc: :published_on])
Post.list_posts(order_by: [desc: :published_on, asc: :title])
```

The downside is that we are ever-so-slightly coupling our `order_by` option
to Ecto and we are less explicit about what ordering is supported via our
context. Also, what if we need to support ordering by an association (like author
name) rather than an attribute/column directly on `Post`?

Thus, we might consider handling ordering in the same way as `:include` and `:filter`.

```elixir
def list_posts(opts \\ []) do
  Post
  |> TokenOperator.maybe(opts, :include, author: &join_author/2)
  |> TokenOperator.maybe(opts, :filter, published: &published/2, featured: &featured/2)
  |> TokenOperator.maybe(opts, :order_by, [publish_date: &order_by_publish_date/2, title: &order_by_title/2], order_by: :publish_date)
  |> TokenOperator.maybe(opts, :paginate, &paginate/2, paginate: false, page: 1, page_size: 20)
end

defp order_by_publish_date(query, _opts) do
  from query, order_by: [desc: :published_on]
end

defp order_by_title(query, _opts) do
  from query, order_by: :title
end
```

This is more work, but more explicit and less dependent upon Ecto. Which method
is best is going to depend upon our use case.

## Making It Our Own

`maybe/5` can continue to be chained directly within contexts. However, it is likely that
the language of our API will start to become clear. If we are always using
keyword options like `:include`, `:filter`, `:order_by`, and `:paginate`, it is quite easy
to wrap these calls in a consistent API that our app owns.

```elixir
defmodule MyApp.Utilities.MaybeQueries do
  alias MyApp.Repo

  def maybe_filter(query, opts, functions, defaults \\ []) do
    TokenOperator.maybe(query, opts, :filter, functions, defaults)
  end

  def maybe_include(query, opts, functions, defaults \\ []) do
    TokenOperator.maybe(query, opts, :include, functions, defaults)
  end

  def maybe_order_by(query, opts, functions, defaults \\ []) do
    TokenOperator.maybe(query, opts, :order_by, functions, defaults)
  end

  def maybe_paginate(query, opts, defaults \\ [paginate: false, page: 1, page_size: 20]) do
    TokenOperator.maybe(query, opts, :paginate, &paginate/2, defaults)
  end

  defp paginate(query, %{paginate: true, page: page, page_size: page_size}) do
    Repo.paginate(query, page: page, page_size: page_size)
  end

  defp paginate(query, _) do
    Repo.all(query)
  end
end
```

Now our `list_posts` function becomes even simpler.

```elixir
import MyApp.Utilities.MaybeQueries

def list_posts(opts \\ []) do
  Post
  |> maybe_include(opts, author: &join_author/2)
  |> maybe_filter(opts, published: &published/2, featured: &featured/2)
  |> maybe_order_by(opts, publish_date: &order_by_publish_date/2, title: &order_by_title/2, order_by: :publish_date)
  |> maybe_paginate(opts)
end
```

We'll still need to provide the filter, include, and order option functions
in our context, but our wrapper function now automatically provides the behavior
for pagination.

## Taking It Too Far

This functionality could be used to support any sort of query option. For example,
perhaps we want to be able to grab all posts by a given author. We could expose
an `:author` option.

```elixir
def list_posts(opts \\ []) do
  Post
  |> TokenOperator.maybe(opts, :author, &by_author/2)
  |> maybe_include(opts, author: &join_author/2)
  |> maybe_filter(opts, published: &published/2, featured: &featured/2)
  |> maybe_order_by(opts, publish_date: &order_by_publish_date/2, title: &order_by_title/2, order_by: :publish_date)
  |> maybe_paginate(opts)
end

defp by_author(query, %{author: author}) do
  from(p in query, where: p.author_id == ^author.id)
end
```

Now we can get the posts for the author with the following API:

```elixir
author = Accounts.get_user!(author_id)
Posts.list_posts(author: author)
```

But did we gain much out of this? Maybe it's nice that we only have a single `list_posts`
function. But the goal was not necessarily for less functions. It was for the API
to be clean and clear. This is arguably less clear than simply adding a dedicated
function for a collection of posts by author like the following:

```elixir
author = Accounts.get_user!(author_id)
Posts.list_posts_by(author)
```

Our context function can then cleanly communicate and lock down the required
struct type in our function's arguments.

```elixir
def list_posts_by(%User{} = author) do
  from(p in query, where: p.author_id == ^author.id)
end
```

Since we previously wrapped up our optional query functions, this is a good
opportunity to reuse them in an additional function. Let's create a function
that can be shared. We'll leave `maybe_paginate` off since it is a terminating
function, which makes it slightly less flexible.

```elixir
defp maybe_queries(query, opts \\ []) do
  query
  |> maybe_include(opts, author: &join_author/2)
  |> maybe_filter(opts, published: &published/2, featured: &featured/2)
  |> maybe_order_by(opts, publish_date: &order_by_publish_date/2, title: &order_by_title/2, order_by: :publish_date)
end
```

We can use this shared function in both our collection functions.

```elixir
def list_posts(opts \\ []) do
  Post
  |> maybe_queries(opts)
  |> maybe_paginate(opts)
end

def list_posts_by(%User{} = author, opts \\ []) do
  from(p in Post, where: p.author_id == ^author.id)
  |> maybe_queries(opts)
  |> maybe_paginate(opts)
end
```

## Single Resource Reuse

The examples thus far have focused on providing keyword list options for querying
collections, but this works just fine for single resources. The include and
filter examples are both relevant to single resources. The ordering options
are not relevant, but they don't hurt anything. Thus, we can use our same
shared `maybe_query/2` function here.

```elixir
def get_post!(opts \\ []) do
  Post
  |> maybe_queries(opts)
  |> Repo.get!()
end
```

Now we have all the same keyword options available.

```elixir
Posts.get_post!(post_id, include: :author, filter: [:published, :featured])
```

That post will only be returned if it is both published and featured. If returned,
it will include the author association.

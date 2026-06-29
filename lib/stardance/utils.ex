defmodule Stardance.Utils do
  @base_url "https://stardance.hackclub.com"
  @user_agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

  def get_project(id) do
    case fetch_document("/projects/#{id}") do
      {:ok, document} -> {:ok, parse_project_doc(id, document)}
      error -> error
    end
  end

  def get_user(username) do
    case fetch_document("/@#{username}") do
      {:ok, document} -> {:ok, parse_user_doc(username, document)}
      error -> error
    end
  end

  def shorten(nil), do: nil

  def shorten(url) do
    %{body: %{"encoded" => encoded}} =
      Req.post!("https://url.jam06452.uk/make_url", json: %{"url" => url})

    "https://url.jam06452.uk/" <> encoded
  end

  defp fetch_document(path) do
    cookie = Application.fetch_env!(:stardance, :stardance_cookie)

    headers = [
      {"cookie", "_stardance_session_v3=#{cookie}"},
      {"user-agent", @user_agent}
    ]

    case Req.get(@base_url <> path, headers: headers) do
      {:ok, %{status: 200, body: body}} ->
        Floki.parse_document(body)

      {:ok, %{status: status}} ->
        {:error, status}

      {:error, exception} ->
        {:error, exception}
    end
  end

  defp parse_project_doc(id, document) do
    title = extract_text(document, ".project-show__title")
    description = extract_text(document, ".project-show__description")
    username = extract_text(document, "a.project-show__author")

    banner_url = extract_attr(document, ".project-show__banner-image", "src") |> shorten()

    stats =
      Map.new(Floki.find(document, ".project-show__stats-item"), fn node ->
        num = extract_text(node, ".project-show__stats-num")
        label = extract_text(node, ".project-show__stats-label") |> String.downcase()
        {label, num}
      end)

    followers = extract_text(document, ".project-show__followers strong") |> parse_int()

    panel_links = Floki.find(document, ".project-show__panel-actions a")

    demo_url =
      panel_links
      |> Enum.find(fn node -> Floki.text(node) =~ ~r/Demo|Website/i end)
      |> extract_first_href()
      |> shorten()

    sourcecode =
      panel_links
      |> Enum.find(fn node ->
        Floki.text(node) =~ ~r/Source|Code/i or
          extract_first_href(node) =~ ~r/github\.com/
      end)
      |> extract_first_href()
      |> shorten()

    superstar =
      document
      |> Floki.find("[class*='superstar' i], [alt*='superstar' i]")
      |> Enum.any?()

    %{
      id: id,
      title: title,
      username: username,
      description: description,
      devlog_count: Map.get(stats, "devlogs", "0") |> parse_int(),
      total_hours: Map.get(stats, "total hours", "0") |> parse_float(),
      banner_url: banner_url,
      demo_url: demo_url,
      sourcecode: sourcecode,
      followers: followers,
      superstar: superstar
    }
  end

  defp parse_user_doc(username, document) do
    extracted = extract_text(document, ".profile__handle") |> String.trim_leading("@")
    final_username = if extracted == "", do: username, else: extracted

    user_pfp = extract_attr(document, ".profile__avatar", "src") |> shorten()
    banner_url = extract_attr(document, ".profile__banner-image", "src") |> shorten()
    slack_url = extract_attr(document, "a[href*='slack.com']", "href") |> shorten()
    bio = extract_text(document, ".profile__bio")

    stats =
      Map.new(Floki.find(document, ".profile__stat"), fn node ->
        num = extract_text(node, ".profile__stat-num") |> parse_int()
        label = extract_text(node, ".profile__stat-label") |> String.downcase()
        {label, num}
      end)

    feed_cards = Floki.find(document, ".feed-post-card")

    project_ids = extract_feed_ids(feed_cards, "data-feed-engagement-project-id-value")
    devlog_ids = extract_feed_ids(feed_cards, "data-feed-engagement-post-id-value")

    %{
      username: final_username,
      user_pfp: user_pfp,
      bio: bio,
      banner_url: banner_url,
      devlog_count: Map.get(stats, "devlogs", 0),
      project_count: Map.get(stats, "projects", 0),
      project_ids: project_ids,
      devlog_ids: devlog_ids,
      ships: Map.get(stats, "ships", 0),
      votes: Map.get(stats, "votes", 0),
      slack_url: slack_url
    }
  end

  defp extract_text(tree, selector) do
    tree |> Floki.find(selector) |> Floki.text() |> String.trim()
  end

  defp extract_attr(tree, selector, attribute) do
    tree |> Floki.find(selector) |> Floki.attribute(attribute) |> List.first()
  end

  defp extract_first_href(nil), do: nil
  defp extract_first_href(node), do: Floki.attribute(node, "href") |> List.first()

  defp extract_feed_ids(cards, attribute) do
    cards
    |> Enum.map(fn card -> Floki.attribute(card, attribute) |> List.first() end)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&parse_int/1)
    |> Enum.uniq()
  end

  defp parse_int(text) when is_binary(text) do
    case Integer.parse(String.trim(text)) do
      {int, _} -> int
      :error -> 0
    end
  end

  defp parse_int(_), do: 0

  defp parse_float(text) when is_binary(text) do
    text = String.trim(text)

    case Float.parse(text) do
      {float, _} ->
        float

      :error ->
        case Integer.parse(text) do
          {int, _} -> int * 1.0
          :error -> 0.0
        end
    end
  end

  defp parse_float(_), do: 0.0
end

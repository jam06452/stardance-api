defmodule Stardance.Utils do
  @base_url "https://stardance.hackclub.com"
  @user_agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

  def get_project(id) do
    case fetch_document("/projects/#{id}") do
      {:ok, document} -> {:ok, parse_project_doc(id, document)}
      error -> error
    end
  end

  def get_devlog(project_id, devlog_id) do
    case fetch_document("/projects/#{project_id}/devlogs/#{devlog_id}") do
      {:ok, document} -> {:ok, parse_devlog_doc(project_id, devlog_id, document)}
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

    devlog_ids =
      document
      |> Floki.find("a.feed-post-card__overlay-link[href*='/devlogs/']")
      |> Enum.map(fn node -> Floki.attribute(node, "href") |> List.first() end)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&parse_devlog_id_from_href/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

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
      devlog_ids: devlog_ids,
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

  defp parse_devlog_id_from_href(href) do
    case Regex.run(~r{/devlogs/(\d+)}, href) do
      [_, id_str] -> parse_int(id_str)
      _ -> nil
    end
  end

  defp parse_devlog_doc(project_id, devlog_id, document) do
    # Only take the first `.feed-post-card__body` to avoid duplicating text from the
    # composer-modal quote preview inside `<dialog>`.
    description =
      case Floki.find(document, ".feed-post-card__body") do
        [] -> ""
        [node | _] -> Floki.text(node) |> String.trim()
      end

    image_urls =
      document
      |> Floki.find(".feed-post-card__image")
      |> Enum.map(fn node -> Floki.attribute(node, "src") |> List.first() end)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&shorten/1)

    likes =
      extract_text(document, ".like-button__count") |> parse_int()

    views =
      case Floki.find(document, ".feed-post-card__action--disabled[title*='Unique viewers']") do
        [node | _] -> node |> Floki.text() |> String.trim() |> parse_int()
        _ -> 0
      end

    duration_seconds =
      case extract_text(document, ".feed-post-card__duration") |> parse_duration() do
        {:ok, seconds} -> seconds
        :error -> 0
      end

    username =
      document
      |> Floki.find("a.feed-post-card__author")
      |> Enum.map(&(&1 |> Floki.attribute("href") |> List.first()))
      |> List.first()
      |> case do
        nil -> nil
        href -> String.trim_leading(href, "/@")
      end

    %{
      id: devlog_id,
      project_id: project_id,
      username: username,
      description: description,
      image_urls: image_urls,
      likes: likes,
      views: views,
      duration_seconds: duration_seconds
    }
  end

  defp parse_duration(nil), do: :error

  defp parse_duration(text) do
    text = String.trim(text)

    regex = ~r/(?:(\d+)h)?\s*(?:(\d+)m)?\s*(?:(\d+)s)?/i

    case Regex.run(regex, text, capture: :all_but_first) do
      [h, m, s] ->
        {:ok,
         parse_int(h) * 3600 +
           parse_int(m) * 60 +
           parse_int(s)}

      _ ->
        :error
    end
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

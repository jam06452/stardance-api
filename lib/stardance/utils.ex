defmodule Stardance.Utils do
  def get_project(id) do
    cookie = Application.fetch_env!(:stardance, :stardance_cookie)

    headers = [
      {"cookie", "_stardance_session_v3=#{cookie}"},
      {"user-agent",
       "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"}
    ]

    response = Req.get!("https://stardance.hackclub.com/projects/#{id}", headers: headers)
    {:ok, document} = Floki.parse_document(response.body)

    title =
      document
      |> Floki.find(".project-show__title")
      |> Floki.text()
      |> String.trim()

    description =
      document
      |> Floki.find(".project-show__description")
      |> Floki.text()
      |> String.trim()

    banner_url =
      document
      |> Floki.find(".project-show__banner-image")
      |> Floki.attribute("src")
      |> List.first()
      |> shorten()

    user_id_text =
      document
      |> Floki.find("meta[property='og:image']")
      |> Floki.attribute("content")
      |> List.first()

    user_id =
      if user_id_text do
        case Regex.run(~r/users\/(\d+)/, user_id_text) do
          [_, id_str] -> parse_int(id_str)
          _ -> nil
        end
      else
        nil
      end

    stats =
      document
      |> Floki.find(".project-show__stats-item")
      |> Enum.reduce(%{}, fn node, acc ->
        num = node |> Floki.find(".project-show__stats-num") |> Floki.text() |> String.trim()

        label =
          node
          |> Floki.find(".project-show__stats-label")
          |> Floki.text()
          |> String.trim()
          |> String.downcase()

        Map.put(acc, label, num)
      end)

    devlog_count = Map.get(stats, "devlogs", "0") |> parse_int()
    total_hours = Map.get(stats, "total hours", "0") |> parse_float()

    followers =
      document
      |> Floki.find(".project-show__followers strong")
      |> Floki.text()
      |> parse_int()

    panel_links = Floki.find(document, ".project-show__panel-actions a")

    demo_url =
      panel_links
      |> Enum.find(fn node -> Floki.text(node) =~ ~r/Demo|Website/i end)
      |> case do
        nil ->
          nil

        node ->
          Floki.attribute(node, "href")
          |> List.first()
          |> shorten()
      end

    sourcecode =
      panel_links
      |> Enum.find(fn node ->
        Floki.text(node) =~ ~r/Source|Code/i or
          Floki.attribute(node, "href") |> List.first() =~ ~r/github\.com/
      end)
      |> case do
        nil -> nil
        node -> Floki.attribute(node, "href") |> List.first() |> shorten()
      end

    superstar =
      document
      |> Floki.find("[class*='superstar' i], [alt*='superstar' i]")
      |> Enum.any?()

    %{
      id: id,
      title: title,
      user_id: user_id,
      description: description,
      devlog_count: devlog_count,
      total_hours: total_hours,
      banner_url: banner_url,
      demo_url: demo_url,
      sourcecode: sourcecode,
      followers: followers,
      superstar: superstar
    }
  end

  def get_user(username) do
    cookie = Application.fetch_env!(:stardance, :stardance_cookie)

    headers = [
      {"cookie", "_stardance_session_v3=#{cookie}"},
      {"user-agent",
       "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"}
    ]

    response =
      Req.get!("https://stardance.hackclub.com/@#{username}",
        headers: headers
      )

    {:ok, document} = Floki.parse_document(response.body)

    extracted_username =
      document
      |> Floki.find(".profile__handle")
      |> Floki.text()
      |> String.trim_leading("@")

    user_pfp =
      document
      |> Floki.find(".profile__avatar")
      |> Floki.attribute("src")
      |> List.first()
      |> shorten()

    bio =
      document
      |> Floki.find(".profile__bio")
      |> Floki.text()
      |> String.trim()

    banner_url =
      document
      |> Floki.find(".profile__banner-image")
      |> Floki.attribute("src")
      |> List.first()
      |> shorten()

    slack_url =
      document
      |> Floki.find("a[href*='slack.com']")
      |> Floki.attribute("href")
      |> List.first()
      |> shorten()

    # 2. Stats (Devlogs, Projects, Ships, Votes)
    stats =
      document
      |> Floki.find(".profile__stat")
      |> Enum.reduce(%{}, fn node, acc ->
        num = node |> Floki.find(".profile__stat-num") |> Floki.text() |> parse_int()
        label = node |> Floki.find(".profile__stat-label") |> Floki.text() |> String.downcase()

        Map.put(acc, label, num)
      end)

    feed_cards = Floki.find(document, ".feed-post-card")

    project_ids =
      feed_cards
      |> Enum.map(fn card ->
        Floki.attribute(card, "data-feed-engagement-project-id-value") |> List.first()
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&parse_int/1)
      |> Enum.uniq()

    devlog_ids =
      feed_cards
      |> Enum.map(fn card ->
        Floki.attribute(card, "data-feed-engagement-post-id-value") |> List.first()
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&parse_int/1)
      |> Enum.uniq()

    %{
      username: if(extracted_username == "", do: username, else: extracted_username),
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

  def shorten(url) do
    %{body: %{"encoded" => encoded}} =
      Req.post!("https://url.jam06452.uk/make_url", json: %{"url" => url})

    "https://url.jam06452.uk/" <> encoded
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

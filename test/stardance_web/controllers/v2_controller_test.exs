defmodule StardanceWeb.API.V2ControllerTest do
  use StardanceWeb.ConnCase

  alias Stardance.Repo
  alias Stardance.Schema.{User, Project, Devlog, Comment}

  @fresh_timestamp DateTime.utc_now() |> DateTime.add(-3600, :second)

  @valid_user_attrs %{
    id: "c89e02d4-54fd-4126-bec7-ebfbb3c0f389",
    username: "testuser",
    user_pfp: "https://example.com/pfp.png",
    bio: "A test bio",
    banner_url: "https://example.com/banner.png",
    devlog_count: 5,
    project_count: 3,
    project_ids: [100, 200],
    devlog_ids: [10, 20],
    ships: 7,
    votes: 42,
    slack_url: "https://slack.com/test",
    last_scraped_at: @fresh_timestamp
  }

  @valid_project_attrs %{
    id: 100,
    title: "Test Project",
    description: "A test project description",
    devlog_count: 3,
    total_hours: 12.5,
    banner_url: "https://example.com/project-banner.png",
    demo_url: "https://example.com/demo",
    source_code: "https://github.com/test/project",
    followers: 10,
    devlog_ids: [1, 2, 3],
    super_star: false,
    last_scraped_at: @fresh_timestamp
  }

  @valid_devlog_attrs %{
    id: 1,
    description: "A test devlog entry",
    image_urls: ["https://example.com/img1.png", "https://example.com/img2.png"],
    likes: 15,
    views: 200,
    duration_seconds: 3600,
    comments_count: 0,
    last_scraped_at: @fresh_timestamp
  }

  describe "GET /api/v2/users/:username/projects" do
    setup do
      {:ok, user} = User.changeset(struct(User), @valid_user_attrs) |> Repo.insert()

      project_attrs = Map.put(@valid_project_attrs, :user_id, user.id)
      {:ok, _project} = %Project{} |> Project.changeset(project_attrs) |> Repo.insert()

      {:ok, user: user}
    end

    test "returns paginated projects for a user", %{conn: conn, user: user} do
      conn = get(conn, ~p"/api/v2/users/#{user.username}/projects")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert length(body["projects"]) == 1
      assert body["pagination"]["total_count"] == 1
    end

    test "strips leading @ from username", %{conn: conn, user: user} do
      conn = get(conn, ~p"/api/v2/users/@#{user.username}/projects")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert length(body["projects"]) == 1
    end

    test "returns 404 when user does not exist", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/users/nonexistentuser/projects")

      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Resource not found"
    end
  end

  describe "GET /api/v2/comments/devlog/:id" do
    setup do
      {:ok, user} = User.changeset(struct(User), @valid_user_attrs) |> Repo.insert()

      project_attrs = Map.put(@valid_project_attrs, :user_id, user.id)
      {:ok, project} = %Project{} |> Project.changeset(project_attrs) |> Repo.insert()

      devlog_attrs =
        @valid_devlog_attrs
        |> Map.put(:user_id, user.id)
        |> Map.put(:project_id, project.id)

      {:ok, devlog} = %Devlog{} |> Devlog.changeset(devlog_attrs) |> Repo.insert()

      {:ok, user: user, project: project, devlog: devlog}
    end

    test "returns empty list when devlog has no comments", %{
      conn: conn,
      devlog: devlog
    } do
      conn = get(conn, ~p"/api/v2/comments/devlog/#{devlog.id}")

      assert conn.status == 200
      assert Jason.decode!(conn.resp_body) == []
    end

    test "returns comments for a devlog", %{
      conn: conn,
      user: user,
      devlog: devlog
    } do
      {:ok, _comment} =
        Comment.changeset(struct(Comment), %{
          body: "Great work!",
          author_username: "testuser",
          devlog_id: devlog.id,
          user_id: user.id,
          scraped_at: DateTime.utc_now()
        })
        |> Repo.insert()

      conn = get(conn, ~p"/api/v2/comments/devlog/#{devlog.id}")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert length(body) == 1
      assert hd(body)["body"] == "Great work!"
    end

    test "returns 404 when devlog does not exist", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/comments/devlog/99999")

      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Resource not found"
    end
  end

  describe "GET /api/v2/comments/project/:id" do
    setup do
      {:ok, user} = User.changeset(struct(User), @valid_user_attrs) |> Repo.insert()

      project_attrs = Map.put(@valid_project_attrs, :user_id, user.id)
      {:ok, project} = %Project{} |> Project.changeset(project_attrs) |> Repo.insert()

      devlog_attrs =
        @valid_devlog_attrs
        |> Map.put(:user_id, user.id)
        |> Map.put(:project_id, project.id)

      {:ok, devlog} = %Devlog{} |> Devlog.changeset(devlog_attrs) |> Repo.insert()

      {:ok, user: user, project: project, devlog: devlog}
    end

    test "returns comments across a project's devlogs", %{
      conn: conn,
      user: user,
      project: project,
      devlog: devlog
    } do
      {:ok, _comment} =
        Comment.changeset(struct(Comment), %{
          body: "Nice project!",
          author_username: "testuser",
          devlog_id: devlog.id,
          user_id: user.id,
          scraped_at: DateTime.utc_now()
        })
        |> Repo.insert()

      conn = get(conn, ~p"/api/v2/comments/project/#{project.id}")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert length(body) == 1
      assert hd(body)["body"] == "Nice project!"
    end

    test "returns 404 when project does not exist", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/comments/project/99999")

      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Resource not found"
    end
  end
end

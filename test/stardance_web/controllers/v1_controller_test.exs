defmodule StardanceWeb.API.V1ControllerTest do
  use StardanceWeb.ConnCase

  alias Stardance.Repo
  alias Stardance.Schema.{User, Project, Devlog}

  # Always-fresh timestamp so the staleness check (12h) doesn't trigger an
  # external scrape during tests. Computed at compile time.
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
    repo_url: "https://github.com/test/project",
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
    last_scraped_at: @fresh_timestamp
  }

  describe "GET /api/v1/projects" do
    test "returns empty list when no projects exist", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/projects")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["projects"] == []
      assert body["pagination"]["current_page"] == 1
      assert body["pagination"]["total_count"] == 0
    end

    test "returns paginated list of projects", %{conn: conn} do
      {:ok, user} = User.changeset(struct(User), @valid_user_attrs) |> Repo.insert()

      project_attrs = Map.put(@valid_project_attrs, :user_id, user.id)
      {:ok, _project} = %Project{} |> Project.changeset(project_attrs) |> Repo.insert()

      conn = get(conn, ~p"/api/v1/projects")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert length(body["projects"]) == 1
      assert body["pagination"]["total_count"] == 1
      assert body["pagination"]["total_pages"] == 1
    end

    test "limits results based on limit param", %{conn: conn} do
      {:ok, user} = User.changeset(struct(User), @valid_user_attrs) |> Repo.insert()

      for i <- 1..3 do
        attrs =
          Map.merge(@valid_project_attrs, %{id: i, title: "Project #{i}", user_id: user.id})

        {:ok, _} = %Project{} |> Project.changeset(attrs) |> Repo.insert()
      end

      conn = get(conn, ~p"/api/v1/projects?limit=2")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert length(body["projects"]) == 2
    end

    test "filters projects by query", %{conn: conn} do
      {:ok, user} = User.changeset(struct(User), @valid_user_attrs) |> Repo.insert()

      {:ok, _} =
        %Project{}
        |> Project.changeset(Map.put(@valid_project_attrs, :user_id, user.id))
        |> Repo.insert()

      {:ok, _} =
        %Project{}
        |> Project.changeset(%{
          Map.put(@valid_project_attrs, :user_id, user.id)
          | id: 201,
            title: "Other Project"
        })
        |> Repo.insert()

      conn = get(conn, ~p"/api/v1/projects?query=Other")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert length(body["projects"]) == 1
      assert hd(body["projects"])["title"] == "Other Project"
    end
  end

  describe "GET /api/v1/projects/:id" do
    setup do
      {:ok, user} = User.changeset(struct(User), @valid_user_attrs) |> Repo.insert()
      {:ok, user: user}
    end

    test "returns project when found in database (fresh)", %{conn: conn, user: user} do
      project_attrs = Map.put(@valid_project_attrs, :user_id, user.id)
      {:ok, _project} = %Project{} |> Project.changeset(project_attrs) |> Repo.insert()

      conn = get(conn, ~p"/api/v1/projects/100")

      assert conn.status == 200
      assert conn.resp_body != ""

      body = Jason.decode!(conn.resp_body)
      assert body["id"] == 100
      assert body["title"] == "Test Project"
      assert body["description"] == "A test project description"
      assert body["banner_url"] == "https://example.com/project-banner.png"
      assert body["devlog_ids"] == [1, 2, 3]
      assert body["demo_url"] == "https://example.com/demo"
      assert body["repo_url"] == "https://github.com/test/project"
      assert body["readme_url"] == nil
      assert body["ai_declaration"] == nil
      assert body["ship_status"] == nil
      assert body["created_at"] != nil
      assert body["updated_at"] != nil
      assert body["username"] == nil
      assert body["devlog_count"] == nil
      assert body["total_hours"] == nil
      assert body["followers"] == nil
      assert body["sourcecode"] == nil
      assert body["superstar"] == nil
    end

    test "returns 404 when project not found in database and API call fails", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/projects/99999")

      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Resource not found"
    end

    test "refreshes stale project when found in database", %{conn: conn, user: user} do
      stale_attrs =
        @valid_project_attrs
        |> Map.put(:user_id, user.id)
        |> Map.put(:id, 999_999)
        |> Map.put(:last_scraped_at, ~U[2026-06-15 12:00:00Z])

      {:ok, _project} = %Project{} |> Project.changeset(stale_attrs) |> Repo.insert()

      conn = get(conn, ~p"/api/v1/projects/999999")

      # Stale data triggers a refresh from the external API, which fails with 404
      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Resource not found"
    end
  end

  describe "GET /api/v1/users" do
    test "returns empty list when no users exist", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/users")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["users"] == []
      assert body["pagination"]["total_count"] == 0
    end

    test "returns paginated list of users", %{conn: conn} do
      {:ok, _} = User.changeset(struct(User), @valid_user_attrs) |> Repo.insert()

      conn = get(conn, ~p"/api/v1/users")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert length(body["users"]) == 1
      assert body["pagination"]["total_count"] == 1
    end

    test "filters users by query", %{conn: conn} do
      {:ok, _} = User.changeset(struct(User), @valid_user_attrs) |> Repo.insert()

      {:ok, _} =
        User.changeset(struct(User), %{
          Map.put(@valid_user_attrs, :username, "otheruser")
          | id: "a89e02d4-54fd-4126-bec7-ebfbb3c0f38a"
        })
        |> Repo.insert()

      conn = get(conn, ~p"/api/v1/users?query=otheruser")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert length(body["users"]) == 1
      assert hd(body["users"])["display_name"] == "otheruser"
    end
  end

  describe "GET /api/v1/users/:username" do
    test "returns user when found in database (fresh)", %{conn: conn} do
      {:ok, _user} = User.changeset(struct(User), @valid_user_attrs) |> Repo.insert()

      conn = get(conn, ~p"/api/v1/users/testuser")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["id"] == @valid_user_attrs.id
      assert body["slack_id"] == nil
      assert body["display_name"] == "testuser"
      assert body["avatar"] == "https://example.com/pfp.png"
      assert body["project_ids"] == [100, 200]
      assert body["stardust"] == nil
      assert body["username"] == nil
      assert body["bio"] == nil
    end

    test "strips leading @ from username", %{conn: conn} do
      {:ok, _user} = User.changeset(struct(User), @valid_user_attrs) |> Repo.insert()

      conn = get(conn, ~p"/api/v1/users/@testuser")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["display_name"] == "testuser"
    end

    test "returns 404 when user not found in database and API call fails", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/users/nonexistentuser")

      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Resource not found"
    end

    test "refreshes stale user when found in database", %{conn: conn} do
      stale_attrs =
        @valid_user_attrs
        |> Map.put(:last_scraped_at, ~U[2026-06-15 12:00:00Z])
        |> Map.put(:username, "nonexistent_stale_user_test")

      {:ok, _user} = User.changeset(struct(User), stale_attrs) |> Repo.insert()

      conn = get(conn, ~p"/api/v1/users/nonexistent_stale_user_test")

      # Stale data triggers a refresh from the external API, which fails with 404
      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Resource not found"
    end
  end

  describe "GET /api/v1/users/:username/projects" do
    setup do
      {:ok, user} = User.changeset(struct(User), @valid_user_attrs) |> Repo.insert()

      project_attrs = Map.put(@valid_project_attrs, :user_id, user.id)
      {:ok, _project} = %Project{} |> Project.changeset(project_attrs) |> Repo.insert()

      {:ok, user: user}
    end

    test "returns paginated projects for a user", %{conn: conn, user: user} do
      conn = get(conn, ~p"/api/v1/users/#{user.username}/projects")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert length(body["projects"]) == 1
      assert body["pagination"]["total_count"] == 1

      project = hd(body["projects"])
      assert project["id"] == 100
      assert project["title"] == "Test Project"
      assert project["repo_url"] == "https://github.com/test/project"
      assert project["demo_url"] == "https://example.com/demo"
      assert project["devlog_ids"] == [1, 2, 3]
      assert project["username"] == nil
      assert project["sourcecode"] == nil
    end

    test "strips leading @ from username", %{conn: conn, user: user} do
      conn = get(conn, ~p"/api/v1/users/@#{user.username}/projects")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert length(body["projects"]) == 1
    end

    test "returns 404 when user does not exist", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/users/nonexistentuser/projects")

      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Resource not found"
    end
  end

  describe "GET /api/v1/projects/:id/devlogs" do
    setup do
      {:ok, user} = User.changeset(struct(User), @valid_user_attrs) |> Repo.insert()

      project_attrs = Map.put(@valid_project_attrs, :user_id, user.id)
      {:ok, project} = %Project{} |> Project.changeset(project_attrs) |> Repo.insert()

      for id <- [1, 2, 3] do
        devlog_attrs =
          @valid_devlog_attrs
          |> Map.put(:id, id)
          |> Map.put(:user_id, user.id)
          |> Map.put(:project_id, project.id)

        {:ok, _} = %Devlog{} |> Devlog.changeset(devlog_attrs) |> Repo.insert()
      end

      {:ok, user: user, project: project}
    end

    test "returns paginated devlogs for a project", %{
      conn: conn,
      project: project
    } do
      conn = get(conn, ~p"/api/v1/projects/#{project.id}/devlogs")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert length(body["devlogs"]) == 3
      assert body["pagination"]["total_count"] == 3
    end

    test "limits results via limit param", %{conn: conn, project: project} do
      conn = get(conn, ~p"/api/v1/projects/#{project.id}/devlogs?limit=2")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert length(body["devlogs"]) == 2
    end

    test "returns 404 when project does not exist", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/projects/99999/devlogs")

      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Resource not found"
    end
  end

  describe "GET /api/v1/devlogs" do
    setup do
      {:ok, user} = User.changeset(struct(User), @valid_user_attrs) |> Repo.insert()

      project_attrs = Map.put(@valid_project_attrs, :user_id, user.id)
      {:ok, project} = %Project{} |> Project.changeset(project_attrs) |> Repo.insert()

      devlog_attrs =
        @valid_devlog_attrs
        |> Map.put(:user_id, user.id)
        |> Map.put(:project_id, project.id)

      {:ok, _} = %Devlog{} |> Devlog.changeset(devlog_attrs) |> Repo.insert()

      {:ok, user: user, project: project}
    end

    test "returns paginated list of all devlogs", %{
      conn: conn
    } do
      conn = get(conn, ~p"/api/v1/devlogs")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert length(body["devlogs"]) == 1
      assert body["pagination"]["total_count"] == 1
    end
  end

  describe "GET /api/v1/devlogs/:id" do
    setup do
      {:ok, user} = User.changeset(struct(User), @valid_user_attrs) |> Repo.insert()

      project_attrs = Map.put(@valid_project_attrs, :user_id, user.id)
      {:ok, project} = %Project{} |> Project.changeset(project_attrs) |> Repo.insert()

      {:ok, user: user, project: project}
    end

    test "returns devlog when found in database (fresh)", %{
      conn: conn,
      user: user,
      project: project
    } do
      devlog_attrs =
        @valid_devlog_attrs
        |> Map.put(:user_id, user.id)
        |> Map.put(:project_id, project.id)

      {:ok, _devlog} = %Devlog{} |> Devlog.changeset(devlog_attrs) |> Repo.insert()

      conn = get(conn, ~p"/api/v1/devlogs/1")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["id"] == 1
      assert body["body"] == "A test devlog entry"
      assert body["likes_count"] == 15
      assert body["duration_seconds"] == 3600
      assert body["comments_count"] == 0
      assert length(body["media"]) == 2
      assert hd(body["media"])["url"] == "https://example.com/img1.png"
      assert body["description"] == nil
      assert body["likes"] == nil
      assert body["views"] == nil
      assert body["project_id"] == nil
      assert body["user_id"] == nil
    end

    test "returns 404 when devlog not found in database", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/devlogs/99999")

      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Resource not found"
    end

    test "refreshes stale devlog when found in database", %{
      conn: conn,
      user: user,
      project: project
    } do
      stale_attrs =
        @valid_devlog_attrs
        |> Map.put(:user_id, user.id)
        |> Map.put(:project_id, project.id)
        |> Map.put(:id, 999_998)
        |> Map.put(:last_scraped_at, ~U[2026-06-15 12:00:00Z])

      {:ok, _devlog} = %Devlog{} |> Devlog.changeset(stale_attrs) |> Repo.insert()

      conn = get(conn, ~p"/api/v1/devlogs/999998")

      # Stale data triggers a refresh from the external API, which fails with 404
      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Resource not found"
    end
  end

  describe "GET /api/v1/projects/:id/devlogs/:devlog_id" do
    setup do
      {:ok, user} = User.changeset(struct(User), @valid_user_attrs) |> Repo.insert()

      project_attrs = Map.put(@valid_project_attrs, :user_id, user.id)
      {:ok, project} = %Project{} |> Project.changeset(project_attrs) |> Repo.insert()

      {:ok, user: user, project: project}
    end

    test "returns project devlog when found in database (fresh)", %{
      conn: conn,
      user: user,
      project: project
    } do
      devlog_attrs =
        @valid_devlog_attrs
        |> Map.put(:user_id, user.id)
        |> Map.put(:project_id, project.id)

      {:ok, _devlog} = %Devlog{} |> Devlog.changeset(devlog_attrs) |> Repo.insert()

      conn = get(conn, ~p"/api/v1/projects/100/devlogs/1")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["id"] == 1
      assert body["body"] == "A test devlog entry"
      assert body["likes_count"] == 15
      assert body["duration_seconds"] == 3600
      assert body["comments_count"] == 0
      assert length(body["media"]) == 2
      assert body["description"] == nil
      assert body["project_id"] == nil
      assert body["user_id"] == nil
    end

    test "returns 404 when devlog does not belong to the given project", %{conn: conn, user: user} do
      # Create a different project
      other_project_attrs =
        @valid_project_attrs
        |> Map.put(:id, 200)
        |> Map.put(:user_id, user.id)

      {:ok, other_project} = %Project{} |> Project.changeset(other_project_attrs) |> Repo.insert()

      # Create a devlog for the other project only
      devlog_attrs =
        @valid_devlog_attrs
        |> Map.put(:user_id, user.id)
        |> Map.put(:project_id, other_project.id)

      {:ok, _devlog} = %Devlog{} |> Devlog.changeset(devlog_attrs) |> Repo.insert()

      # Request the devlog under project 100 (wrong project)
      conn = get(conn, ~p"/api/v1/projects/100/devlogs/1")

      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Resource not found"
    end

    test "returns 404 when neither project nor devlog exists", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/projects/99999/devlogs/88888")

      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Resource not found"
    end

    test "refreshes stale project devlog when found in database", %{
      conn: conn,
      user: user,
      project: project
    } do
      stale_attrs =
        @valid_devlog_attrs
        |> Map.put(:user_id, user.id)
        |> Map.put(:project_id, project.id)
        |> Map.put(:id, 999_997)
        |> Map.put(:last_scraped_at, ~U[2026-06-15 12:00:00Z])

      {:ok, _devlog} = %Devlog{} |> Devlog.changeset(stale_attrs) |> Repo.insert()

      conn = get(conn, ~p"/api/v1/projects/100/devlogs/999997")

      # Stale data triggers a refresh from the external API, which fails with 404
      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Resource not found"
    end
  end
end

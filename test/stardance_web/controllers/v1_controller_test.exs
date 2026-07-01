defmodule StardanceWeb.API.V1ControllerTest do
  use StardanceWeb.ConnCase

  alias Stardance.Repo
  alias Stardance.Schema.{User, Project, Devlog}

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
    last_scraped_at: ~U[2026-07-01 12:00:00Z]
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
    last_scraped_at: ~U[2026-07-01 12:00:00Z]
  }

  @valid_devlog_attrs %{
    id: 1,
    description: "A test devlog entry",
    image_urls: ["https://example.com/img1.png", "https://example.com/img2.png"],
    likes: 15,
    views: 200,
    duration_seconds: 3600,
    last_scraped_at: ~U[2026-07-01 12:00:00Z]
  }

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
      assert body["username"] == "testuser"
      assert body["banner_url"] == "https://example.com/project-banner.png"
      assert body["devlog_count"] == 3
      assert body["devlog_ids"] == [1, 2, 3]
      assert body["total_hours"] == 12.5
      assert body["followers"] == 10
      assert body["demo_url"] == "https://example.com/demo"
      assert body["sourcecode"] == "https://github.com/test/project"
      assert body["superstar"] == false
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

  describe "GET /api/v1/users/:username" do
    test "returns user when found in database (fresh)", %{conn: conn} do
      {:ok, _user} = User.changeset(struct(User), @valid_user_attrs) |> Repo.insert()

      conn = get(conn, ~p"/api/v1/users/testuser")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["user_id"] == @valid_user_attrs.id
      assert body["username"] == "testuser"
      assert body["user_pfp"] == "https://example.com/pfp.png"
      assert body["bio"] == "A test bio"
      assert body["banner_url"] == "https://example.com/banner.png"
      # devlog_count/project_count are computed from the length of devlog_ids/project_ids
      assert body["devlog_count"] == 2
      assert body["project_count"] == 2
      assert body["project_ids"] == [100, 200]
      assert body["devlog_ids"] == [10, 20]
      assert body["ships"] == 7
      assert body["votes"] == 42
      assert body["slack_url"] == "https://slack.com/test"
    end

    test "strips leading @ from username", %{conn: conn} do
      {:ok, _user} = User.changeset(struct(User), @valid_user_attrs) |> Repo.insert()

      conn = get(conn, ~p"/api/v1/users/@testuser")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["username"] == "testuser"
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
      assert body["description"] == "A test devlog entry"

      assert body["image_urls"] == [
               "https://example.com/img1.png",
               "https://example.com/img2.png"
             ]

      assert body["likes"] == 15
      assert body["views"] == 200
      assert body["duration_seconds"] == 3600
      assert body["project_id"] == project.id
      assert body["user_id"] == user.id
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
      assert body["project_id"] == project.id
      assert body["user_id"] == user.id
      assert body["description"] == "A test devlog entry"
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

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
    comments_count: 0,
    last_scraped_at: @fresh_timestamp
  }

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

  describe "GET /api/v2/projects/top" do
    setup do
      {:ok, user} = User.changeset(struct(User), @valid_user_attrs) |> Repo.insert()

      low_project_attrs =
        Map.merge(@valid_project_attrs, %{
          user_id: user.id,
          title: "Low Score Project",
          score: 1.0
        })

      {:ok, _low_project} = %Project{} |> Project.changeset(low_project_attrs) |> Repo.insert()

      high_project_attrs =
        Map.merge(@valid_project_attrs, %{
          id: 101,
          user_id: user.id,
          title: "High Score Project",
          score: 100.0
        })

      {:ok, _high_project} = %Project{} |> Project.changeset(high_project_attrs) |> Repo.insert()

      {:ok, user: user}
    end

    test "returns top projects ranked by score with default limit of 10", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/projects/top")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert length(body["projects"]) == 2
      assert body["pagination"]["total_count"] == 2

      first = hd(body["projects"])
      assert first["rank"] == 1
      assert first["title"] == "High Score Project"
      assert first["score"] == 100.0

      second = Enum.at(body["projects"], 1)
      assert second["rank"] == 2
      assert second["title"] == "Low Score Project"
      assert second["score"] == 1.0
    end

    test "respects custom limit", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/projects/top?limit=1")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert length(body["projects"]) == 1
      assert hd(body["projects"])["rank"] == 1
    end

    test "respects page offset for ranks", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/projects/top?limit=1&page=2")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert length(body["projects"]) == 1
      assert hd(body["projects"])["rank"] == 2
    end

    test "returns empty list when no projects exist", %{conn: conn} do
      Repo.delete_all(Project)

      conn = get(conn, ~p"/api/v2/projects/top")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["projects"] == []
      assert body["pagination"]["total_count"] == 0
    end
  end

  describe "GET /api/v2/projects" do
    setup do
      {:ok, user} = User.changeset(struct(User), @valid_user_attrs) |> Repo.insert()

      project_attrs = Map.put(@valid_project_attrs, :user_id, user.id)
      {:ok, _project} = %Project{} |> Project.changeset(project_attrs) |> Repo.insert()

      {:ok, user: user}
    end

    test "returns paginated projects with V2 fields", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/projects")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert length(body["projects"]) == 1
      assert body["pagination"]["total_count"] == 1

      project = hd(body["projects"])
      assert project["id"] == 100
      assert project["title"] == "Test Project"
      assert project["username"] == "testuser"
      assert project["sourcecode"] == "https://github.com/test/project"
      assert project["superstar"] == false
      assert project["devlog_count"] == 3
      assert project["total_hours"] == 12.5
      assert project["followers"] == 10
      assert project["repo_url"] == "https://github.com/test/project"
      # V1 base fields still present
      assert project["demo_url"] == "https://example.com/demo"
      assert project["devlog_ids"] == [1, 2, 3]
      assert project["banner_url"] == "https://example.com/project-banner.png"
    end

    test "filters projects by query", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/projects?query=Other")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["projects"] == []
      assert body["pagination"]["total_count"] == 0
    end
  end

  describe "GET /api/v2/projects/:id" do
    setup do
      {:ok, user} = User.changeset(struct(User), @valid_user_attrs) |> Repo.insert()

      project_attrs = Map.put(@valid_project_attrs, :user_id, user.id)
      {:ok, project} = %Project{} |> Project.changeset(project_attrs) |> Repo.insert()

      {:ok, user: user, project: project}
    end

    test "returns V2 project with extra fields", %{conn: conn, project: project, user: user} do
      conn = get(conn, ~p"/api/v2/projects/#{project.id}")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["id"] == 100
      assert body["username"] == user.username
      assert body["sourcecode"] == "https://github.com/test/project"
      assert body["superstar"] == false
      assert body["total_hours"] == 12.5
      assert body["user_id"] == user.id
      # V1 base fields
      assert body["repo_url"] == "https://github.com/test/project"
      assert body["demo_url"] == "https://example.com/demo"
    end

    test "returns 404 when project not found", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/projects/99999")

      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Resource not found"
    end
  end

  describe "GET /api/v2/projects/:id/devlogs" do
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

    test "returns V2 devlogs with extra fields", %{conn: conn, project: project} do
      conn = get(conn, ~p"/api/v2/projects/#{project.id}/devlogs")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert length(body["devlogs"]) == 1

      devlog = hd(body["devlogs"])
      assert devlog["id"] == 1
      assert devlog["description"] == "A test devlog entry"
      assert devlog["likes"] == 15
      assert devlog["views"] == 200
      assert devlog["project_id"] == project.id
      # V1 base fields still present
      assert devlog["body"] == "A test devlog entry"
      assert devlog["likes_count"] == 15
      assert devlog["duration_seconds"] == 3600
      assert length(devlog["media"]) == 2
    end

    test "returns 404 when project does not exist", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/projects/99999/devlogs")

      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Resource not found"
    end
  end

  describe "GET /api/v2/projects/:id/devlogs/:devlog_id" do
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

    test "returns V2 devlog with extra fields", %{
      conn: conn,
      project: project,
      devlog: devlog,
      user: user
    } do
      conn = get(conn, ~p"/api/v2/projects/#{project.id}/devlogs/#{devlog.id}")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["id"] == devlog.id
      assert body["description"] == "A test devlog entry"
      assert body["likes"] == 15
      assert body["views"] == 200
      assert body["project_id"] == project.id
      assert body["user_id"] == user.id
      assert body["body"] == "A test devlog entry"
      assert body["likes_count"] == 15
    end

    test "returns 404 when devlog does not belong to the given project", %{conn: conn, user: user} do
      other_project_attrs =
        @valid_project_attrs
        |> Map.put(:id, 200)
        |> Map.put(:user_id, user.id)

      {:ok, other_project} = %Project{} |> Project.changeset(other_project_attrs) |> Repo.insert()

      devlog_attrs =
        @valid_devlog_attrs
        |> Map.put(:id, 2)
        |> Map.put(:user_id, user.id)
        |> Map.put(:project_id, other_project.id)

      {:ok, _devlog} = %Devlog{} |> Devlog.changeset(devlog_attrs) |> Repo.insert()

      conn = get(conn, ~p"/api/v2/projects/100/devlogs/2")

      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Resource not found"
    end
  end

  describe "GET /api/v2/devlogs" do
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

    test "returns paginated V2 devlogs", %{conn: conn, devlog: devlog} do
      conn = get(conn, ~p"/api/v2/devlogs")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert length(body["devlogs"]) == 1
      assert body["pagination"]["total_count"] == 1

      item = hd(body["devlogs"])
      assert item["id"] == devlog.id
      assert item["description"] == "A test devlog entry"
      assert item["likes"] == 15
      assert item["views"] == 200
      assert item["body"] == "A test devlog entry"
      assert item["likes_count"] == 15
    end
  end

  describe "GET /api/v2/devlogs/:id" do
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

    test "returns V2 devlog with extra fields", %{conn: conn, devlog: devlog, user: user} do
      conn = get(conn, ~p"/api/v2/devlogs/#{devlog.id}")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["id"] == devlog.id
      assert body["description"] == "A test devlog entry"
      assert body["likes"] == 15
      assert body["views"] == 200
      assert body["user_id"] == user.id
      assert body["body"] == "A test devlog entry"
      assert body["likes_count"] == 15
    end

    test "returns 404 when devlog not found", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/devlogs/99999")

      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Resource not found"
    end
  end

  describe "GET /api/v2/users" do
    setup do
      {:ok, user} = User.changeset(struct(User), @valid_user_attrs) |> Repo.insert()
      {:ok, user: user}
    end

    test "returns paginated V2 users", %{conn: conn, user: user} do
      conn = get(conn, ~p"/api/v2/users")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert length(body["users"]) == 1
      assert body["pagination"]["total_count"] == 1

      u = hd(body["users"])
      assert u["id"] == user.id
      assert u["username"] == "testuser"
      assert u["display_name"] == "testuser"
      assert u["bio"] == "A test bio"
      assert u["ships"] == 7
      assert u["votes"] == 42
      assert u["achievements"] == []
      # V1 base fields still present
      assert u["avatar"] == "https://example.com/pfp.png"
      assert u["project_ids"] == [100, 200]
    end

    test "filters users by query", %{conn: conn} do
      {:ok, _} =
        User.changeset(struct(User), %{
          Map.put(@valid_user_attrs, :username, "otheruser")
          | id: "a89e02d4-54fd-4126-bec7-ebfbb3c0f38a"
        })
        |> Repo.insert()

      conn = get(conn, ~p"/api/v2/users?query=otheruser")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert length(body["users"]) == 1
      assert hd(body["users"])["username"] == "otheruser"
    end
  end

  describe "GET /api/v2/users/:username" do
    setup do
      {:ok, user} = User.changeset(struct(User), @valid_user_attrs) |> Repo.insert()
      {:ok, user: user}
    end

    test "returns V2 user with extra fields", %{conn: conn, user: user} do
      conn = get(conn, ~p"/api/v2/users/#{user.username}")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["id"] == user.id
      assert body["username"] == "testuser"
      assert body["display_name"] == "testuser"
      assert body["bio"] == "A test bio"
      assert body["banner_url"] == "https://example.com/banner.png"
      assert body["ships"] == 7
      assert body["votes"] == 42
      assert body["achievements"] == []
      assert body["avatar"] == "https://example.com/pfp.png"
      assert body["project_ids"] == [100, 200]
      assert body["devlog_ids"] == [10, 20]
    end

    test "strips leading @ from username", %{conn: conn, user: user} do
      conn = get(conn, ~p"/api/v2/users/@#{user.username}")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["username"] == "testuser"
    end

    test "returns 404 when user does not exist", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/users/nonexistentuser")

      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Resource not found"
    end
  end

  describe "GET /api/v2/users/:username/projects" do
    setup do
      {:ok, user} = User.changeset(struct(User), @valid_user_attrs) |> Repo.insert()

      project_attrs = Map.put(@valid_project_attrs, :user_id, user.id)
      {:ok, _project} = %Project{} |> Project.changeset(project_attrs) |> Repo.insert()

      {:ok, user: user}
    end

    test "returns V2 projects for a user", %{conn: conn, user: user} do
      conn = get(conn, ~p"/api/v2/users/#{user.username}/projects")

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert length(body["projects"]) == 1
      assert body["pagination"]["total_count"] == 1

      project = hd(body["projects"])
      assert project["id"] == 100
      assert project["username"] == "testuser"
      assert project["sourcecode"] == "https://github.com/test/project"
      assert project["superstar"] == false
      # V1 base fields
      assert project["repo_url"] == "https://github.com/test/project"
      assert project["demo_url"] == "https://example.com/demo"
    end

    test "returns 404 when user does not exist", %{conn: conn} do
      conn = get(conn, ~p"/api/v2/users/nonexistentuser/projects")

      assert conn.status == 404
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "Resource not found"
    end
  end
end

defmodule StardanceWeb.Router do
  use StardanceWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {StardanceWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticate do
    plug StardanceWeb.Plugs.Authenticate
  end

  scope "/auth", alias: false do
    pipe_through :browser
    forward "/", Amur.Router
  end

  scope "/", StardanceWeb do
    pipe_through :browser

    get "/", PageController, :lander
    get "/signin", PageController, :signin
    get "/docs", PageController, :docs
  end

  scope "/", StardanceWeb do
    pipe_through [:browser, :authenticate]

    get "/dash", PageController, :dash
  end

  scope "/api/v1", StardanceWeb do
    pipe_through :api

    get "/projects", API.V1Controller, :index
    get "/projects/:id", API.V1Controller, :projects
    get "/projects/:id/devlogs", API.V1Controller, :project_devlogs
    get "/projects/:id/devlogs/:devlog_id", API.V1Controller, :project_devlog

    get "/devlogs", API.V1Controller, :devlogs_index
    get "/devlogs/:id", API.V1Controller, :devlogs

    get "/users", API.V1Controller, :list_users
    get "/users/:username", API.V1Controller, :users
  end

  scope "/api/v2", StardanceWeb do
    pipe_through :api

    get "/comments/devlog/:id", API.V2Controller, :devlog_comments
    get "/comments/project/:id", API.V2Controller, :project_comments

    get "/users/:username/projects", API.V2Controller, :user_projects
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:stardance, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: StardanceWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

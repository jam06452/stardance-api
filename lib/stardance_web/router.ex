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

  scope "/", StardanceWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/api/v1", StardanceWeb do
    pipe_through :api

    get "/projects/:id", API.V1Controller, :projects
    get "/users/:username", API.V1Controller, :users
    get "/devlogs/:id", API.V1Controller, :devlogs
  end

  # Other scopes may use custom stacks.
  # scope "/api", StardanceWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:stardance, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: StardanceWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

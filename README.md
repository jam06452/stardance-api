# Stardance API

> An unofficial REST API for [stardance.hackclub.com](https://stardance.hackclub.com) — the platform where Hack Clubbers showcase their projects with video demos and devlogs.

I got tired of waiting for an official API for Stardance, so I built my own. It scrapes the Stardance website and caches results in a PostgreSQL database, serving them back as clean JSON.

## How it works

Stardance doesn't have a public API — it's a standard Rails app that renders HTML. This project works around that in three layers:

### 1. Scraping — `Stardance.Utils`

Uses [`Req`](https://hex.pm/packages/req) to fetch HTML pages from the Stardance website (authenticated via a session cookie) and [`Floki`](https://hex.pm/packages/floki) to parse and extract structured data from the DOM.

Supports four data types:
- **Projects** — title, description, author, banner, stats (devlogs count, total hours), demo/source links, follower count, superstar status
- **Users** — username, avatar, bio, banner, stats (devlogs, projects, ships, votes), Slack link
- **Devlogs** — description, images, likes, views, duration

### 2. Database & caching — `Stardance.DB`

Scraped data is cached in a **PostgreSQL database** (via Ecto) to avoid hammering the Stardance site on every request. The caching logic:

- **Cache miss** → scrape from Stardance, store in DB, return result
- **Cache hit, fresh** (scraped within 12 hours) → return cached data immediately
- **Cache hit, stale** → scrape fresh data, upsert in DB, return fresh result, and **background-scrape related resources** (e.g., a project's devlogs)

Background scraping is dispatched via `Task.Supervisor` (`Stardance.ScrapeSupervisor`) so the API responds quickly while related data populates asynchronously.

### 3. JSON API — `StardanceWeb.API.V1Controller`

A thin Phoenix controller layer that translates internal data into JSON responses.

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/projects/:id` | Get project details |
| `GET` | `/api/v1/projects/:id/devlogs/:devlog_id` | Get a specific devlog for a project |
| `GET` | `/api/v1/users/:username` | Get user/profile details |
| `GET` | `/api/v1/devlogs/:id` | Get a devlog by its ID |

There's also a documentation page at `/` that renders the API reference.

## Data Model

### User
Stored with a `binary_id` primary key. Tied to projects and devlogs via associations.

| Field | Type | Description |
|-------|------|-------------|
| `username` | `string` | Unique username |
| `user_pfp` | `string` | Avatar URL |
| `banner_url` | `string` | Profile banner URL |
| `bio` | `string` | User bio |
| `project_ids` | `array<int>` | IDs of the user's projects |
| `devlog_ids` | `array<int>` | IDs of the user's devlogs |
| `ships` | `integer` | Ship count |
| `votes` | `integer` | Vote count |

### Project
Uses the same integer ID as the Stardance website (`autogenerate: false`).

| Field | Type | Description |
|-------|------|-------------|
| `id` | `integer` | Stardance project ID |
| `title` | `string` | Project title |
| `description` | `string` | Project description |
| `username` | `string` | (via `belongs_to :user`) |
| `banner_url` | `string` | Banner image URL |
| `devlog_count` | `integer` | Number of devlogs |
| `total_hours` | `float` | Total logged hours |
| `demo_url` | `string` | Demo/website link |
| `source_code` | `string` | Source code link |
| `followers` | `integer` | Follower count |
| `super_star` | `boolean` | Superstar status |

### Devlog
Uses the same integer ID as the Stardance website.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `integer` | Stardance devlog/post ID |
| `description` | `string` | Devlog body text |
| `image_urls` | `array<string>` | Attached image URLs |
| `likes` | `integer` | Like count |
| `views` | `integer` | Unique viewer count |
| `duration_seconds` | `integer` | Video duration if applicable |

**Caching note**: devlogs and devlog lists are only populated via background scraping, so a fresh project or user response may initially return empty `devlog_ids`. They'll be populated on subsequent requests.

## Setup

### Prerequisites

- Elixir & OTP (see `.tool-versions` or the Elixir requirement in `mix.exs`)
- PostgreSQL
- A valid Stardance session cookie (you need to be logged into stardance.hackclub.com)

### Getting started

```bash
# Get dependencies
mix setup

# Set your Stardance session cookie in a .env file
echo "STARDANCE_COOKIE=your_session_cookie_here" > .env

# Start the dev server
mix phx.server
```

> **On the session cookie**: Open [stardance.hackclub.com](https://stardance.hackclub.com) in your browser while logged in, open DevTools, find the `_stardance_session_v3` cookie, and copy its value. Without this, the scraper will get redirected to the login page and fail.

## Tech stack

| Component | Library |
|-----------|---------|
| Web framework | [Phoenix](https://www.phoenixframework.org/) (v1.8) |
| HTTP client | [Req](https://hex.pm/packages/req) |
| HTML parsing | [Floki](https://hex.pm/packages/floki) |
| Database | PostgreSQL via Ecto |
| ORM | [Ecto](https://hex.pm/packages/ecto) |
| HTTP server | [Bandit](https://hex.pm/packages/bandit) |
| JS bundler | esbuild |
| CSS | Tailwind CSS v4 |
| URL shortener | External service at `url.jam06452.uk` |

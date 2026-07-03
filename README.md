# Stardance API

API for accessing Stardance hackclub project data. All endpoints are read-only and return cached results. When cached data is older than 12 hours, the requested resource is re-scraped synchronously while cascading refreshes run in the background.

## Endpoints:

Stardance API endpoints and their return payloads:

### Projects

* **`GET /api/v1/projects`**
* **Returns:** A JSON object containing a paginated array of `Project` objects and `Pagination` details.


* **`GET /api/v1/projects/{id}`**
* **Returns:** A single `Project` JSON object matching the provided ID. (Returns `404` if not found).


* **`GET /api/v1/projects/{id}/devlogs`**
* **Returns:** A JSON object containing a paginated array of `Devlog` objects that belong to the specified project, alongside `Pagination` data.


* **`GET /api/v1/projects/{id}/devlogs/{devlog_id}`**
* **Returns:** A single `Devlog` JSON object scoped to the specified project. (Returns `404` if the project or devlog is not found).



---

### Devlogs

* **`GET /api/v1/devlogs`**
* **Returns:** A JSON object containing a paginated array of `Devlog` objects across *all* projects, alongside `Pagination` data.


* **`GET /api/v1/devlogs/{id}`**
* **Returns:** A single `Devlog` JSON object matching the requested ID. (Returns `404` if not found).



---

### Users

* **`GET /api/v1/users`**
* **Returns:** A JSON object containing a paginated array of `User` objects and `Pagination` data.


* **`GET /api/v1/users/{username}`**
* **Returns:** A single `User` JSON object representing the requested profile. (Returns `404` if not found).


* **`GET /api/v2/users/{username}/projects`**
* **Returns:** A JSON object containing a paginated array of `Project` objects belonging to the specified user, alongside `Pagination` data.



---

### Comments (v2)

* **`GET /api/v2/comments/devlog/{id}`**
* **Returns:** A JSON array of `Comment` objects belonging to the specified devlog. (Returns `404` if the devlog is not found).


* **`GET /api/v2/comments/project/{id}`**
* **Returns:** A JSON array of `Comment` objects spanning across all devlogs belonging to the specified project. (Returns `404` if the project is not found).

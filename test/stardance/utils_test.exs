defmodule Stardance.UtilsTest do
  use ExUnit.Case, async: true

  alias Stardance.Utils

  describe "readme_url_from_repo/1" do
    test "returns nil for nil or empty input" do
      assert Utils.readme_url_from_repo(nil) == nil
      assert Utils.readme_url_from_repo("") == nil
    end

    test "derives raw README URL from a github.com repo URL" do
      assert Utils.readme_url_from_repo("https://github.com/jam06452/stardance-api") ==
               "https://raw.githubusercontent.com/jam06452/stardance-api/refs/heads/main/README.md"

      assert Utils.readme_url_from_repo("https://github.com/jam06452/stardance-api/") ==
               "https://raw.githubusercontent.com/jam06452/stardance-api/refs/heads/main/README.md"

      assert Utils.readme_url_from_repo("https://github.com/imdevarsh/gorkie") ==
               "https://raw.githubusercontent.com/imdevarsh/gorkie/refs/heads/main/README.md"
    end

    test "strips www and handles non-https input" do
      assert Utils.readme_url_from_repo("www.github.com/foo/bar") ==
               "https://raw.githubusercontent.com/foo/bar/refs/heads/main/README.md"

      assert Utils.readme_url_from_repo("http://github.com/foo/bar") ==
               "https://raw.githubusercontent.com/foo/bar/refs/heads/main/README.md"
    end

    test "tolerates trailing path segments" do
      assert Utils.readme_url_from_repo("https://github.com/foo/bar/tree/main/sub") ==
               "https://raw.githubusercontent.com/foo/bar/refs/heads/main/README.md"
    end

    test "returns nil for non-github URLs" do
      assert Utils.readme_url_from_repo("https://gitlab.com/foo/bar") == nil
      assert Utils.readme_url_from_repo("https://example.com") == nil
    end

    test "returns nil for a github URL without an owner/repo pair" do
      assert Utils.readme_url_from_repo("https://github.com/foo") == nil
    end
  end
end

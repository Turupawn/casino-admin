require "test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  test "should get home" do
    get games_home_url
    assert_response :success
  end
end

require "test_helper"

class MunicipalitiesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get municipalities_index_url
    assert_response :success
  end

  test "should get show" do
    get municipalities_show_url
    assert_response :success
  end
end

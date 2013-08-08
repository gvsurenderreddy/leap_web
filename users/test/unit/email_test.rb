require 'test_helper'

class EmailTest < ActiveSupport::TestCase

  test "valid format" do
    email = Email.new(email_string)
    assert email.valid?
  end

  test "validates format" do
    email = Email.new("email")
    assert !email.valid?
    assert_equal ["needs to be a valid email address"], email.errors[:email]
  end

  def email_string
    @email_string ||= Faker::Internet.email
  end
end

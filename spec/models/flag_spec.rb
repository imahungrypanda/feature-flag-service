# frozen_string_literal: true

require "rails_helper"

RSpec.describe Flag, type: :model do
  describe "validations" do
    it "is valid with a unique key" do
      flag = described_class.new(key: "my_feature", enabled: false)
      expect(flag).to be_valid
    end

    it "requires key to be present" do
      flag = described_class.new(key: nil, enabled: false)
      expect(flag).not_to be_valid
      expect(flag.errors[:key]).to include("can't be blank")
    end

    it "requires key to be unique" do
      described_class.create!(key: "existing_key", enabled: false)
      duplicate = described_class.new(key: "existing_key", enabled: true)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:key]).to include("has already been taken")
    end
  end

  describe "defaults" do
    it "defaults enabled to false" do
      flag = described_class.create!(key: "default_flag")
      expect(flag.enabled).to be false
    end

    it "allows description to be nil" do
      flag = described_class.create!(key: "no_desc")
      expect(flag.description).to be_nil
    end
  end
end

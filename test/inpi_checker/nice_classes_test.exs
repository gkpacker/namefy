defmodule InpiChecker.NiceClassesTest do
  use ExUnit.Case, async: true

  alias InpiChecker.NiceClasses

  describe "description/1" do
    test "returns description for class 1" do
      assert NiceClasses.description(1) == "Chemicals"
    end

    test "returns description for class 9 (software)" do
      assert NiceClasses.description(9) == "Software, electronics, computers"
    end

    test "returns description for class 25 (clothing)" do
      assert NiceClasses.description(25) == "Clothing, footwear"
    end

    test "returns description for class 36 (financial services)" do
      assert NiceClasses.description(36) == "Financial services, insurance, banking"
    end

    test "returns description for class 42 (technology services)" do
      assert NiceClasses.description(42) == "Technology services, SaaS, software development"
    end

    test "returns description for class 45 (last class)" do
      assert NiceClasses.description(45) == "Legal services, security"
    end

    test "returns nil for class 0" do
      assert NiceClasses.description(0) == nil
    end

    test "returns nil for class 46" do
      assert NiceClasses.description(46) == nil
    end

    test "returns nil for negative class numbers" do
      assert NiceClasses.description(-1) == nil
      assert NiceClasses.description(-100) == nil
    end

    test "returns nil for very large class numbers" do
      assert NiceClasses.description(1000) == nil
    end
  end

  describe "valid?/1" do
    test "returns true for class 1" do
      assert NiceClasses.valid?(1)
    end

    test "returns true for class 45" do
      assert NiceClasses.valid?(45)
    end

    test "returns true for all classes 1-45" do
      for class <- 1..45 do
        assert NiceClasses.valid?(class), "Class #{class} should be valid"
      end
    end

    test "returns false for class 0" do
      refute NiceClasses.valid?(0)
    end

    test "returns false for class 46" do
      refute NiceClasses.valid?(46)
    end

    test "returns false for negative numbers" do
      refute NiceClasses.valid?(-1)
      refute NiceClasses.valid?(-100)
    end

    test "returns false for large numbers" do
      refute NiceClasses.valid?(100)
      refute NiceClasses.valid?(1000)
    end
  end

  describe "all/0" do
    test "returns a map with 45 entries" do
      all_classes = NiceClasses.all()

      assert map_size(all_classes) == 45
    end

    test "includes all classes from 1 to 45" do
      all_classes = NiceClasses.all()

      for class <- 1..45 do
        assert Map.has_key?(all_classes, class), "Should include class #{class}"
      end
    end

    test "all values are non-empty strings" do
      all_classes = NiceClasses.all()

      for {_class, description} <- all_classes do
        assert is_binary(description)
        assert String.length(description) > 0
      end
    end

    test "product classes are 1-34" do
      # Product classes should have descriptions
      product_classes = 1..34

      for class <- product_classes do
        description = NiceClasses.description(class)
        assert description != nil, "Product class #{class} should have description"
      end
    end

    test "service classes are 35-45" do
      # Service classes should have descriptions
      service_classes = 35..45

      for class <- service_classes do
        description = NiceClasses.description(class)
        assert description != nil, "Service class #{class} should have description"
      end
    end
  end

  describe "common business use cases" do
    test "fintech/finance app classes have correct descriptions" do
      # Class 9: Software/apps
      assert NiceClasses.description(9) == "Software, electronics, computers"
      # Class 36: Financial services
      assert NiceClasses.description(36) == "Financial services, insurance, banking"
      # Class 42: Tech services
      assert NiceClasses.description(42) == "Technology services, SaaS, software development"
    end

    test "e-commerce platform classes have correct descriptions" do
      # Class 9: Software
      assert NiceClasses.description(9) == "Software, electronics, computers"
      # Class 35: Retail/advertising
      assert NiceClasses.description(35) == "Advertising, business management, retail"
      # Class 42: Tech services
      assert NiceClasses.description(42) == "Technology services, SaaS, software development"
    end

    test "clothing brand classes have correct descriptions" do
      # Class 25: Clothing
      assert NiceClasses.description(25) == "Clothing, footwear"
      # Class 35: Retail
      assert NiceClasses.description(35) == "Advertising, business management, retail"
    end

    test "restaurant/food business classes have correct descriptions" do
      # Class 29: Meat, fish, dairy
      assert NiceClasses.description(29) == "Meat, fish, dairy"
      # Class 30: Coffee, bakery
      assert NiceClasses.description(30) == "Coffee, tea, bakery"
      # Class 43: Food services
      assert NiceClasses.description(43) == "Food services, restaurants"
    end

    test "education platform classes have correct descriptions" do
      # Class 9: Software
      assert NiceClasses.description(9) == "Software, electronics, computers"
      # Class 41: Education
      assert NiceClasses.description(41) == "Education, entertainment"
      # Class 42: Tech services
      assert NiceClasses.description(42) == "Technology services, SaaS, software development"
    end
  end

  describe "edge cases" do
    test "handles non-integer input gracefully" do
      # Should not crash with non-integer input
      refute NiceClasses.valid?(1.5)
      refute NiceClasses.valid?("9")
      refute NiceClasses.valid?(:nine)
      refute NiceClasses.valid?(nil)
    end

    test "boundary validation is inclusive" do
      assert NiceClasses.valid?(1), "Class 1 should be valid (lower boundary)"
      assert NiceClasses.valid?(45), "Class 45 should be valid (upper boundary)"
      refute NiceClasses.valid?(0), "Class 0 should be invalid"
      refute NiceClasses.valid?(46), "Class 46 should be invalid"
    end
  end
end

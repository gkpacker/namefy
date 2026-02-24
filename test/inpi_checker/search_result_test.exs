defmodule InpiChecker.SearchResultTest do
  use ExUnit.Case, async: true

  alias InpiChecker.SearchResult

  describe "to_json/1" do
    test "converts complete SearchResult to JSON-compatible map" do
      result = %SearchResult{
        brand: "NUBANK",
        class: 36,
        class_description: "Financial services, insurance, banking",
        mode: :exact,
        search_performed: "exact:NUBANK",
        total_results: 3,
        blocking_conflicts: [
          %{
            name: "NUBANK",
            process: "123456789",
            status: "Registro",
            holder: "NU PAGAMENTOS S.A.",
            risk: "HIGH"
          }
        ],
        potential_conflicts: [
          %{
            name: "NUBANK PAY",
            process: "987654321",
            status: "Pedido",
            holder: "NU PAGAMENTOS S.A.",
            risk: "MEDIUM"
          }
        ],
        safe_matches: [
          %{
            name: "NUBANK OLD",
            process: "111222333",
            status: "Arquivado",
            holder: "OLD COMPANY",
            risk: "LOW"
          }
        ],
        recommendation: :blocked,
        summary: "Found 1 active registration(s) blocking this brand in class 36",
        searched_at: ~U[2024-01-01 10:00:00Z]
      }

      json = SearchResult.to_json(result)

      assert json["brand"] == "NUBANK"
      assert json["class"] == 36
      assert json["class_description"] == "Financial services, insurance, banking"
      assert json["mode"] == "exact"
      assert json["search_performed"] == "exact:NUBANK"
      assert json["total_results"] == 3
      assert json["recommendation"] == "BLOCKED"
      assert json["summary"] == "Found 1 active registration(s) blocking this brand in class 36"
    end

    test "converts mode atom to string" do
      result = %SearchResult{
        brand: "TEST",
        class: 9,
        mode: :radical,
        recommendation: :clear,
        blocking_conflicts: [],
        potential_conflicts: [],
        safe_matches: [],
        total_results: 0,
        search_performed: "radical:TEST",
        summary: "Clear",
        searched_at: DateTime.utc_now()
      }

      json = SearchResult.to_json(result)

      assert json["mode"] == "radical"
    end

    test "converts recommendation atom to uppercase string" do
      test_cases = [
        {:clear, "CLEAR"},
        {:caution, "CAUTION"},
        {:blocked, "BLOCKED"},
        {:error, "ERROR"}
      ]

      for {recommendation, expected} <- test_cases do
        result = %SearchResult{
          brand: "TEST",
          class: 9,
          mode: :exact,
          recommendation: recommendation,
          blocking_conflicts: [],
          potential_conflicts: [],
          safe_matches: [],
          total_results: 0,
          search_performed: "test",
          summary: "Test",
          searched_at: DateTime.utc_now()
        }

        json = SearchResult.to_json(result)
        assert json["recommendation"] == expected
      end
    end

    test "includes all conflict arrays in JSON" do
      blocking = [%{name: "BLOCKED", process: "123", status: "Registro", holder: "H1", risk: "HIGH"}]
      potential = [%{name: "POTENTIAL", process: "456", status: "Pedido", holder: "H2", risk: "MEDIUM"}]
      safe = [%{name: "SAFE", process: "789", status: "Arquivado", holder: "H3", risk: "LOW"}]

      result = %SearchResult{
        brand: "TEST",
        class: 9,
        mode: :exact,
        recommendation: :blocked,
        blocking_conflicts: blocking,
        potential_conflicts: potential,
        safe_matches: safe,
        total_results: 3,
        search_performed: "exact:TEST",
        summary: "Test summary",
        searched_at: DateTime.utc_now()
      }

      json = SearchResult.to_json(result)

      assert json["blocking_conflicts"] == blocking
      assert json["potential_conflicts"] == potential
      assert json["safe_matches"] == safe
    end

    test "handles empty conflict arrays" do
      result = %SearchResult{
        brand: "TEST",
        class: 9,
        mode: :exact,
        recommendation: :clear,
        blocking_conflicts: [],
        potential_conflicts: [],
        safe_matches: [],
        total_results: 0,
        search_performed: "exact:TEST",
        summary: "No conflicts found",
        searched_at: DateTime.utc_now()
      }

      json = SearchResult.to_json(result)

      assert json["blocking_conflicts"] == []
      assert json["potential_conflicts"] == []
      assert json["safe_matches"] == []
    end
  end

  describe "error/3" do
    test "creates error result with basic information" do
      result = SearchResult.error("TESTBRAND", 36, "Connection timeout")

      assert result.brand == "TESTBRAND"
      assert result.class == 36
      assert result.class_description == "Financial services, insurance, banking"
      assert result.mode == :exact
      assert result.search_performed == "error"
      assert result.total_results == 0
      assert result.recommendation == :error
      assert result.blocking_conflicts == []
      assert result.potential_conflicts == []
      assert result.safe_matches == []
      assert %DateTime{} = result.searched_at
    end

    test "includes error reason in summary" do
      result = SearchResult.error("BRAND", 9, "Database unavailable")

      assert result.summary == "Search failed: \"Database unavailable\""
    end

    test "handles different error reasons" do
      test_cases = [
        "Connection timeout",
        "Invalid credentials",
        "Rate limit exceeded",
        {:error, :timeout}
      ]

      for reason <- test_cases do
        result = SearchResult.error("BRAND", 9, reason)

        assert result.recommendation == :error
        assert String.starts_with?(result.summary, "Search failed:")
      end
    end

    test "sets class description correctly" do
      result = SearchResult.error("BRAND", 42, "Error")

      assert result.class_description == "Technology services, SaaS, software development"
    end

    test "handles invalid class numbers gracefully" do
      result = SearchResult.error("BRAND", 999, "Error")

      assert result.class == 999
      assert result.class_description == nil
    end

    test "creates valid timestamp" do
      before = DateTime.utc_now()
      result = SearchResult.error("BRAND", 9, "Error")
      after_time = DateTime.utc_now()

      assert DateTime.compare(result.searched_at, before) in [:gt, :eq]
      assert DateTime.compare(result.searched_at, after_time) in [:lt, :eq]
    end
  end

  describe "struct validation" do
    test "creates valid SearchResult with all required fields" do
      result = %SearchResult{
        brand: "TEST",
        class: 9,
        class_description: "Software",
        mode: :exact,
        search_performed: "exact:TEST",
        total_results: 0,
        blocking_conflicts: [],
        potential_conflicts: [],
        safe_matches: [],
        recommendation: :clear,
        summary: "Test",
        searched_at: DateTime.utc_now()
      }

      assert %SearchResult{} = result
      assert result.brand == "TEST"
    end

    test "allows nil values for optional fields" do
      result = %SearchResult{
        brand: nil,
        class: nil,
        class_description: nil,
        mode: nil,
        search_performed: nil,
        total_results: nil,
        blocking_conflicts: nil,
        potential_conflicts: nil,
        safe_matches: nil,
        recommendation: nil,
        summary: nil,
        searched_at: nil
      }

      assert %SearchResult{} = result
    end
  end

  describe "recommendation types" do
    test "supports all valid recommendation types" do
      recommendations = [:clear, :caution, :blocked, :error]

      for rec <- recommendations do
        result = %SearchResult{
          brand: "TEST",
          class: 9,
          mode: :exact,
          recommendation: rec,
          blocking_conflicts: [],
          potential_conflicts: [],
          safe_matches: [],
          total_results: 0,
          search_performed: "test",
          summary: "Test",
          searched_at: DateTime.utc_now()
        }

        assert result.recommendation == rec

        json = SearchResult.to_json(result)
        assert is_binary(json["recommendation"])
      end
    end
  end

  describe "mode types" do
    test "supports exact and radical modes" do
      modes = [:exact, :radical]

      for mode <- modes do
        result = %SearchResult{
          brand: "TEST",
          class: 9,
          mode: mode,
          recommendation: :clear,
          blocking_conflicts: [],
          potential_conflicts: [],
          safe_matches: [],
          total_results: 0,
          search_performed: "#{mode}:TEST",
          summary: "Test",
          searched_at: DateTime.utc_now()
        }

        assert result.mode == mode

        json = SearchResult.to_json(result)
        assert json["mode"] == to_string(mode)
      end
    end
  end

  describe "edge cases" do
    test "handles very long brand names" do
      long_name = String.duplicate("A", 1000)
      result = SearchResult.error(long_name, 9, "Error")

      assert result.brand == long_name
      assert byte_size(result.brand) == 1000
    end

    test "handles special characters in brand name" do
      special_brand = "CAFÉ & BAR™"
      result = SearchResult.error(special_brand, 43, "Error")

      assert result.brand == special_brand
    end

    test "handles large conflict arrays" do
      large_array = Enum.map(1..1000, fn i ->
        %{name: "BRAND#{i}", process: "#{i}", status: "Registro", holder: "H#{i}", risk: "HIGH"}
      end)

      result = %SearchResult{
        brand: "TEST",
        class: 9,
        mode: :exact,
        recommendation: :blocked,
        blocking_conflicts: large_array,
        potential_conflicts: [],
        safe_matches: [],
        total_results: 1000,
        search_performed: "exact:TEST",
        summary: "Many conflicts",
        searched_at: DateTime.utc_now()
      }

      json = SearchResult.to_json(result)
      assert length(json["blocking_conflicts"]) == 1000
    end

    test "handles empty strings in fields" do
      result = %SearchResult{
        brand: "",
        class: 9,
        class_description: "",
        mode: :exact,
        search_performed: "",
        total_results: 0,
        blocking_conflicts: [],
        potential_conflicts: [],
        safe_matches: [],
        recommendation: :clear,
        summary: "",
        searched_at: DateTime.utc_now()
      }

      json = SearchResult.to_json(result)
      assert json["brand"] == ""
      assert json["summary"] == ""
    end
  end
end

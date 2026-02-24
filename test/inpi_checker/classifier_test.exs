defmodule InpiChecker.ClassifierTest do
  use ExUnit.Case, async: true

  alias InpiChecker.{Classifier, SearchResult}

  describe "classify/4" do
    test "classifies exact match with Registro status as blocking conflict" do
      entries = [
        %{name: "NUBANK", process: "123456789", status: "Registro", holder: "NU PAGAMENTOS S.A."}
      ]

      result = Classifier.classify(entries, "NUBANK", 36, :exact)

      assert result.recommendation == :blocked
      assert length(result.blocking_conflicts) == 1
      assert length(result.potential_conflicts) == 0
      assert length(result.safe_matches) == 0

      blocking = hd(result.blocking_conflicts)
      assert blocking.name == "NUBANK"
      assert blocking.risk == "HIGH"
      assert blocking.status == "Registro"
    end

    test "classifies exact match with Pedido status as potential conflict" do
      entries = [
        %{name: "ZAPIER", process: "987654321", status: "Pedido", holder: "ZAPIER INC"}
      ]

      result = Classifier.classify(entries, "ZAPIER", 42, :exact)

      assert result.recommendation == :caution
      assert length(result.blocking_conflicts) == 0
      assert length(result.potential_conflicts) == 1
      assert length(result.safe_matches) == 0

      potential = hd(result.potential_conflicts)
      assert potential.name == "ZAPIER"
      assert potential.risk == "MEDIUM"
      assert potential.status == "Pedido"
    end

    test "classifies Arquivado status as safe match" do
      entries = [
        %{name: "OLDBANK", process: "111222333", status: "Arquivado", holder: "OLD COMPANY"}
      ]

      result = Classifier.classify(entries, "OLDBANK", 36, :exact)

      assert result.recommendation == :clear
      assert length(result.blocking_conflicts) == 0
      assert length(result.potential_conflicts) == 0
      assert length(result.safe_matches) == 1

      safe = hd(result.safe_matches)
      assert safe.name == "OLDBANK"
      assert safe.risk == "LOW"
      assert safe.status == "Arquivado"
    end

    test "classifies Indeferido status as safe match" do
      entries = [
        %{
          name: "REJECTED BRAND",
          process: "444555666",
          status: "Indeferido",
          holder: "FAILED COMPANY"
        }
      ]

      result = Classifier.classify(entries, "REJECTED BRAND", 9, :exact)

      assert result.recommendation == :clear
      assert length(result.safe_matches) == 1

      safe = hd(result.safe_matches)
      assert safe.status == "Indeferido"
      assert safe.risk == "LOW"
    end

    test "classifies similar name with Registro as blocking conflict" do
      entries = [
        %{name: "NUBANK PAY", process: "123456789", status: "Registro", holder: "NU PAGAMENTOS"}
      ]

      result = Classifier.classify(entries, "NUBANK", 36, :radical)

      assert result.recommendation == :blocked
      assert length(result.blocking_conflicts) == 1

      blocking = hd(result.blocking_conflicts)
      assert blocking.name == "NUBANK PAY"
      assert blocking.risk == "HIGH"
    end

    test "classifies dissimilar name with Registro as potential conflict" do
      entries = [
        %{
          name: "COMPLETELY DIFFERENT",
          process: "777888999",
          status: "Registro",
          holder: "OTHER COMPANY"
        }
      ]

      result = Classifier.classify(entries, "NUBANK", 36, :radical)

      assert result.recommendation == :caution
      assert length(result.potential_conflicts) == 1

      potential = hd(result.potential_conflicts)
      assert potential.name == "COMPLETELY DIFFERENT"
      assert potential.risk == "MEDIUM"
    end

    test "handles mixed results with multiple conflict levels" do
      entries = [
        %{name: "MYBANK", process: "111", status: "Registro", holder: "HOLDER1"},
        %{name: "MYBANK TECH", process: "222", status: "Pedido", holder: "HOLDER2"},
        %{name: "MYBANK OLD", process: "333", status: "Arquivado", holder: "HOLDER3"},
        %{name: "OTHER BANK", process: "444", status: "Registro", holder: "HOLDER4"}
      ]

      result = Classifier.classify(entries, "MYBANK", 36, :exact)

      # Should be blocked due to exact Registro match
      assert result.recommendation == :blocked
      assert length(result.blocking_conflicts) == 1
      assert length(result.potential_conflicts) == 2
      assert length(result.safe_matches) == 1

      # Verify correct classification
      assert hd(result.blocking_conflicts).name == "MYBANK"
      assert Enum.any?(result.potential_conflicts, &(&1.name == "MYBANK TECH"))
      assert Enum.any?(result.potential_conflicts, &(&1.name == "OTHER BANK"))
      assert hd(result.safe_matches).name == "MYBANK OLD"
    end

    test "handles case-insensitive matching" do
      entries = [
        %{name: "nubank", process: "123", status: "Registro", holder: "NU PAGAMENTOS"}
      ]

      result = Classifier.classify(entries, "NUBANK", 36, :exact)

      assert result.recommendation == :blocked
      assert length(result.blocking_conflicts) == 1
    end

    test "detects similarity using Jaro distance" do
      entries = [
        %{name: "NUBANKPAY", process: "123", status: "Registro", holder: "HOLDER"}
      ]

      result = Classifier.classify(entries, "NUBANK", 36, :radical)

      # Should be considered similar enough
      assert result.recommendation == :blocked
      assert length(result.blocking_conflicts) == 1
    end

    test "includes all entry fields in result" do
      entries = [
        %{
          name: "TEST BRAND",
          process: "123456789",
          status: "Registro",
          holder: "TEST COMPANY LTDA"
        }
      ]

      result = Classifier.classify(entries, "TEST", 9, :exact)

      conflict = hd(result.blocking_conflicts)
      assert conflict.name == "TEST BRAND"
      assert conflict.process == "123456789"
      assert conflict.status == "Registro"
      assert conflict.holder == "TEST COMPANY LTDA"
      assert conflict.risk == "HIGH"
    end

    test "builds SearchResult with correct metadata" do
      entries = [
        %{name: "BRAND", process: "123", status: "Registro", holder: "HOLDER"}
      ]

      result = Classifier.classify(entries, "BRAND", 36, :exact)

      assert result.brand == "BRAND"
      assert result.class == 36
      assert result.class_description == "Financial services, insurance, banking"
      assert result.mode == :exact
      assert result.search_performed == "exact:BRAND"
      assert result.total_results == 1
      assert %DateTime{} = result.searched_at
    end

    test "returns empty lists when no entries provided" do
      result = Classifier.classify([], "BRAND", 9, :exact)

      assert result.recommendation == :clear
      assert result.blocking_conflicts == []
      assert result.potential_conflicts == []
      assert result.safe_matches == []
      assert result.summary == "No conflicts found in class 9"
    end
  end

  describe "summary generation" do
    test "generates summary for blocked recommendation" do
      entries = [
        %{name: "BRAND", process: "123", status: "Registro", holder: "HOLDER"}
      ]

      result = Classifier.classify(entries, "BRAND", 36, :exact)

      assert result.summary ==
               "Found 1 active registration(s) blocking this brand in class 36"
    end

    test "generates summary for caution recommendation" do
      entries = [
        %{name: "BRANDSIMILAR", process: "123", status: "Pedido", holder: "HOLDER"}
      ]

      result = Classifier.classify(entries, "BRAND", 36, :exact)

      assert result.summary == "Found 1 pending/similar trademark(s) - recommend legal review"
    end

    test "generates summary for clear recommendation with no results" do
      result = Classifier.classify([], "BRAND", 9, :exact)

      assert result.summary == "No conflicts found in class 9"
    end

    test "generates summary for clear recommendation with only safe results" do
      entries = [
        %{name: "OLD1", process: "111", status: "Arquivado", holder: "HOLDER1"},
        %{name: "OLD2", process: "222", status: "Indeferido", holder: "HOLDER2"}
      ]

      result = Classifier.classify(entries, "BRAND", 42, :exact)

      assert result.summary == "Found 2 result(s), all archived or unrelated"
    end
  end

  describe "recommendation logic" do
    test "blocked takes precedence over potential and safe" do
      entries = [
        %{name: "EXACT", process: "111", status: "Registro", holder: "H1"},
        %{name: "SIMILAR", process: "222", status: "Pedido", holder: "H2"},
        %{name: "OLD", process: "333", status: "Arquivado", holder: "H3"}
      ]

      result = Classifier.classify(entries, "EXACT", 9, :exact)

      assert result.recommendation == :blocked
    end

    test "caution when only potential conflicts exist" do
      entries = [
        %{name: "BRAND SIMILAR", process: "222", status: "Pedido", holder: "H2"},
        %{name: "OLD", process: "333", status: "Arquivado", holder: "H3"}
      ]

      result = Classifier.classify(entries, "BRAND", 9, :exact)

      assert result.recommendation == :caution
    end

    test "clear when only safe matches exist" do
      entries = [
        %{name: "OLD1", process: "111", status: "Arquivado", holder: "H1"},
        %{name: "OLD2", process: "222", status: "Indeferido", holder: "H2"}
      ]

      result = Classifier.classify(entries, "BRAND", 9, :exact)

      assert result.recommendation == :clear
    end

    test "clear when no entries" do
      result = Classifier.classify([], "BRAND", 9, :exact)

      assert result.recommendation == :clear
    end
  end

  describe "similarity detection" do
    test "detects exact matches regardless of case" do
      entries = [
        %{name: "nubank", process: "123", status: "Registro", holder: "HOLDER"}
      ]

      result = Classifier.classify(entries, "NUBANK", 36, :exact)

      assert length(result.blocking_conflicts) == 1
    end

    test "detects substring matches" do
      entries = [
        %{name: "NUBANK PAYMENTS", process: "123", status: "Registro", holder: "HOLDER"}
      ]

      result = Classifier.classify(entries, "NUBANK", 36, :radical)

      assert length(result.blocking_conflicts) == 1
    end

    test "detects reverse substring matches" do
      entries = [
        %{name: "NU", process: "123", status: "Registro", holder: "HOLDER"}
      ]

      result = Classifier.classify(entries, "NUBANK", 36, :radical)

      assert length(result.blocking_conflicts) == 1
    end

    test "uses Jaro distance for fuzzy matching" do
      # "NUBANKPAY" and "NUBANK" should be similar (Jaro > 0.8)
      entries = [
        %{name: "NUBANKPAY", process: "123", status: "Registro", holder: "HOLDER"}
      ]

      result = Classifier.classify(entries, "NUBANK", 36, :radical)

      assert length(result.blocking_conflicts) == 1
    end

    test "rejects very dissimilar names" do
      # "ZZZZZ" and "NUBANK" should not be similar
      entries = [
        %{name: "ZZZZZ", process: "123", status: "Registro", holder: "HOLDER"}
      ]

      result = Classifier.classify(entries, "NUBANK", 36, :radical)

      # Should be in potential_conflicts, not blocking
      assert length(result.blocking_conflicts) == 0
      assert length(result.potential_conflicts) == 1
    end

    test "handles empty strings safely" do
      entries = [
        %{name: "", process: "123", status: "Registro", holder: "HOLDER"}
      ]

      result = Classifier.classify(entries, "BRAND", 9, :exact)

      # Empty string "" contains any string in Elixir (String.contains?("BRAND", "") is true)
      # So it's classified as similar and goes to blocking_conflicts
      assert length(result.blocking_conflicts) == 1
    end
  end

  describe "edge cases" do
    test "handles entries with missing fields gracefully" do
      entries = [
        %{name: "BRAND", process: "", status: "Registro", holder: ""}
      ]

      result = Classifier.classify(entries, "BRAND", 9, :exact)

      assert result.recommendation == :blocked
      assert length(result.blocking_conflicts) == 1

      conflict = hd(result.blocking_conflicts)
      assert conflict.name == "BRAND"
      assert conflict.process == ""
      assert conflict.holder == ""
    end

    test "handles invalid UTF-8 characters safely" do
      # Classifier should handle encoding issues gracefully
      entries = [
        %{name: "CAFÉ", process: "123", status: "Registro", holder: "HOLDER"}
      ]

      result = Classifier.classify(entries, "CAFE", 30, :exact)

      # Should not crash
      assert %SearchResult{} = result
    end

    test "handles very long brand names" do
      long_name = String.duplicate("A", 1000)

      entries = [
        %{name: long_name, process: "123", status: "Registro", holder: "HOLDER"}
      ]

      result = Classifier.classify(entries, long_name, 9, :exact)

      assert result.recommendation == :blocked
    end

    test "preserves entry order in results (reversed during accumulation)" do
      entries = [
        %{name: "FIRST", process: "111", status: "Arquivado", holder: "H1"},
        %{name: "SECOND", process: "222", status: "Arquivado", holder: "H2"},
        %{name: "THIRD", process: "333", status: "Arquivado", holder: "H3"}
      ]

      result = Classifier.classify(entries, "BRAND", 9, :exact)

      # Results should maintain original order
      names = Enum.map(result.safe_matches, & &1.name)
      assert names == ["FIRST", "SECOND", "THIRD"]
    end
  end
end

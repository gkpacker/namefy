defmodule InpiCheckerTest do
  use ExUnit.Case

  alias InpiChecker.NiceClasses

  test "validates Nice classes" do
    assert NiceClasses.valid?(9)
    assert NiceClasses.valid?(36)
    assert NiceClasses.valid?(42)
    refute NiceClasses.valid?(0)
    refute NiceClasses.valid?(46)
    refute NiceClasses.valid?(-1)
  end

  test "rejects invalid class in search" do
    assert {:error, {:invalid_class, 99}} = InpiChecker.search("Test", 99, :exact)
  end
end

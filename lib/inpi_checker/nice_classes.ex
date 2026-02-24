defmodule InpiChecker.NiceClasses do
  @moduledoc """
  Nice Classification definitions for trademark registration.
  Classes 1-34 are products, 35-45 are services.
  """

  @classes %{
    1 => "Chemicals",
    2 => "Paints",
    3 => "Cosmetics, cleaning",
    4 => "Industrial oils, fuels",
    5 => "Pharmaceuticals",
    6 => "Common metals",
    7 => "Machines",
    8 => "Hand tools",
    9 => "Software, electronics, computers",
    10 => "Medical apparatus",
    11 => "Lighting, heating",
    12 => "Vehicles",
    13 => "Firearms",
    14 => "Jewelry, watches",
    15 => "Musical instruments",
    16 => "Paper, printed matter",
    17 => "Rubber, plastics",
    18 => "Leather goods, bags",
    19 => "Building materials",
    20 => "Furniture",
    21 => "Household utensils",
    22 => "Ropes, textiles",
    23 => "Yarns, threads",
    24 => "Fabrics",
    25 => "Clothing, footwear",
    26 => "Lace, embroidery",
    27 => "Carpets, mats",
    28 => "Games, toys",
    29 => "Meat, fish, dairy",
    30 => "Coffee, tea, bakery",
    31 => "Agricultural products",
    32 => "Beverages (non-alcoholic)",
    33 => "Alcoholic beverages",
    34 => "Tobacco",
    35 => "Advertising, business management, retail",
    36 => "Financial services, insurance, banking",
    37 => "Construction, repair",
    38 => "Telecommunications",
    39 => "Transport, storage",
    40 => "Material treatment",
    41 => "Education, entertainment",
    42 => "Technology services, SaaS, software development",
    43 => "Food services, restaurants",
    44 => "Medical, veterinary services",
    45 => "Legal services, security"
  }

  @doc "Get description for a Nice class number"
  def description(class) when class in 1..45, do: Map.get(@classes, class)
  def description(_), do: nil

  @doc "Check if a class number is valid"
  def valid?(class), do: class in 1..45

  @doc "Get all classes"
  def all, do: @classes
end

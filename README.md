# Namefy

Elixir CLI tool for checking trademark/brand name availability on Brazil's [INPI](https://busca.inpi.gov.br/pePI/) (Instituto Nacional da Propriedade Industrial).

Searches the INPI database by brand name and [Nice Classification](https://www.wipo.int/classifications/nice/en/) class, classifies results by risk level, and outputs structured JSON for easy integration with AI workflows.

## Features

- **Exact and radical search modes** - match brand names exactly or find variations
- **Parallel multi-class search** - search across multiple Nice classes concurrently using supervised tasks
- **Automatic pagination** - fetches all result pages (up to 50 pages per search)
- **Retry with exponential backoff** - automatic retry on transient failures (3 attempts by default)
- **Risk classification** - categorizes results as BLOCKED, CAUTION, or CLEAR using string similarity (Jaro distance)
- **JSON output** - structured output with conflicts, recommendations, and summaries
- **Session management** - GenServer-based authenticated session with cookie handling

## Requirements

- Erlang/OTP 28
- Elixir ~> 1.19
- INPI account (optional - anonymous access is supported)

Versions are pinned in `.mise.toml` for use with [mise](https://mise.jdx.dev/).

## Setup

```bash
git clone <repo-url> && cd namefy
mise install
mix deps.get
cp .env.example .env
```

Edit `.env` with your INPI credentials (optional):

```
INPI_USER=your_username
INPI_PASSWORD=your_password
```

## Usage

### WebInterface

```bash
mix run --no-halt
```

### Exact search in a single class

```bash
mix inpi "Horizon" 9
```

### Parallel search across multiple classes

```bash
mix inpi "Horizon" 9,36,42 --parallel
```

### Radical search (finds variations)

```bash
mix inpi "Horizon Tech" 42 --mode radical
```

### Options

| Flag | Description | Default |
|------|-------------|---------|
| `--mode` | `exact` or `radical` | `exact` |
| `--parallel` | Enable parallel search (auto-enabled for multiple classes) | `false` |
| `--debug` | Enable debug output | `false` |

## Output

Results are returned as JSON:

```json
{
  "brand": "Horizon",
  "class": 9,
  "class_description": "Software, electronics, computers",
  "mode": "exact",
  "search_performed": "exact:Horizon",
  "total_results": 3,
  "recommendation": "CLEAR",
  "blocking_conflicts": [],
  "potential_conflicts": [],
  "safe_matches": [
    {
      "name": "HORIZON DIGITAL",
      "process": "123456789",
      "status": "Arquivado",
      "holder": "Example Corp",
      "risk": "LOW"
    }
  ],
  "summary": "Found 3 result(s), all archived or unrelated"
}
```

### Recommendations

| Value | Meaning |
|-------|---------|
| **BLOCKED** | Active registered trademark conflicts exist |
| **CAUTION** | Pending applications or similar marks found - legal review recommended |
| **CLEAR** | No conflicts found or all matches are archived/unrelated |

### INPI Status Reference

| Status | Blocks Registration? |
|--------|---------------------|
| Registro | Yes - active trademark |
| Pedido | Yes - pending application with priority rights |
| Arquivado | No - abandoned |
| Indeferido | No - rejected |

## Programmatic API

```elixir
# Single search
{:ok, result} = InpiChecker.search("Horizon", 9, :exact)

# Parallel search across classes
results = InpiChecker.search_parallel("Horizon", [9, 36, 42], mode: :exact)

# Search brand variations in a single class
results = InpiChecker.search_variations(["Horizon Tech", "Horizon App"], 42)

# Convert to JSON
json = InpiChecker.to_json(result)
```

## Nice Classification Quick Reference

| Class | Description | Common Use |
|-------|-------------|------------|
| 9 | Software, electronics | Apps, software products |
| 25 | Clothing, footwear | Fashion brands |
| 35 | Advertising, retail | E-commerce, marketplaces |
| 36 | Financial services | Fintech, banking |
| 41 | Education, entertainment | EdTech, media |
| 42 | Technology services, SaaS | SaaS platforms, dev tools |
| 43 | Food services | Restaurants, delivery |

## Architecture

```
InpiChecker.Application
├── Task.Supervisor (InpiChecker.TaskSupervisor)  # Supervises parallel search tasks
└── InpiChecker.Session (GenServer)               # Manages authenticated INPI session

InpiChecker          # Public API
├── SearchCoordinator  # Orchestrates parallel searches with retry
├── Searcher           # Executes individual searches against INPI
├── Parser             # HTML parsing with Floki (handles Latin1 encoding)
├── Classifier         # Risk classification using Jaro string similarity
├── SearchResult       # Result struct with JSON serialization
└── NiceClasses        # Nice Classification reference data
```

## License

Private.

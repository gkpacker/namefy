# INPI Brand Availability Checker (Elixir)

Tool for checking trademark/brand name availability on Brazil's INPI (Instituto Nacional da Propriedade Industrial).

## AI-Driven Search Workflow

When user asks to check a brand name:

### Step 1: Analyze the Brand and Context

Before searching, analyze:
- **Brand uniqueness**: Is it a common word (Horizon, Nova) or distinctive (Nubank, Zapier)?
- **Industry context**: What business type? Fintech, e-commerce, SaaS?
- **Relevant classes**: Which Nice classes apply to this business?
- **Descriptiveness**: Is the name descriptive of the service? (e.g., "Cashflow" for fintech = highly descriptive)

### Step 2: Plan Your Searches

You decide which searches to perform. Consider:

1. **Exact search** (always do first) - finds direct name conflicts
2. **Spaced variations** - search both "BrandName" and "BRAND NAME" (tool may not match across spacing)
3. **Targeted radical searches** - find variations by appending relevant terms

**Example for "Compass" fintech app:**
```
Exact searches (parallel, all classes):
  - "Compass" in class 9, 36, 42

Spaced variation (if compound word):
  - "CASH FLOW" radical search (catches "CASH FLOW SOLUTIONS", etc.)

Radical searches (parallel, based on context):
  - "Compass Finance" in class 36
  - "Compass Fintech" in class 36
  - "Compass Pay" in class 36
  - "Compass App" in class 9
  - "Compass Tech" in class 42
```

### Step 3: Execute Searches

```bash
# Single exact search
mix inpi "BrandName" 9 --mode exact

# Parallel exact search across multiple classes (recommended)
mix inpi "BrandName" 9,36,42 --parallel

# IMPORTANT: For compound words, also search spaced version with radical mode
mix inpi "BRAND NAME" 36 --mode radical

# Radical searches for variations
mix inpi "BrandName Finance" 36 --mode radical
mix inpi "BrandName App" 9 --mode radical
```

### Step 4: MANDATORY - Call brazil-trademark-specialist Agent

**ALWAYS call the `brazil-trademark-specialist` agent after running INPI searches.**

### Step 5: MANDATORY - Update Search History

**ALWAYS update `CHECKED_NAMES.md` after completing a trademark search.**

Add the checked name to the tracking file with:
- Name and classes searched
- Result per class (CLEAR/BLOCKED/RISKY)
- Overall probability percentage
- Key conflicts or notes
- Date of search

This ensures we never re-check names and have a complete history of searches.

The agent will:
- Verify status interpretations (tool can show misleading statuses)
- Assess impact of pending applications (they have priority rights!)
- Evaluate descriptiveness risk for the specific class
- Provide realistic success probability
- Recommend whether to proceed or choose different name

```
Use Task tool with subagent_type="brazil-trademark-specialist"
Provide: brand name, classes, all search results, any user context
```

**Why this is mandatory:**
- Tool status "Registro" can mean REJECTED (check detailed status text)
- Pending applications ("Pedido") establish priority rights - they're not "safe"
- Brazil uses first-to-file: earlier applications block later ones
- Descriptive terms have low registration probability in relevant classes

## Search Modes

| Mode | What it does | When to use |
|------|--------------|-------------|
| `exact` | Only exact "BrandName" match | Always do this first |
| `radical` | Finds variations of the search term | Use with specific appended terms |

## Features

- **Parallel search**: Search multiple classes simultaneously with `--parallel`
- **Automatic retry**: 3 retries with exponential backoff on failures
- **Fault isolation**: One failing search doesn't affect others
- **JSON output**: Compatible with AI parsing

## Choosing Radical Search Terms

**You decide which terms to append based on:**

1. **Industry/business type**:
   - Fintech: finance, fintech, bank, pay, credito, pagamentos
   - E-commerce: store, shop, loja, marketplace
   - SaaS: tech, cloud, software, sistemas, digital
   - Food: restaurante, food, delivery, cafe

2. **Brand characteristics**:
   - Generic names (Horizon, Nova): search more variations
   - Distinctive names (Nubank): fewer variations needed

3. **Portuguese vs English**:
   - Search both: "Brand Finance" and "Brand Financeira"

## Common Class Combinations

| Business Type | Classes to Search |
|---------------|-------------------|
| **Fintech/Finance App** | 9, 36, 42 |
| **E-commerce Platform** | 9, 35, 42 |
| **SaaS Product** | 9, 35, 42 |
| **Clothing Brand** | 25, 35 |
| **Restaurant/Food** | 29, 30, 43 |
| **Education Platform** | 9, 41, 42 |

## Interpreting Results

### JSON Output Structure

```json
{
  "brand": "Horizon",
  "class": 36,
  "mode": "exact",
  "search_performed": "exact:Horizon",
  "recommendation": "CLEAR|CAUTION|BLOCKED",
  "blocking_conflicts": [],
  "potential_conflicts": [],
  "safe_matches": [{"name": "...", "status": "Arquivado", "process": "..."}],
  "summary": "Human-readable summary"
}
```

### Decision Logic

```
IF recommendation = "BLOCKED":
  → "Cannot register - active trademark exists"
  → Show blocking_conflicts list

ELSE IF recommendation = "CAUTION":
  → "Proceed with caution - recommend legal review"
  → Show potential_conflicts list

ELSE IF recommendation = "CLEAR":
  → "Safe to proceed with registration"
  → Note: archived marks don't block registration
```

### Status Meanings

| Status | Meaning | Blocks Registration? |
|--------|---------|---------------------|
| **Registro** | Active registered trademark | **YES** |
| **Pedido / Aguardando exame** | Pending application | **YES - has priority rights** |
| **Arquivado** | Archived/abandoned | No |
| **Indeferido** | Rejected | No |
| **Indeferido (mantido em grau de recurso)** | Rejected, appeal denied | No |
| **Extinto** | Cancelled/expired | No |

**CRITICAL: Pending applications (Pedido) are NOT safe!**
- Brazil uses **first-to-file** system - earlier filings have priority
- Pending marks may become registered before yours
- INPI examiners cite pending applications as conflicts
- Applicants can file opposition against your application

**WARNING: Tool status can be misleading!**
- "Registro" sometimes appears for REJECTED marks
- Always check the detailed status text (e.g., "Pedido de registro de marca indeferido")
- Use the brazil-trademark-specialist agent to verify

## Response Template

After running searches AND calling brazil-trademark-specialist agent, respond with:

```markdown
## Brand Availability Check: "BrandName"

### Summary
[CLEAR/CAUTION/BLOCKED/LOW PROBABILITY] - [One line summary]

### Results by Class

| Class | Description | Status | Conflicts |
|-------|-------------|--------|-----------|
| 9 | Software | CLEAR | X archived marks |
| 36 | Finance | CAUTION | Y pending applications with priority |
| 42 | Tech/SaaS | BLOCKED | Active registration found |

### Conflict Details

| Process | Mark | Status | Risk Level |
|---------|------|--------|------------|
| 123456 | BRAND X | Registro (Active) | BLOCKING |
| 789012 | BRAND Y | Pedido (Pending) | HIGH - has priority |
| 345678 | BRAND Z | Arquivado | LOW - archived |

### Success Probability
[X-Y%] - Based on agent analysis considering:
- Number of prior-filed pending applications
- Descriptiveness of mark in target class
- Brazil's first-to-file system

### Recommendation
[Clear guidance from agent: proceed / do not proceed / alternative strategies]

### Next Steps
- [Actionable items based on agent analysis]
```

## Troubleshooting

### Timeout errors
- The tool will automatically retry up to 3 times with exponential backoff
- If still failing, try a more specific search term

### "Database unavailable" error
- INPI database is temporarily down
- Wait and retry later

### Missing credentials
- Ensure `.env` file exists with `INPI_USER` and `INPI_PASSWORD`

## Nice Classification Reference

### Products (1-34)
- **9**: Software, apps, electronics
- **25**: Clothing, footwear
- **28**: Games, toys
- **30**: Food (coffee, bakery)

### Services (35-45)
- **35**: Retail, advertising, e-commerce
- **36**: Financial services, fintech, banking
- **38**: Telecommunications
- **41**: Education, entertainment
- **42**: Technology services, SaaS
- **43**: Restaurants, food services
- **45**: Legal, security services

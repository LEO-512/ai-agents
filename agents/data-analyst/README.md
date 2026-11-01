# data-analyst

An agent for exploring a dataset and building an honest baseline model. It checks data quality first, splits before engineering features, and refuses to report a metric it did not compute.

## When to use it

- You have a new CSV or notebook and want to know what is actually in it
- You need a baseline before trying a complex model
- A model is scoring suspiciously well and you suspect leakage

## Example prompt

```text
Use the data-analyst subagent on data/rainfall.csv.
Target column is "rainfall". Build a baseline, compare it with a random forest,
and tell me if any feature could be leaking information.
```

Another one:

```text
My classifier reports 99% accuracy but performs badly in production.
Look at notebooks/train.ipynb and find out why.
```

## What you get back

```text
Data:      365 rows, 11 features, target 68% / 32%, 1 incomplete row
Cleaning:  dropped 1 row missing winddirection and windspeed
Models:    logistic 0.822 (CV 0.792), random forest 0.795 (CV 0.773)
Best:      logistic regression — simpler and higher on held-out data
Caveats:   one year of data, random split; time-based validation needed
```

## Install — OpenCode

```powershell
Copy-Item opencode.md "$env:USERPROFILE\.config\opencode\agents\data-analyst.md"
```

```bash
cp opencode.md ~/.config/opencode/agents/data-analyst.md
```

Per project: `.opencode/agents/data-analyst.md`.

## Install — Claude Code

```powershell
Copy-Item claude.md "$env:USERPROFILE\.claude\agents\data-analyst.md"
```

```bash
cp claude.md ~/.claude/agents/data-analyst.md
```

Per project: `.claude/agents/data-analyst.md`.

## Notes

- It needs Python with pandas and scikit-learn available in the environment it runs in.
- The "Caveats" section is the most valuable part. Treat a missing caveat as a red flag, not a clean bill of health.

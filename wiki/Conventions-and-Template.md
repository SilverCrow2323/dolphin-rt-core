# Wiki Conventions and Page Template

The GitHub Wiki is the practical handbook. Keep implementation details in `docs/`; use Wiki pages to help a reader complete one task or understand one user-facing topic.

## Page rules

- One topic per page.
- Start with a short explanation and say when the page is useful.
- Use one concept per bullet.
- Use **MUST KNOW!!** only for required safety, prerequisite or compatibility information.
- Use **Optional** only for enhancements that are not required.
- Leave basic steps unlabelled.
- Keep status honest: build, desktop test and physical handheld test are different evidence levels.

## Reusable template

```markdown
# Short topic title

[Two or three sentences: what this is and when to use it.]

## In breve
- One concept per bullet.
- Keep each bullet short and actionable.

> [!IMPORTANT]
> **MUST KNOW!!** Required prerequisite, safety or compatibility note.

## Steps
1. First action.
2. Next action.
3. How to verify the result.

> **Optional** — Non-essential enhancement.

## Troubleshooting
| Symptom | First check |
|---|---|
| Visible issue | Safe first check |

## Related pages
- Link to one or two existing pages that help the reader with the next step.
```

Remove the **MUST KNOW!!** or **Optional** block when it does not apply. Do not add labels just to fill the template.

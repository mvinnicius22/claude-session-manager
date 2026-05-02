# Session End — Update Project Documentation

Before ending a Claude Code session, update the project documentation to reflect the current state.

## Steps

1. **Update README.md**: If the session introduced new features, changed setup steps, modified commands, or altered the project structure, update `README.md` accordingly. Keep it accurate and concise. If no changes affect the README, skip this step.

2. **Update CLAUDE.md**: If the session changed architecture, conventions, key commands, or project structure, update `CLAUDE.md` so future Claude Code sessions have accurate context. If no changes affect CLAUDE.md, skip this step.

3. **Update TODO.md**: Create or update `TODO.md` at the project root with:
   - **Next steps**: Work that should continue in the next session.
   - **Pending tasks**: Known issues, incomplete work, or deferred items.
   - **Decisions made**: Important architectural or design decisions from this session that provide context for future work.
   - Use clear, actionable language. Remove completed items. Add dates to new entries.

4. **Update or create docs under `docs/`**: If the session changed anything that belongs in the detailed docs tree, reflect it there. Do not duplicate content that already lives in `README.md` or `CLAUDE.md` — those are overviews; `docs/` is the canonical reference.
   - **Domain docs (`docs/domains/*.md`)**: If a feature, field, endpoint, or technical-debt note of a given domain changed, update the matching file. If the session introduced a new domain, create `docs/domains/<name>.md` following the existing template.
   - **ADRs (`docs/adr/*.md`)**: If the session made an architectural decision (new dependency, structural change, significant trade-off), write a new ADR. Number sequentially. Do not rewrite history — append a new ADR that supersedes the old one if needed.
   - **PRDs (`docs/prd/*.md`)**: If a new feature shipped or expanded, create or update its PRD with problem, users, solution, and success criteria.
   - **Guides / runbooks / references / playbooks**: If the session created a reusable how-to, operational procedure, convention, or recurring process, add it under the matching folder (`docs/guides/`, `docs/runbooks/`, `docs/references/`, `docs/playbooks/`).
   - **Diagrams (`docs/diagrams/*.md`)**: If the session changed an architecture, sequence, network, or ER diagram, update the matching Mermaid file.
   - **Schema and artifact docs**: If migrations/models changed, update `docs/schema.yml` manually. If API / admin / jobs / env / screens changed, regenerate the matching YAML via the corresponding `task` command (see project CLAUDE.md).
   - **Cross-cutting docs**: If the change is security, observability, performance, legal, or LGPD-shaped, update the corresponding doc under `docs/security/`, `docs/observability/`, `docs/performance/`, or `docs/legal/`.
   - **Index (`docs/index.md`)**: When adding new docs, add the link with a one-line description in the correct section of the index.
   - If a new doc is needed but the content is not yet mature, create a stub with clear "TBD" markers rather than skipping it — future sessions pick up the thread.

5. **Summary**: Provide a brief summary of what was updated and why, including every file touched under `docs/`.

## Rules

- Only update files that need changes. Do not make cosmetic-only edits.
- Do not push to remote. The user handles pushes manually.
- If a file does not exist yet (e.g., TODO.md), create it.
- Keep all updates minimal and factual.

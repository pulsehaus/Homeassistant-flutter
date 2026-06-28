# `shared/`

Cross-cutting code reused by more than one feature: common widgets, extensions,
formatting helpers and small utilities that are not tied to a single feature and
do not belong in `core/` (app-wide infrastructure such as theme, config,
routing).

Add subfolders as needed, e.g. `shared/widgets/`, `shared/extensions/`,
`shared/utils/`. Keep anything feature-specific inside that feature instead.

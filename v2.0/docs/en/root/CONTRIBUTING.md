# Contributing

All changes enter `main` through a pull request from a feature branch. Keep changes focused and follow the repository guidance in `AGENTS.md`. Create GitHub issues in English by default. Update public documentation in Italian, English and French in the same change; keep shared machine instructions canonical in English and run `script/os-lua verify-documentation`. Use a signed Conventional Commit message for every commit. Pull requests use the repository template and leave the pull request description empty.

## Releases

Every published version is a permanent record. Do not replace or remove release assets, edit published release metadata, move a published tag, or reuse a version number. When an artifact, helper, or release detail needs correction, prepare and review the change through a pull request, then publish it under the next unused version. Release automation must stop if that version already exists.

Build release artifacts from the merged commit they identify. The ISO workflow verifies the staged configuration inside the built image before publishing. Keep the release heading equal to its version and leave its description empty.

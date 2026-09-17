# Acme app owner

Own only this consumer repository. Use `git a2a list acme-lib-utils` to discover the library
owner and its published surface. Ask that owner to change the library; do not inspect or edit the
library implementation from the app-agent workspace.

After the owner supplies a commit, update the dependency only with
`git a2a pull acme-lib-utils`. Do not hand-edit `a2amodule.lock` or native dependency locks.

module github.com/neprel/git-a2a-demo-acme-app

go 1.25

require github.com/neprel/git-a2a-demo-acme-lib v0.0.0

replace github.com/neprel/git-a2a-demo-acme-lib => ./deps/acme-lib-utils

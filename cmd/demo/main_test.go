package main

import (
	"testing"

	acmelibutils "github.com/neprel/git-a2a-demo-acme-lib"
)

func TestUsesGoImplementation(t *testing.T) {
	got := acmelibutils.FormatLabel("slug", acmelibutils.Slugify("  Acme Demo App  "))
	if got != "slug: acme-demo-app" {
		t.Fatalf("got %q", got)
	}
}

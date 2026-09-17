package main

import (
	"testing"

	acmelibutils "github.com/neprel/git-a2a-demo-acme-lib"
)

func TestUsesGoImplementation(t *testing.T) {
	got := acmelibutils.FormatDisplayName("  Ada   Lovelace  ")
	if got != "Ada Lovelace" {
		t.Fatalf("got %q", got)
	}
}

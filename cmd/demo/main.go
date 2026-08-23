package main

import (
	"fmt"

	acmelibutils "github.com/neprel/git-a2a-demo-acme-lib"
)

func main() {
	fmt.Println(acmelibutils.FormatLabel("slug", acmelibutils.Slugify("  Acme Demo App  ")))
}

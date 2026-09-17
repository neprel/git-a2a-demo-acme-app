package main

import (
	"fmt"
	"os"

	acmelibutils "github.com/neprel/git-a2a-demo-acme-lib"
)

func main() {
	value := "  Ada   Lovelace  "
	if len(os.Args) > 1 {
		value = os.Args[1]
	}
	fmt.Println(acmelibutils.FormatDisplayName(value))
}

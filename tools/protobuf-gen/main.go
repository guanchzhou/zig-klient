// Command protobuf-gen writes, from the upstream Kubernetes Go types:
//
//   - the Protobuf message tables zig-klient decodes with (-schema FILE)
//   - list bodies in both wire formats the API server serves (-fixtures DIR):
//     <name>.pb holds application/vnd.kubernetes.protobuf (k8s\x00 +
//     runtime.Unknown), <name>.json holds application/json
//
// Usage: go run . -schema ../../src/k8s/protobuf_generated.zig -fixtures ../../tests/fixtures/protobuf
package main

import (
	"flag"
	"log"
	"os"
)

func main() {
	schemaPath := flag.String("schema", "", "write the message tables to this file")
	fixturesDir := flag.String("fixtures", "", "write list fixtures to this directory")
	flag.Parse()
	if *schemaPath == "" && *fixturesDir == "" {
		flag.Usage()
		os.Exit(2)
	}
	if *schemaPath != "" {
		if err := os.WriteFile(*schemaPath, generateSchema(), 0o644); err != nil {
			log.Fatal(err)
		}
	}
	if *fixturesDir != "" {
		if err := writeFixtures(*fixturesDir); err != nil {
			log.Fatal(err)
		}
	}
}

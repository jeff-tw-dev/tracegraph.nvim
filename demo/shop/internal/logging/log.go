// Package logging is the shared helper every layer reaches for.
//
// Debugf is deliberately called from several packages — tracing its
// callers is what shows off tracegraph's fan-in view, and following one
// of those callers upward is the six-frame chain in the demo.
package logging

import (
	"fmt"
	"os"
)

// Verbose gates the debug output.
var Verbose = true

// Debugf writes one debug line when verbose logging is on.
func Debugf(format string, args ...any) {
	if !Verbose {
		return
	}

	fmt.Fprintf(os.Stderr, "debug: "+format+"\n", args...)
}

// Infof writes one info line.
func Infof(format string, args ...any) {
	fmt.Fprintf(os.Stdout, "info: "+format+"\n", args...)
}

package main

import (
	"bytes"
	"errors"
	"fmt"
	"io/ioutil"
	"os/exec"
	"strings"

	"golang.org/x/mod/modfile"
)

// goModInfo returns the main module's root directory
// and the parsed contents of the go.mod file.
func goModInfo() (*modfile.File, error) {
	goModPath, err := findGoMod()
	if err != nil {
		return nil, fmt.Errorf("cannot find main module: %w", err)
	}

	data, err := ioutil.ReadFile(goModPath)
	if err != nil {
		return nil, fmt.Errorf("cannot read main go.mod file: %w", err)
	}

	modf, err := modfile.Parse(goModPath, data, nil)
	if err != nil {
		return nil, fmt.Errorf("could not parse go.mod: %w", err)
	}

	return modf, nil
}

func findGoMod() (string, error) {
	out, err := runCmd(".", "go", "env", "GOMOD")
	if err != nil {
		return "", err
	}
	out = strings.TrimSpace(out)
	if out == "" {
		return "", errors.New("no go.mod file found in any parent directory")
	}
	return strings.TrimSpace(out), nil
}

func runCmd(dir string, name string, args ...string) (string, error) {
	var outData, errData bytes.Buffer

	c := exec.Command(name, args...)
	c.Stdout = &outData
	c.Stderr = &errData
	c.Dir = dir
	err := c.Run()
	if err == nil {
		return outData.String(), nil
	}
	if _, ok := err.(*exec.ExitError); ok && errData.Len() > 0 {
		return "", errors.New(strings.TrimSpace(errData.String()))
	}
	return "", fmt.Errorf("cannot run %q: %v", append([]string{name}, args...), err)
}

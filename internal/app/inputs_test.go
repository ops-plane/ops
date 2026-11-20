package app

import (
	"testing"

	"github.com/google/uuid"

	"github.com/ops-plane/ops/internal/templates"
)

// A sensitive input left empty keeps its stored value; one with a rejected new value (invalid, or too short to
// mask) keeps the error.
func TestSealInputsKeepsRejectedError(t *testing.T) {
	s := &App{Secrets: keys("test-secret-key", "")}
	tpl := templates.Template{Inputs: []templates.Input{{Name: "pin", Type: "number", Required: true, Sensitive: true}}}
	old := map[string]any{"pin": map[string]any{"sealed": "c3RvcmVk"}}

	for raw, wantErr := range map[string]bool{"": false, "not-a-number": true, "123": true, "1234": false} {
		form := map[string]string{"pin": raw}
		vals, errs := tpl.Validate(form)
		if err := s.SealInputs(tpl, form, vals, old, errs, uuid.New(), ""); err != nil {
			t.Fatal(err)
		}
		if _, got := errs["pin"]; got != wantErr {
			t.Errorf("%q: error kept = %v, want %v (errs %v)", raw, got, wantErr, errs)
		}
		if _, kept := vals["pin"]; kept == wantErr {
			t.Errorf("%q: stored value used = %v, want %v", raw, kept, !wantErr)
		}
	}
}

// A sensitive number is masked in its printed form.
func TestOpenInputsMasksNumbers(t *testing.T) {
	s := &App{Secrets: keys("test-secret-key", "")}
	tpl := templates.Template{Inputs: []templates.Input{{Name: "pin", Type: "number", Sensitive: true}}}
	ws := uuid.New()
	form := map[string]string{"pin": "12345"}
	vals, errs := tpl.Validate(form)
	if err := s.SealInputs(tpl, form, vals, nil, errs, ws, ""); err != nil || len(errs) > 0 {
		t.Fatal(err, errs)
	}
	if _, secrets, err := s.OpenInputs(vals, ws, ""); err != nil || len(secrets) != 1 || secrets[0] != "12345" {
		t.Fatalf("secrets %q, %v", secrets, err)
	}
}

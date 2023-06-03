package data

import (
	"fmt"
	"os/exec"
	"strings"

	"github.com/pkg/errors"
	"k8s.io/klog/v2"
)

const (
	expectedState = "inactive"
)

var (
	services = []string{"microshift.service", "microshift-etcd.scope"}
)

func MicroShiftIsNotRunning() error {
	for _, service := range services {
		klog.InfoS("Checking service state", "service", service)

		cmd := exec.Command("systemctl", "show", "-p", "ActiveState", "--value", service)
		out, err := cmd.CombinedOutput()
		state := strings.TrimSpace(string(out))
		if err != nil {
			return errors.Wrap(err, fmt.Sprintf("could not determine if %s is active", service))
		}

		klog.InfoS("Found service state", "service", service, "state", state)

		if state != expectedState {
			return fmt.Errorf("service %s is %s - expected to be %s", service, state, expectedState)
		}
	}

	return nil
}

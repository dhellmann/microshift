package cmd

import (
	"github.com/spf13/cobra"
	"k8s.io/cli-runtime/pkg/genericclioptions"
	"github.com/openshift/oc/pkg/cli/admin/inspect"
)

func NewInspectCommand(ioStreams genericclioptions.IOStreams) *cobra.Command {
	// This command gets the kubeconfig from command line flags/env vars.
	cmd := inspect.NewCmdInspect(ioStreams)
	return cmd
}

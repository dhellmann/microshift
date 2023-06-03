package data

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/openshift/microshift/pkg/config"
	"github.com/openshift/microshift/pkg/util"
	"github.com/pkg/errors"
	"k8s.io/klog/v2"
)

var (
	cpArgs = []string{
		"--verbose",
		"--recursive",
		"--preserve",
		"--reflink=auto",
	}
)

func NewManager(storage StoragePath) (*manager, error) {
	if storage == "" {
		return nil, &EmptyArgErr{argName: "storage"}
	}
	return &manager{storage: storage}, nil
}

var _ Manager = (*manager)(nil)

type manager struct {
	storage StoragePath
}

func (dm *manager) GetBackupPath(name BackupName) string {
	return filepath.Join(string(dm.storage), string(name))
}

func (dm *manager) BackupExists(name BackupName) (bool, error) {
	return pathExists(dm.GetBackupPath(name))
}

func (dm *manager) RemoveBackup(name BackupName) error {
	return os.RemoveAll(dm.GetBackupPath(name))
}

func (dm *manager) GetBackupList() ([]BackupName, error) {
	files, err := os.ReadDir(config.BackupsDir)
	if err != nil {
		return nil, err
	}

	backups := make([]BackupName, 0, len(files))
	for _, file := range files {
		if file.IsDir() {
			backups = append(backups, BackupName(file.Name()))
		}
	}

	return backups, nil
}

func (dm *manager) Backup(name BackupName) error {
	klog.InfoS("Starting backup",
		"storage", dm.storage, "name", name, "data", config.DataDir)

	if name == "" {
		return &EmptyArgErr{"name"}
	}

	if exists, err := dm.BackupExists(name); err != nil {
		return errors.Wrap(err, fmt.Sprintf("could not determine if backup %s exists", name))
	} else if exists {
		return fmt.Errorf("backup %s already exists, name must be unique", name)
	}

	if found, err := pathExists(string(dm.storage)); err != nil {
		return errors.Wrap(err, "could not determine if backup storage directory")
	} else if !found {
		klog.InfoS("Creating backup storage directory", "path", dm.storage)
		if makeDirErr := util.MakeDir(string(dm.storage)); makeDirErr != nil {
			return errors.Wrap(makeDirErr, fmt.Sprintf("failed to create backup storage directory %s", dm.storage))
		}
		klog.InfoS("Created backup storage directory", "path", dm.storage)
	}

	dest := dm.GetBackupPath(name)

	if err := copyDataDir(dest); err != nil {
		return errors.Wrap(err, "failed to create backup")
	}

	klog.InfoS("Completed backup", "backup", dest, "data", config.DataDir)
	return nil
}

func (dm *manager) Restore(n BackupName) error {
	return fmt.Errorf("Restore not implemented")
}

func copyDataDir(dest string) error {
	cmd := exec.Command("cp", append(cpArgs, config.DataDir, dest)...) //nolint:gosec
	klog.InfoS("Executing command", "cmd", cmd)

	var outb, errb bytes.Buffer
	cmd.Stdout = &outb
	cmd.Stderr = &errb
	err := cmd.Run()

	klog.InfoS("Command finished running", "cmd", cmd,
		"stdout", strings.ReplaceAll(outb.String(), "\n", `, `),
		"stderr", errb.String())

	if err != nil {
		return errors.Wrap(err, "copy command failed")
	}

	klog.InfoS("Command successful", "cmd", cmd)
	return nil
}

func pathExists(path string) (bool, error) {
	exists, err := util.PathExists(path)
	if err != nil {
		return false, errors.Wrap(err, fmt.Sprintf("could not determine if %s exists", path))
	}
	return exists, nil
}

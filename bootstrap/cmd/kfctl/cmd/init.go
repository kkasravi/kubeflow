// Copyright 2018 The Kubeflow Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package cmd

import (
	"github.com/spf13/viper"

	kftypes "github.com/kubeflow/kubeflow/bootstrap/pkg/apis/apps"
	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
)

var initCfg = viper.New()

// initCmd represents the init command
var initCmd = &cobra.Command{
	Use:   "init <[path/]name>",
	Short: "Create a kubeflow application under <[path/]name>",
	Long: `Create a kubeflow application under <[path/]name>. The <[path/]name> argument can either be a full path 
or a name where the kubeflow application will be initialized in $PWD/name if <name> is not a path or in the parent 
directory is name is a path.`,
	Run: func(cmd *cobra.Command, args []string) {
		log.SetLevel(log.InfoLevel)
		if len(args) == 0 {
			log.Errorf("KsApp name is required")
			return
		}
		appName := args[0]
		kfApp, kfAppErr := NewKfApp(appName, initCfg)
		if kfAppErr != nil {
			log.Errorf("couldn't create KfApp: %v", kfAppErr)
			return
		}
		initErr := kfApp.Init()
		if initErr != nil {
			log.Errorf("KfApp initialization failed: %v", initErr)
			return
		}
	},
}

func init() {
	rootCmd.AddCommand(initCmd)

	initCfg.SetConfigName("app")
	initCfg.SetConfigType("yaml")

	initCmd.Flags().StringP("platform", "p", kftypes.DefaultPlatform,
		"one of 'gcp|minikube|docker-for-desktop|ack'")
	initCfg.BindPFlag("platform", initCmd.Flags().Lookup("platform"))
	initCmd.Flags().StringP("version", "v", kftypes.DefaultVersion,
		"desired version Kubeflow or latest tag if not provided by user ")
	initCfg.BindPFlag("version", initCmd.Flags().Lookup("version"))
	initCmd.Flags().StringP("repo", "r", kftypes.DefaultKfRepo,
		"local github kubeflow repo ")
	initCfg.BindPFlag("repo", initCmd.Flags().Lookup("repo"))
	initCmd.Flags().String("project", "",
		"name of the gcp project if --platform gcp")
	initCfg.BindPFlag("project", initCmd.Flags().Lookup("project"))
}
package cli

import (
	"errors"
	"fmt"
	"os"
	"runtime"

	"bitrec.ai/dialmainer/configs"
	"bitrec.ai/dialmainer/core/constants"
	"bitrec.ai/dialmainer/core/global"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var (
	cfgFile string
)

func init() {
	if len(os.Args) > 1 && (os.Args[1] == "version" || os.Args[1] == "completion") {
		return
	}
	cobra.OnInitialize(loadConfig)
	rootCmd.PersistentFlags().
		StringVarP(&cfgFile, "config", "c", "", "config file (default is /etc/dialer/config.toml)")
	rootCmd.PersistentFlags().
		StringP("output", "o", "", "Output format. Empty for human-readable,'toml', 'json', 'json-line' or 'yaml'")
	rootCmd.PersistentFlags().
		Bool("force", false, "Disable prompts and forces the execution")
}

func loadConfig() {
	if cfgFile == "" {
		cfgFile = os.Getenv("DIALER_CONFIG")

	}
	if cfgFile == "" && global.Mode == "dev" {
		cfgFile = constants.DEV_CONFIG_FILE
	}
	if cfgFile != "" {
		err := readCfg(cfgFile)
		if err != nil {
			log.Fatal().Caller().Err(err).Msgf("Error loading config file %s", cfgFile)
		}
	} else {
		log.Fatal().Caller().Err(errors.New("config file not found")).Msgf("Error loading config")
	}
	machineOutput := HasMachineOutputFlag()

	logLevel, err := zerolog.ParseLevel(global.Config.Log.Level)
	if err != nil {
		logLevel = zerolog.DebugLevel
	}
	zerolog.SetGlobalLevel(logLevel)
	if machineOutput {
		zerolog.SetGlobalLevel(zerolog.Disabled)
	}
	if machineOutput {
		zerolog.SetGlobalLevel(zerolog.Disabled)
	}

	if global.Config.Log.Format == constants.JSONLogFormat {
		log.Logger = log.Output(os.Stdout)
	}
	if runtime.GOOS != "linux" && runtime.GOOS != "darwin" {
		log.Fatal().Caller().Err(errors.New("os not support")).Msgf("dialer only support linux and darwin")
	}
}
func readCfg(cfgPath string) error {
	v := viper.New()
	v.SetConfigFile(cfgPath)
	err := v.ReadInConfig()
	if err != nil {
		return err
	}
	conf := configs.NewConfig()
	if err := v.Unmarshal(&conf); err != nil {
		log.Fatal().Caller().Err(err).Msgf("Fatal error config file: Unmarshal failed")
		return err
	}
	global.Config = conf
	return nil
}

var rootCmd = &cobra.Command{
	Use:   "dialer",
	Short: "dialer - a Dial pppoe and Static fixed ip control server",
	Long: `
dialer - a CDN service that provides PPPoE and static fixed IP control for servers

https://git.c.bitrec.ai/bitrec/dialmainer`,
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

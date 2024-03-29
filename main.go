package main

import (
	"embed"
	"fmt"
	"io"
	"io/fs"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
	"text/tabwriter"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
	"github.com/volatiletech/sqlboiler/v4/boilingcore"
	"github.com/volatiletech/sqlboiler/v4/drivers"
	"github.com/volatiletech/sqlboiler/v4/importers"
)

//go:embed templates
var templates embed.FS

const boilingSeedVersion = "0.1.0"

var (
	flagConfigFile   string
	tempTemplatesDir string
	modelsPkg        string
	cmdState         *boilingcore.State
	cmdConfig        *boilingcore.Config
)

func initConfig() {
	if len(flagConfigFile) != 0 {
		viper.SetConfigFile(flagConfigFile)
		if err := viper.ReadInConfig(); err != nil {
			fmt.Println("Can't read config:", err)
			os.Exit(1)
		}
		return
	}

	var err error
	viper.SetConfigName("sqlboiler")

	configHome := os.Getenv("XDG_CONFIG_HOME")
	homePath := os.Getenv("HOME")
	wd, err := os.Getwd()
	if err != nil {
		wd = "."
	}

	configPaths := []string{wd}
	if len(configHome) > 0 {
		configPaths = append(configPaths, filepath.Join(configHome, "sqlboiler"))
	} else {
		configPaths = append(configPaths, filepath.Join(homePath, ".config/sqlboiler"))
	}

	for _, p := range configPaths {
		viper.AddConfigPath(p)
	}

	// Ignore errors here, fallback to other validation methods.
	// Users can use environment variables if a config is not found.
	_ = viper.ReadInConfig()
}

func main() {
	// Too much happens between here and cobra's argument handling, for
	// something so simple just do it immediately.
	for _, arg := range os.Args {
		if arg == "--version" {
			fmt.Println("BoilingSeed v" + boilingSeedVersion)
			return
		}
	}

	// Set up the cobra root command
	rootCmd := &cobra.Command{
		Use:   "boilingseed [flags] <driver>",
		Short: "BoilingSeed generates seeder for your SQLBoiler models.",
		Long: "BoilingSeed generates seeder for your SQLBoiler models.\n" +
			`Complete documentation is available at http://github.com/stephenafamo/boilingseed`,
		Example:       `boilingseed psql`,
		PreRunE:       preRun,
		RunE:          run,
		PostRunE:      postRun,
		SilenceErrors: true,
		SilenceUsage:  true,
	}

	cobra.OnInitialize(initConfig)

	// Set up the cobra root command flags
	rootCmd.PersistentFlags().StringVarP(&flagConfigFile, "config", "c", "", "Filename of config file to override default lookup")
	rootCmd.PersistentFlags().String("sqlboiler-models", "", "The package of your generated models. Needed to import them properly in the seeder files.")
	rootCmd.PersistentFlags().StringP("output", "o", "seeds", "The name of the folder to output to")
	rootCmd.PersistentFlags().StringP("pkgname", "p", "seeds", "The name you wish to assign to your generated package")
	rootCmd.PersistentFlags().BoolP("debug", "d", false, "Debug mode prints stack traces on error")
	rootCmd.PersistentFlags().BoolP("no-context", "", false, "Disable context.Context usage in the generated code")
	rootCmd.PersistentFlags().BoolP("no-tests", "", false, "Disable generated go test files")
	// Use hooks instead of // AfterXXXAdded
	// rootCmd.PersistentFlags().BoolP("no-hooks", "", false, "Disable hooks feature for your models")
	rootCmd.PersistentFlags().BoolP("version", "", false, "Print the version")
	rootCmd.PersistentFlags().BoolP("wipe", "", false, "Delete the output folder (rm -rf) before generation to ensure sanity")

	// hide flags not recommended for use
	rootCmd.PersistentFlags().MarkHidden("no-tests")

	viper.BindPFlags(rootCmd.PersistentFlags())
	viper.SetEnvKeyReplacer(strings.NewReplacer(".", "_", "-", "_"))
	viper.AutomaticEnv()

	if err := rootCmd.Execute(); err != nil {
		if e, ok := err.(commandFailure); ok {
			fmt.Printf("Error: %v\n\n", string(e))
			rootCmd.Help()
		} else if !viper.GetBool("debug") {
			fmt.Printf("Error: %v\n", err)
		} else {
			fmt.Printf("Error: %+v\n", err)
		}

		os.Exit(1)
	}
}

type commandFailure string

func (c commandFailure) Error() string {
	return string(c)
}

func preRun(cmd *cobra.Command, args []string) error {
	var err error

	// set the models pkg path
	modelsPkg = viper.GetString("sqlboiler-models")
	if modelsPkg == "" {
		modFile, err := goModInfo()
		if err != nil {
			return commandFailure("must provide the models package (--sqlboiler-models) or be in a go module")
		}

		modelsPkg = modFile.Module.Mod.Path + "/models"
	}

	if len(args) == 0 {
		return commandFailure("must provide a driver name")
	}

	driverName, driverPath, err := drivers.RegisterBinaryFromCmdArg(args[0])
	if err != nil {
		return fmt.Errorf("could not register driver: %w", err)
	}

	// Create the directior
	tempTemplatesDir, err = ioutil.TempDir("", "boilingseed")
	if err != nil {
		return fmt.Errorf("could not create temp directory: %w", err)
	}

	// Add a folder for our singleton templates
	if err := os.Mkdir(tempTemplatesDir+"/singleton", 0o755); err != nil {
		return fmt.Errorf("could not make singleton temp directory: %w", err)
	}

	// Write template files to this directory
	if err := copyTemplates(tempTemplatesDir); err != nil {
		return fmt.Errorf("could not copy seed template files: %w", err)
	}

	cmdConfig = &boilingcore.Config{
		DriverName: driverName,
		OutFolder:  viper.GetString("output"),
		PkgName:    viper.GetString("pkgname"),
		Debug:      viper.GetBool("debug"),
		NoContext:  viper.GetBool("no-context"),
		NoTests:    viper.GetBool("no-tests"),
		Wipe:       viper.GetBool("wipe"),
		Version:    "boilingseed-" + boilingSeedVersion,

		// Things we specifically override
		TemplateDirs:      []string{tempTemplatesDir},
		NoDriverTemplates: true,
	}

	if cmdConfig.Debug {
		fmt.Fprintln(os.Stderr, "using driver:", driverPath)
		fmt.Fprintln(os.Stderr, "using models:", modelsPkg)
	}

	// Configure the driver
	cmdConfig.DriverConfig = map[string]interface{}{
		"whitelist": viper.GetStringSlice(driverName + ".whitelist"),
		"blacklist": viper.GetStringSlice(driverName + ".blacklist"),
	}

	keys := allKeys(driverName)
	for _, key := range keys {
		if key != "blacklist" && key != "whitelist" {
			prefixedKey := fmt.Sprintf("%s.%s", driverName, key)
			cmdConfig.DriverConfig[key] = viper.Get(prefixedKey)
		}
	}

	cmdConfig.Imports = configureImports()

	cmdState, err = boilingcore.New(cmdConfig)
	return err
}

func run(cmd *cobra.Command, args []string) error {
	return cmdState.Run()
}

func postRun(cmd *cobra.Command, args []string) error {
	err := os.RemoveAll(tempTemplatesDir)
	if err != nil {
		return fmt.Errorf("could not clean up temp templates directory: %w", err)
	}

	return cmdState.Cleanup()
}

func allKeys(prefix string) []string {
	keys := make(map[string]bool)

	prefix += "."

	for _, e := range os.Environ() {
		splits := strings.SplitN(e, "=", 2)
		key := strings.ReplaceAll(strings.ToLower(splits[0]), "_", ".")

		if strings.HasPrefix(key, prefix) {
			keys[strings.ReplaceAll(key, prefix, "")] = true
		}
	}

	for _, key := range viper.AllKeys() {
		if strings.HasPrefix(key, prefix) {
			keys[strings.ReplaceAll(key, prefix, "")] = true
		}
	}

	keySlice := make([]string, 0, len(keys))
	for k := range keys {
		keySlice = append(keySlice, k)
	}
	return keySlice
}

func copyTemplates(dir string) error {
	w := tabwriter.NewWriter(os.Stdout, 0, 0, 0, ' ', tabwriter.Debug)
	defer w.Flush()

	return fs.WalkDir(templates, ".", func(path string, info fs.DirEntry, err error) error {
		if err != nil {
			return fmt.Errorf("an error was passed to the walkFunc: %w", err)
		}

		if info.IsDir() {
			return nil
		}

		relPath := strings.TrimPrefix(path, "templates/")

		tplFile, err := templates.Open(path)
		if err != nil {
			return fmt.Errorf("error when opening template file: %w", err)
		}
		defer tplFile.Close()

		newFile, err := os.Create(filepath.Join(dir, relPath))
		if err != nil {
			return fmt.Errorf("error when creating new file: %w", err)
		}
		defer newFile.Close()

		_, err = io.Copy(newFile, tplFile)
		if err != nil {
			return fmt.Errorf("error when copying file: %w", err)
		}

		return nil
	})
}

func configureImports() importers.Collection {
	imports := importers.NewDefaultImports()

	imports.All.Standard = []string{`"fmt"`, `"math"`}
	imports.All.ThirdParty = []string{
		fmt.Sprintf(`models "%s"`, modelsPkg),
		`"github.com/volatiletech/sqlboiler/v4/boil"`,
		`"github.com/volatiletech/sqlboiler/v4/queries"`,
		`"github.com/volatiletech/randomize"`,
	}
	imports.Singleton["boilingseed_main"] = importers.Set{
		Standard: []string{`"fmt"`, `"sync"`, `"time"`, `"context"`, `"math/rand"`},
		ThirdParty: []string{
			fmt.Sprintf(`models "%s"`, modelsPkg),
			`"github.com/volatiletech/sqlboiler/v4/boil"`,
		},
	}

	return imports
}

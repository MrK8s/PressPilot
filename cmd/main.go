package main

import (
	"flag"
    "fmt"
    "os"
    "os/exec"
    "strings"
    "time"
    "net/http"
	"path/filepath"
	"bytes"
)

func main() {
    installCommand := flag.NewFlagSet("install", flag.ExitOnError)

    externalNetworkID := installCommand.String("external_network_id", "", "External Network ID")
    imageName := installCommand.String("image_name", "", "Image Name")
    flavorName := installCommand.String("flavor_name", "", "Flavor Name")
    publicNetwork := installCommand.String("public_network", "", "Public Network Name")

    if len(os.Args) < 2 {
        fmt.Println("expected 'install' subcommands")
        os.Exit(1)
    }

    switch os.Args[1] {
    case "install":
        installCommand.Parse(os.Args[2:])

        // Running Terraform init and apply
        runTerraformCommand("terraform/openstack", "init")
        terraformApplyCmd := []string{
            "-auto-approve",
            fmt.Sprintf("-var=external_network_id=%s", *externalNetworkID),
            fmt.Sprintf("-var=image_name=%s", *imageName),
            fmt.Sprintf("-var=flavor_name=%s", *flavorName),
            fmt.Sprintf("-var=public_network=%s", *publicNetwork),
        }
        runTerraformCommand("terraform/openstack", "apply", terraformApplyCmd...)

        wpURL, err := getTerraformOutput("terraform/openstack", "wordpress_floating_ip")
        if err != nil {
            fmt.Println("Error getting WordPress URL:", err)
            return
        }

        fmt.Println("Polling WordPress service to check if it's up...")
        pollWordPressService(wpURL)

    default:
        fmt.Println("expected 'install' subcommands")
        os.Exit(1)
    }
}

func runTerraformCommand(dir, command string, args ...string) {
    baseDir := filepath.Join("..")
    absDirPath, err := filepath.Abs(filepath.Join(baseDir, dir)) // Create an absolute path to the Terraform directory
    if err != nil {
        fmt.Println("Error constructing path to Terraform directory:", err)
        os.Exit(1)
    }

    // Prepend the '-chdir' option with the correct path
    cmdArgs := append([]string{"-chdir=" + absDirPath, command}, args...)
    cmd := exec.Command("terraform", cmdArgs...)
    cmd.Stdout = os.Stdout
    cmd.Stderr = os.Stderr

	var out bytes.Buffer
    cmd.Stdout = &out
    cmd.Stderr = &out

    if err := cmd.Run(); err != nil {
        fmt.Println("Error running Terraform command:", err)
        os.Exit(1)
    }

	if command == "init" {
        fmt.Println("🚀 Deployment has been initialized!")
    } else if command == "apply" {
        fmt.Println("🚧 Applying components...")
    } 
}

func getTerraformOutput(dir, outputName string) (string, error) {
    baseDir := filepath.Join("..") // Navigate up twice to get to 'web-deploy' from 'cmd'
    absDirPath, err := filepath.Abs(filepath.Join(baseDir, dir)) // Create an absolute path to the Terraform directory
    if err != nil {
        return "", fmt.Errorf("Error constructing path to Terraform directory: %v", err)
    }

    cmd := exec.Command("terraform", "-chdir="+absDirPath, "output", "-raw", outputName)
    out, err := cmd.Output()
    if err != nil {
        return "", err
    }
    return strings.TrimSpace(string(out)), nil
}

func pollWordPressService(wpURL string) {
    wpInstallURL := "http://" + wpURL + "/wp-admin/install.php"
    for {
        resp, err := http.Get(wpInstallURL)
        if err != nil {
            fmt.Println("Error checking WordPress service:", err)
            time.Sleep(5 * time.Second)
            continue
        }
        if resp.StatusCode == http.StatusOK {
            fmt.Println("🎉 WordPress service is up!:", wpInstallURL)
            break
        }
        fmt.Println("Waiting for WordPress to be accessible...")
        time.Sleep(5 * time.Second)
    }
}

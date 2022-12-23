package main

import (
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"strconv"
	"strings"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
)

// ////////////////////////////////// SCRIPTS MIDDLEWARE
func deliver(s string, arch string, mode string) string {
	cmd := exec.Command("bash", "deliver.sh", s, arch, mode)
	stdout, err := cmd.Output()
	if err != nil {
		return fmt.Sprintf("%s", err)
	}
	return string(stdout)
}
func script_ensure_piped(query string) string {
	cmd := exec.Command("bash", "script_ensure_piped.sh", query)
	stdout, err := cmd.Output()
	if err != nil {
		return fmt.Sprintf("%s", err)
	}
	return string(stdout)
}
func script_validates_params(s string, arch string) string {
	cmd := exec.Command("bash", "script_validates_params.sh", s, arch)
	stdout, err := cmd.Output()
	if err != nil {
		return fmt.Sprintf("%s", err)
	}
	return string(stdout)
}

// /////////////////////////////////////// ROUTES
func script(c echo.Context) error {
	s := c.Param("secret")
	arch := c.Param("arch")
	return c.String(http.StatusOK, script_validates_params(s, arch))
}

func standalone(c echo.Context) error {
	s := c.Param("secret")
	arch := c.Param("arch")
	r := deliver(s, arch, "standalone")

	res := strings.Split(r, "::")
	status, _ := strconv.Atoi(res[0])
	message := res[1]

	if status == 200 {
		return c.Attachment(message, "instantvpn-"+s+"-"+arch)
	}
	return c.String(status, message)
}

func enforce_piping(c echo.Context) error {
	q := fmt.Sprintf("%v", c.Request().RequestURI)
	return c.String(http.StatusOK, script_ensure_piped(q))
}

// /////////////////////////////////////// MAIN
func main() {

	e := echo.New()

	e.Use(middleware.Logger())
	e.Use(middleware.Recover())
	e.Pre(middleware.RemoveTrailingSlash())

	e.GET("/shell/vpn/:secret/:arch", script)
	e.GET("/dl/vpn/:secret/:arch", standalone)
	e.GET("/vpn/*", enforce_piping)
	e.Any("/*", script)

	httpPort := os.Getenv("HTTP_PORT")
	if httpPort == "" {
		httpPort = "8080"
	}

	e.Logger.Fatal(e.Start(":" + httpPort))
}

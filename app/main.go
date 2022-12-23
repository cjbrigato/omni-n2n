package main

import (
	"fmt"
	"net/http"
	"os"
	"os/exec"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
)

func handle(c echo.Context) error {
	s := c.Param("secret")
	arch := c.Param("arch")
	return c.String(http.StatusOK, generate(s, arch, "live"))
}

func validate(c echo.Context) error {
	q := fmt.Sprintf("%v", c.Request().RequestURI)
	return c.String(http.StatusOK, preflight(q))
}

func get(c echo.Context) error {
	s := c.Param("secret")
	arch := c.Param("arch")
	file := download(s, arch)
	return c.Attachment(file, "instantvpn-"+s+"-"+arch)
}

func download(s string, arch string) string {
	cmd := exec.Command("bash", "deliver.sh", s, arch, "download")
	stdout, err := cmd.Output()
	if err != nil {
		return fmt.Sprintf("%s", err)
	}
	return string(stdout)
}

func generate(s string, arch string, mode string) string {
	cmd := exec.Command("bash", "generate.sh", s, arch, mode)
	stdout, err := cmd.Output()
	if err != nil {
		return fmt.Sprintf("%s", err)
	}
	return string(stdout)
}

func preflight(query string) string {
	cmd := exec.Command("bash", "preflight.sh", query)
	stdout, err := cmd.Output()
	if err != nil {
		return fmt.Sprintf("%s", err)
	}
	return string(stdout)
}

func main() {

	e := echo.New()

	e.Use(middleware.Logger())
	e.Use(middleware.Recover())
	e.Pre(middleware.RemoveTrailingSlash())

	e.GET("/shell/vpn/:secret/:arch", handle)
	e.GET("/dl/vpn/:secret/:arch", get)
	e.GET("/vpn/*", validate)
	e.Any("/*", handle)

	httpPort := os.Getenv("HTTP_PORT")
	if httpPort == "" {
		httpPort = "8080"
	}

	e.Logger.Fatal(e.Start(":" + httpPort))
}

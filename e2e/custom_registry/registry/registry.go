package main

import (
	"fmt"
	"log"
	"net"
	"net/http"

	"github.com/google/go-containerregistry/pkg/registry"
)

func main() {
	listener, err := net.Listen("tcp", ":0")
	if err != nil {
		log.Fatalln(err)
	}
	port := listener.Addr().(*net.TCPAddr).Port
	fmt.Println(port)
	s := &http.Server{
		Handler: registry.New(),
	}
	log.Fatal(s.Serve(listener))
}

package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"

	"github.com/google/go-containerregistry/pkg/registry"
	"github.com/r3labs/diff/v3"
)

type Authn struct {
	Authorization []string `json:"Authorization"`
}

func main() {

	var auth Authn

	scanner := bufio.NewScanner(os.Stdin)

	go func() {
		for scanner.Scan() {
			content := scanner.Text()
			if content == "exit" {
				os.Exit(0)
			}
			fmt.Println(content)
			err := json.Unmarshal([]byte(content), &auth)
			if err != nil {
				log.Fatalln(err)
			}
		}
		fmt.Println("out of loop")
		if scanner.Err() != nil {
			log.Fatalln(scanner.Err())
		} else {
			log.Println("pipe closed")
		}
	}()

	reg := registry.New(registry.Logger(log.New(ioutil.Discard, "", log.LstdFlags)))
	s := &http.Server{
		Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.RequestURI == "/v2/empty_image/static/manifests/sha256:c3c3d0230d487c0ad3a0d87ad03ee02ea2ff0b3dcce91ca06a1019e07de05f12" {
				currentAuth := Authn{Authorization: []string{}}
				if r.Header["Authorization"] != nil {
					currentAuth.Authorization = r.Header["Authorization"]
				}

				var ret []byte

				changes, err := diff.Diff(currentAuth, auth)

				if err != nil {
					ret = []byte(err.Error())
				} else if len(changes) > 0 {
					ret, err = json.Marshal(changes)
					if err != nil {
						ret = []byte(err.Error())
					}
				}
				if len(ret) > 0 {
					fmt.Println(string(ret))
					w.WriteHeader(http.StatusUnauthorized)
					return
				}

			}

			reg.ServeHTTP(w, r)
		}),
		Addr: "localhost:1447",
	}
	err := s.ListenAndServe()
	if err != nil {
		fmt.Println(err)
	}
}

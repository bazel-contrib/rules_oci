package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"

	"github.com/fsnotify/fsnotify"
	"github.com/google/go-containerregistry/pkg/registry"
	"github.com/r3labs/diff/v3"
)

type Authn struct {
	Authorization []string `json:"Authorization"`
}

func read_auth(p string) (*Authn, error) {
	var auth Authn
	bytes, err := ioutil.ReadFile(p)
	if err != nil {
		return &auth, err
	}
	auth = Authn{}
	err = json.Unmarshal(bytes, &auth)
	if err != nil {
		return &auth, err
	}
	return &auth, nil
}

func main() {
	authPath := os.Args[1]

	auth, err := read_auth(authPath)
	if err != nil {
		log.Fatalln(err)
	}

	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		log.Fatal(err)
	}
	defer watcher.Close()

	err = watcher.Add(authPath)
	if err != nil {
		log.Fatal(err)
	}

	go func() {
		for {
			select {
			case event, ok := <-watcher.Events:
				if !ok {
					return
				}
				if event.Has(fsnotify.Write) {
					fmt.Println("Assertion file has changed. upcoming requests will be asserted against it.")
					auth, err = read_auth(authPath)
					if err != nil {
						log.Fatalln(err)
					}
				}
			case err, ok := <-watcher.Errors:
				if !ok {
					return
				}
				log.Fatalln(err)
			}
		}
	}()

	reg := registry.New(registry.Logger(log.New(ioutil.Discard, "", log.LstdFlags)))
	s := &http.Server{
		Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.RequestURI == "/v2/distroless/static/manifests/sha256:c3c3d0230d487c0ad3a0d87ad03ee02ea2ff0b3dcce91ca06a1019e07de05f12" {
				currentAuth := Authn{Authorization: []string{}}
				if r.Header["Authorization"] != nil {
					currentAuth.Authorization = r.Header["Authorization"]
				}

				var ret []byte

				changes, err := diff.Diff(currentAuth, *auth)

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
	err = s.ListenAndServe()
	if err != nil {
		fmt.Println(err)
	}
}

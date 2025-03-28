package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"strings"

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
			err := json.Unmarshal([]byte(content), &auth)
			if err != nil {
				log.Fatalln(err)
			}
			fmt.Println(content)
		}
		if scanner.Err() != nil {
			log.Fatalln(scanner.Err())
		}
	}()

	reg := registry.New(
		registry.Logger(log.New(ioutil.Discard, "", log.LstdFlags)),
	)
	s := &http.Server{
		Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if strings.Contains(r.RequestURI, "/token") {
				if r.Header["Authorization"] == nil || r.Header["Authorization"][0] != "Basic dGVzdDp0ZXN0" {
					w.WriteHeader(http.StatusUnauthorized)
					w.Write([]byte("{\"errors\":[{\"code\":\"UNAUTHORIZED\",\"message\":\"authentication required\"}]}"))
				} else {
					w.WriteHeader(http.StatusOK)
					w.Write([]byte("{\"token\": \"here_is_the_token\"}"))
				}
				return
			} else if strings.Contains(r.RequestURI, "/v2/empty_image/") {
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

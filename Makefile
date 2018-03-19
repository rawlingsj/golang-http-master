SHELL := /bin/bash
GO := GO15VENDOREXPERIMENT=1 go
VERSION := $(shell cat VERSION)
ROOT_PACKAGE := $(GIT_PROVIDER)/$(ORG)/$(APP_NAME)
GO_VERSION := $(shell $(GO) version | sed -e 's/^[^0-9.]*\([0-9.]*\).*/\1/')
PACKAGE_DIRS := $(shell $(GO) list ./... | grep -v /vendor/)
PKGS := $(shell go list ./... | grep -v /vendor | grep -v generated)
BUILDFLAGS := ''
CGO_ENABLED = 0
VENDOR_DIR=vendor

all: build

check: fmt build test

build:
	CGO_ENABLED=$(CGO_ENABLED) $(GO) build $(BUILDFLAGS) -o build/$(APP_NAME) $(APP_NAME).go

test: 
	CGO_ENABLED=$(CGO_ENABLED) $(GO) test $(PACKAGE_DIRS) -test.v

full: $(PKGS)

install:
	GOBIN=${GOPATH}/bin $(GO) install $(BUILDFLAGS) $(APP_NAME).go

fmt:
	@FORMATTED=`$(GO) fmt $(PACKAGE_DIRS)`
	@([[ ! -z "$(FORMATTED)" ]] && printf "Fixed unformatted files:\n$(FORMATTED)") || true

win:
	CGO_ENABLED=$(CGO_ENABLED) GOOS=windows GOARCH=amd64 $(GO) build $(BUILDFLAGS) -o build/$(APP_NAME).exe $(APP_NAME).go

bootstrap: vendoring

vendoring:
	$(GO) get -u github.com/Masterminds/glide
	GO15VENDOREXPERIMENT=1 glide update --strip-vendor

release: check
	rm -rf build release && mkdir build release
	for os in linux darwin ; do \
		CGO_ENABLED=$(CGO_ENABLED) GOOS=$$os GOARCH=amd64 $(GO) build $(BUILDFLAGS) -o build/$$os/$(APP_NAME) $(APP_NAME).go ; \
	done
	CGO_ENABLED=$(CGO_ENABLED) GOOS=windows GOARCH=amd64 $(GO) build $(BUILDFLAGS) -o build/$(APP_NAME)-windows-amd64.exe $(APP_NAME).go
	zip --junk-paths release/$(APP_NAME)-windows-amd64.zip build/$(APP_NAME)-windows-amd64.exe README.md LICENSE

	chmod +x build/darwin/$(APP_NAME)
	chmod +x build/linux/$(APP_NAME)

	cd ./build/darwin; tar -zcvf ../../release/$(APP_NAME)-darwin-amd64.tar.gz $(APP_NAME)
	cd ./build/linux; tar -zcvf ../../release/$(APP_NAME)-linux-amd64.tar.gz $(APP_NAME)

	go get -u github.com/progrium/gh-release
	gh-release checksums sha256
	gh-release create jenkins-x/$(APP_NAME) $(VERSION) master $(VERSION)

clean:
	rm -rf build release

linux:
	CGO_ENABLED=$(CGO_ENABLED) GOOS=linux GOARCH=amd64 $(GO) build $(BUILDFLAGS) -o build/$(APP_NAME)-linux-amd64 $(APP_NAME).go

.PHONY: release clean

preview: linux
	docker build -t $(JENKINS_X_DOCKER_REGISTRY_SERVICE_HOST):$(JENKINS_X_DOCKER_REGISTRY_SERVICE_PORT)/$(ORG)/$(APP_NAME):$(PREVIEW_VERSION) .
	docker push $(JENKINS_X_DOCKER_REGISTRY_SERVICE_HOST):$(JENKINS_X_DOCKER_REGISTRY_SERVICE_PORT/$(ORG)/$(APP_NAME):$(PREVIEW_VERSION)

FGT := $(GOPATH)/bin/fgt
$(FGT):
	go get github.com/GeertJohan/fgt

GOLINT := $(GOPATH)/bin/golint
$(GOLINT):
	go get github.com/golang/lint/golint

$(PKGS): $(GOLINT) $(FGT)
	@echo "LINTING"
	@$(FGT) $(GOLINT) $(GOPATH)/src/$@/*.go
	@echo "VETTING"
	@go vet -v $@
	@echo "TESTING"
	@go test -v $@

.PHONY: lint
lint: vendor | $(PKGS) $(GOLINT) # ❷
	@cd $(BASE) && ret=0 && for pkg in $(PKGS); do \
	    test -z "$$($(GOLINT) $$pkg | tee /dev/stderr)" || ret=1 ; \
	done ; exit $$ret

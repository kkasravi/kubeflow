GOLANG_VERSION ?= 1.12
GCLOUD_PROJECT ?= kubeflow-images-public
IMG ?= gcr.io/$(GCLOUD_PROJECT)/mutating-webhook
TAG ?= $(eval TAG := $(shell git describe --always --tags --long))$(TAG)
export GO111MODULE = on
export GO = go

build:
	docker build --no-cache --build-arg GOLANG_VERSION=$(GOLANG_VERSION) -t $(IMG):$(TAG) .

build-local:
	$(GO) build -gcflags 'all=-N -l' -o bin/webhook .

run-local:
	./bin/webhook
	
push:
	docker push $(IMG):$(TAG)

generate:
	./gen-cert.sh
	IMG=$(IMG) TAG=$(TAG) ./ca-bundle.sh
	

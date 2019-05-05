
# Image URL to use all building/pushing image targets
GCLOUD_PROJECT ?= kubeflow-images-public
IMG ?= gcr.io/$(GCLOUD_PROJECT)/profile-controller
TAG ?= $(eval TAG := $(shell git describe --tags --long))$(TAG)
GOLANG_VERSION ?= 1.12.4

all: test manager

# Run tests
test: generate fmt vet manifests
	echo "Skip test..."
	#go test ./pkg/... ./cmd/... -coverprofile cover.out

# Build manager binary
manager: generate fmt vet
	go build -o bin/manager github.com/kubeflow/kubeflow/components/profile-controller/cmd/manager

# Run against the configured Kubernetes cluster in ~/.kube/config
run: generate fmt vet
	go run ./cmd/manager/main.go

# Install CRDs into a cluster
install: manifests
	kubectl apply -f config/crds

# Deploy controller in the configured Kubernetes cluster in ~/.kube/config
deploy: manifests
	kubectl apply -f config/crds
	kustomize build config/default | kubectl apply -f -

# Generate manifests e.g. CRD, RBAC etc.
manifests:
	controller-gen all

# Run go fmt against code
fmt:
	go fmt ./pkg/... ./cmd/...

# Run go vet against code
vet:
	go vet ./pkg/... ./cmd/...

# Generate code
generate:
	go generate ./pkg/... ./cmd/...

# Build the docker image
docker-build: test
	docker build \
		--build-arg GOLANG_VERSION=$(GOLANG_VERSION) \
		--build-arg registries=reg_tmp \
		--target=builder \
		--tag $(IMG):$(TAG) .
	@echo "updating kustomize image patch file for manager resource"
	sed -i'' -e 's@image: .*@image: '"${IMG}:${TAG}"'@' ./config/default/manager_image_patch.yaml

# Push the docker image
docker-push:
	docker push ${IMG}:${TAG}

docker-push-latest:
	gcloud container images add-tag --quiet $(IMG):$(TAG) $(IMG):latest --verbosity=info
	echo created $(IMG):latest

build-gcr: test
	docker build -t $(IMG):$(TAG) .
	@echo Built $(IMG):$(TAG)

push-gcr: build-gcr
	docker push $(IMG):$(TAG)
	@echo Pushed $(IMG):$(TAG)

# Build the GCB workflow
build-gcb-spec:
	rm -rf ./gcb_build
	mkdir  -p gcb_build
	jsonnet ./gcb_build.jsonnet --ext-str imageBase=$(IMG) \
	  --ext-str gitVersion=$(GIT_VERSION) --ext-str tag=$(TAG) \
	  --ext-str useImageCache=$(USE_IMAGE_CACHE) \
	  > ./gcb_build/image_build.json

# Build using GCB. This is useful if we are on a slow internet connection
# and don't want to pull images locally.
# Its also used to build from our CI system.
build-gcb: build-gcb-spec
	gcloud builds submit --machine-type=n1-highcpu-32 --project=kubeflow-ci \
	    --config=./gcb_build/image_build.json \
		--timeout=3600 .

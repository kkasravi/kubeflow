# Build the manager binary
ARG GOLANG_VERSION=1.12.4
FROM golang:${GOLANG_VERSION} as builder

RUN go get github.com/derekparker/delve/cmd/dlv

# Copy in the go src
WORKDIR /go/src/github.com/kubeflow/kubeflow/components/profile-controller
COPY pkg/    pkg/
COPY cmd/    cmd/
COPY go.mod .

ENV GO111MODULE=on

RUN go mod download
# Build
RUN go build -gcflags 'all=-N -l' -o manager cmd/manager/main.go

# Copy the controller-manager into a thin image
FROM ubuntu:latest
WORKDIR /
COPY --from=builder /go/src/github.com/kubeflow/kubeflow/components/profile-controller/manager .
ENTRYPOINT ["/manager"]

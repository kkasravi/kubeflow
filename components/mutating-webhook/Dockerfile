# build stage
ARG GOLANG_VERSION=1.12
FROM golang:$GOLANG_VERSION AS build-env
RUN mkdir -p /go/src/github.com/kubeflow/kubeflow/components/mutating-webhook
ENV GO111MODULE=on
WORKDIR /go/src/github.com/kubeflow/kubeflow/components/mutating-webhook
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -gcflags 'all=-N -l' -ldflags '-extldflags "-static"' -o bin/webhook
ENTRYPOINT ["/go/src/github.com/kubeflow/kubeflow/components/mutating-webhook/bin/webhook"]

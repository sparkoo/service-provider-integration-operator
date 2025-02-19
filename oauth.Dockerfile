# Build the manager binary
FROM golang:1.19 as builder

WORKDIR /workspace
# Copy the Go Modules manifests
COPY go.mod go.mod
COPY go.sum go.sum
# cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN go mod download

COPY static/ static/

# Copy the go source
COPY cmd/oauth cmd/oauth
COPY api/ api/
COPY oauth/ oauth/
COPY pkg/ pkg/

# Build
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o bin/ -a ./cmd/oauth/oauth.go

# Compose the final image of spi-oauth service
FROM registry.access.redhat.com/ubi8/ubi-minimal:8.7-923.1669829893 as spi-oauth

# Install the 'shadow-utils' which contains `adduser` and `groupadd` binaries
RUN microdnf install shadow-utils \
	&& groupadd --gid 65532 nonroot \
	&& adduser \
		--no-create-home \
		--no-user-group \
		--uid 65532 \
		--gid 65532 \
		nonroot

COPY --from=builder /workspace/bin/oauth /spi-oauth
COPY --from=builder /workspace/static/callback_success.html /static/callback_success.html
COPY --from=builder /workspace/static/callback_error.html /static/callback_error.html
COPY --from=builder /workspace/static/redirect_notice.html /static/redirect_notice.html

WORKDIR /
USER 65532:65532

ENTRYPOINT ["/spi-oauth"]

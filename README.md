# AI Grid backend

`ai-grid-backend` is a Go gRPC service that reads Open Cluster Management
(OCM)/RHACM `ManagedCluster` resources from the Kubernetes API.

The current API includes:

- `ai_grid.v1.AiGrid/Ping`
- `ai_grid.v1.ManagedClusters/ListManagedClusters`
- `ai_grid.v1.Tenants/ListTenants`

`ListManagedClusters` uses the Kubernetes dynamic client and queries:

```text
cluster.open-cluster-management.io/v1/managedclusters
```

The service runs in-cluster using its Kubernetes ServiceAccount. Its RBAC role
allows `get`, `list`, and `watch` on `ManagedCluster` resources.

`ListTenants` reads Keycloak Organizations from the `ai-grid` realm through the
Keycloak Admin REST API. The Kind setup creates two sample Organizations,
`tenant-a` and `tenant-b`, and configures the backend with the development
Keycloak admin credentials. Use a dedicated service account with the
`query-organizations` role instead of these credentials outside local testing.

## Local architecture

The local environment is Kubernetes-native:

```text
Kind cluster using Podman
├── OCM Cluster Manager
├── ai-grid-backend
├── Keycloak
└── PostgreSQL for Keycloak
```

The backend and Keycloak are deployed as Kubernetes workloads. Podman is used
by Kind to build and run the cluster nodes; Podman Compose is not required.

## Prerequisites

Install or make available:

- Go 1.26.3
- Podman
- Kind
- kubectl
- clusteradm
- grpcurl

The repository is aligned with fulfillment-service and declares `go 1.26.3`.

Install upstream OCM's CLI with Go 1.26.3 if needed:

```sh
go install open-cluster-management.io/clusteradm/cmd/clusteradm@v1.4.0
```

Ensure `$(go env GOPATH)/bin` is on `PATH`.

Kind supports Podman through:

```sh
export KIND_EXPERIMENTAL_PROVIDER=podman
```

## Run the complete integration test

From the repository root:

```sh
export KIND_EXPERIMENTAL_PROVIDER=podman
bash hack/test-kind.sh
```

The test starts by running the prerequisite check directly. You can run that
check without changing the cluster:

```sh
bash hack/check-prereqs.sh
```

It validates Podman, Kind, kubectl, grpcurl, Go, and clusteradm. `clusteradm`
may be installed with:

```sh
go install open-cluster-management.io/clusteradm/cmd/clusteradm@v1.4.0
```

The scripts also recognize an explicit `CLUSTERADM_BIN` or the Go bin
directory.

The script:

1. Creates or reuses a Kind cluster named `ai-grid-hub`.
2. Builds `ai-grid-backend` with Podman and loads it into Kind.
3. Deploys the backend, Keycloak, and PostgreSQL.
4. Installs the OCM hub control plane with `clusteradm init`.
5. Creates two real `ManagedCluster` custom resources.
6. Creates the `ai-grid` Keycloak realm and two sample Organizations.
7. Port-forwards the backend gRPC Service.
8. Runs typed Go gRPC integration tests and verifies ping, clusters, and tenants.

The sample resources are defined in
[deploy/kind/sample-managedclusters.yaml](deploy/kind/sample-managedclusters.yaml).

## Run the environment manually

Create the cluster, build the image, and deploy the workloads:

```sh
export KIND_EXPERIMENTAL_PROVIDER=podman
bash hack/kind-up.sh
```

Install OCM and apply the sample clusters:

```sh
bash hack/ocm-up.sh
```

Expose the backend locally:

```sh
kubectl -n ai-grid port-forward service/ai-grid-backend 8080:8080
```

List available gRPC services:

```sh
grpcurl -plaintext localhost:8080 list
```

Call the ManagedCluster API:

```sh
grpcurl -plaintext -d '{}' localhost:8080 \
  ai_grid.v1.ManagedClusters/ListManagedClusters
```

Call the tenant API:

```sh
grpcurl -plaintext -d '{}' localhost:8080 \
  ai_grid.v1.Tenants/ListTenants
```

Call the service ping API:

```sh
grpcurl -plaintext -d '{"name":"Ada"}' localhost:8080 \
  ai_grid.v1.AiGrid/Ping
```

Keycloak is available inside the cluster at `keycloak.ai-grid.svc:8080`.
For local browser access, forward it with:

```sh
kubectl -n ai-grid port-forward service/keycloak 8081:8080
```

The development Keycloak credentials are `admin` / `admin`. The initialization
Job creates the `ai-grid` realm and Organizations `tenant-a` and `tenant-b`.

## Run Go tests

```sh
go test ./...
```

The repository also provides standard developer targets:

```sh
make build       # build bin/ai-grid-backend
make test        # run all Go tests
make lint        # gofmt check and go vet; uses golangci-lint when installed
make verify      # build, test, and lint
make kind-test   # full Podman/Kind integration test
```

The unit test uses a Kubernetes dynamic fake client. The Kind integration test
uses the real Kubernetes API server, real OCM CRD, real `ManagedCluster`
objects, Keycloak Organizations, and the deployed gRPC service.

## Clean up

Delete the local Kind cluster when finished:

```sh
kind delete cluster --name ai-grid-hub
```

## Repository layout

```text
cmd/ai-grid-backend/             service entrypoint
client/                          reusable gRPC client
proto/ai_grid/v1/                protobuf contract
gen/ai_grid/v1/                  generated protobuf and gRPC code
internal/ai_grid/                gRPC service implementations
internal/ai_grid/managedclusters.go Kubernetes-backed cluster API
internal/ai_grid/tenants.go      Keycloak-backed tenant API
internal/keycloak/               Keycloak Admin API client
deploy/kind/                     Kubernetes manifests
hack/kind-up.sh                  build/load/deploy helper
hack/ocm-up.sh                   OCM bootstrap helper
hack/check-prereqs.sh            local toolchain and runtime preflight
hack/test-kind.sh                end-to-end integration test
integration/kind_test.go         typed gRPC integration test
Makefile                         build, test, lint, and Kind targets
```


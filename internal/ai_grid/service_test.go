package aigrid

import (
	"context"
	"testing"

	aigridv1 "github.com/osac-project/ai-grid-backend/gen/ai_grid/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/client-go/dynamic/fake"
)

func TestListManagedClusters(t *testing.T) {
	client := fake.NewSimpleDynamicClient(runtime.NewScheme(),
		managedCluster("cluster-a", map[string]string{"environment": "production"}, true),
		managedCluster("cluster-b", map[string]string{"environment": "development"}, false),
	)
	service := Service{client: client}

	response, err := service.ListManagedClusters(context.Background(), &aigridv1.ListManagedClustersRequest{})
	if err != nil {
		t.Fatalf("ListManagedClusters() returned an error: %v", err)
	}
	if len(response.GetClusters()) != 2 {
		t.Fatalf("expected 2 clusters, got %d", len(response.GetClusters()))
	}
	if response.GetClusters()[0].GetName() != "cluster-a" {
		t.Fatalf("expected cluster-a, got %q", response.GetClusters()[0].GetName())
	}
	if response.GetClusters()[0].GetLabels()["environment"] != "production" {
		t.Fatalf("expected production label, got %v", response.GetClusters()[0].GetLabels())
	}
}

func managedCluster(name string, labels map[string]string, accepts bool) *unstructured.Unstructured {
	jsonLabels := make(map[string]interface{}, len(labels))
	for key, value := range labels {
		jsonLabels[key] = value
	}
	return &unstructured.Unstructured{Object: map[string]interface{}{
		"apiVersion": "cluster.open-cluster-management.io/v1",
		"kind":       "ManagedCluster",
		"metadata": map[string]interface{}{
			"name":   name,
			"labels": jsonLabels,
		},
		"spec": map[string]interface{}{
			"hubAcceptsClient": accepts,
		},
	}}
}

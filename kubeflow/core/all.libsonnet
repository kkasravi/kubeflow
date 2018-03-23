{
  parts(params):: {
    local ambassador = import "kubeflow/core/ambassador.libsonnet",
    local iap = import "kubeflow/core/iap.libsonnet",
    local certmanager = import "kubeflow/core/cert-manager.libsonnet",
    local jupyter = import "kubeflow/core/jupyterhub.libsonnet",
    local nfs = import "kubeflow/core/nfs.libsonnet",
    local tfjob = import "kubeflow/core/tf-job.libsonnet",
    local spartakus = import "kubeflow/core/spartakus.libsonnet",

    all:: jupyter.all(params) + 
          tfjob.all(params) + 
          ambassador.all(params) + 
          nfs.all(params) + 
          iap.all(params) + 
          certmanager.all(params) + 
          spartakus.all(params),
  },
}

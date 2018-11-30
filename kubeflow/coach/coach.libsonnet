{
  local k = import "k.libsonnet",
  local util = import "kubeflow/core/util.libsonnet",
  local service = k.core.v1.service,
  local deployment = k.apps.v1beta1.deployment,
  local container = deployment.mixin.spec.template.spec.containersType,

  new(_env, _params):: {
    local params = _env + _params {
      labels: {
        app: _params.redis_server_name,
      },
      imageURL: _params.registry + "/" + _params.repoPath + "/" + _params.image,
    },
    params:: params,

    local coachMemoryService =
      service.new(
        name=params.redis_service_name,
        selector=params.labels,
        ports=service.mixin.spec.portsType.new(params.redis_port, params.redis_port).
          withProtocol('TCP'),
      ),
      service.mixin.metadata.
        withNamespace(params.namespace).
        withAnnotationsMixin({
        "getambassador.io/config":
          std.join("\n", [
            "---",
            "apiVersion: ambassador/v0",
            "kind:  Mapping",
            "name: coach-mapping",
            "prefix: /coach/",
            "rewrite: /",
            "service: " + params.name + "." + params.namespace + ":" + params.redis_port,
          ]),
      }),
    coachMemoryService:: coachMemoryService,

    local coachContainer = container.new(params.redis_server_name, params.image),

    local coachMemoryDeployment =
      deployment.new(
        name=params.redis_server_name,
        containers=coachContainer,
        podLabels=params.labels,
      ) +
      deployment.mixin.metadata.
        withNamespace(params.namespace).
        withLabelsMixin(params.labels),
    coachMemoryDeployment:: coachMemoryDeployment,

    parts:: self,
    all:: [
      self.coachMemoryService,
      self.coachMemoryDeployment,
    ],

    list(obj=self.all):: util.list(obj),
  },
}

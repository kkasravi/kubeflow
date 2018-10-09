
local test = {
  request:  {
    parent: {
      metadata: {
        namespace: 'kf-100-user',
      },
      status: {
        created: false,
      },
    },
    children: 
{
  'ConfigMap.v1': {
    'jupyterhub-config': {
      apiVersion: 'v1',
      data: {
        'jupyterhub_config.py': "import json\nimport os\nimport string\nimport escapism\nfrom kubespawner.spawner import KubeSpawner\nfrom jhub_remote_user_authenticator.remote_user_auth import RemoteUserAuthenticator\nfrom oauthenticator.github import GitHubOAuthenticator\n\nSERVICE_ACCOUNT_SECRET_MOUNT = '/var/run/secrets/sa'\n\nclass KubeFormSpawner(KubeSpawner):\n\n    # relies on HTML5 for image datalist\n    def _options_form_default(self):\n        global registry, repoName\n        return '''\n\n    <table style=\"width: 100%;\">\n    <tr>\n        <td style=\"width: 30%;\"><label for='image'>Image</label></td>\n        <td style=\"width: 70%;\"><input value=\"\" list=\"image\" name=\"image\" placeholder='repo/image:tag' style=\"width: 100%;\">\n        <datalist id=\"image\">\n          <option value=\"{0}/{1}/tensorflow-1.4.1-notebook-cpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.4.1-notebook-gpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.5.1-notebook-cpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.5.1-notebook-gpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.6.0-notebook-cpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.6.0-notebook-gpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.7.0-notebook-cpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.7.0-notebook-gpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.8.0-notebook-cpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.8.0-notebook-gpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.9.0-notebook-cpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.9.0-notebook-gpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.10.1-notebook-cpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.10.1-notebook-gpu:v0.3.0\">\n        </datalist>\n        </td>\n    </tr>\n    </table>\n    <div style=\"text-align: center; padding: 10px;\">\n      <a id=\"toggle_advanced_options\" style=\"margin: 20%; cursor: pointer; font-weight: bold;\">Advanced</a>\n    </div>\n    <table id=\"advanced_fields\" style=\"display: none; width: 100%; border-spacing: 0px 25px; border-collapse: separate;\">\n    <tr>\n        <td><label for='cpu_guarantee'>CPU</label></td>\n        <td><input style=\"width: 100%;\" name='cpu_guarantee' placeholder='200m, 1.0, 2.5, etc'></input></td>\n    </tr>\n    <tr>\n        <td><label for='mem_guarantee'>Memory</label></td>\n        <td><input style=\"width: 100%;\" name='mem_guarantee' placeholder='100Mi, 1.5Gi'></input></td>\n    </tr>\n    <tr>\n        <td><label for='extra_resource_limits'>Extra Resource Limits</label></td>\n        <td><input style=\"width: 100%;\" name='extra_resource_limits' placeholder='{{&quot;nvidia.com/gpu&quot;: 3}}'></input></td>\n    </tr>\n    </table>\n\n    <script type=\"text/javascript\">\n      $('#toggle_advanced_options').on('click', function(e){{\n        $('#advanced_fields').toggle();\n      }});\n    </script>\n\n\n        '''.format(registry, repoName)\n\n    def options_from_form(self, formdata):\n        options = {}\n        options['image'] = formdata.get('image', [''])[0].strip()\n        options['cpu_guarantee'] = formdata.get(\n            'cpu_guarantee', [''])[0].strip()\n        options['mem_guarantee'] = formdata.get(\n            'mem_guarantee', [''])[0].strip()\n        options['extra_resource_limits'] = formdata.get(\n            'extra_resource_limits', [''])[0].strip()\n        return options\n\n    @property\n    def singleuser_image_spec(self):\n        global cloud\n        if cloud == 'ack':\n            image = 'registry.aliyuncs.com/kubeflow-images-public/tensorflow-notebook-cpu:v0.2.1'\n        else:\n            image = 'gcr.io/kubeflow-images-public/tensorflow-1.8.0-notebook-cpu:v0.3.0'\n        if self.user_options.get('image'):\n            image = self.user_options['image']\n        return image\n\n    image_spec = singleuser_image_spec\n\n    @property\n    def cpu_guarantee(self):\n        cpu = '500m'\n        if self.user_options.get('cpu_guarantee'):\n            cpu = self.user_options['cpu_guarantee']\n        return cpu\n\n    @property\n    def mem_guarantee(self):\n        mem = '1Gi'\n        if self.user_options.get('mem_guarantee'):\n            mem = self.user_options['mem_guarantee']\n        return mem\n\n    @property\n    def extra_resource_limits(self):\n        extra = ''\n        if self.user_options.get('extra_resource_limits'):\n            extra = json.loads(self.user_options['extra_resource_limits'])\n        return extra\n\n    def get_env(self):\n        env = super(KubeFormSpawner, self).get_env()\n        gcp_secret_name = os.environ.get('GCP_SECRET_NAME')\n        if gcp_secret_name:\n            env['GOOGLE_APPLICATION_CREDENTIALS'] = '{}/{}.json'.format(SERVICE_ACCOUNT_SECRET_MOUNT, gcp_secret_name)\n        return env\n\n    # TODO(kkasravi): add unit test\n    def _parse_user_name(self, username):\n        safe_chars = set(string.ascii_lowercase + string.digits)\n        name = username.split(':')[-1]\n        legacy = ''.join([s if s in safe_chars else '-' for s in name.lower()])\n        safe = escapism.escape(name, safe=safe_chars, escape_char='-').lower()\n        return legacy, safe, name\n\n    def _expand_user_properties(self, template):\n        # override KubeSpawner method to remove prefix accounts.google: for iap\n        # and truncate to 63 characters\n\n        # Set servername based on whether named-server initialised\n        if self.name:\n            servername = '-{}'.format(self.name)\n        else:\n            servername = ''\n\n        legacy, safe, name = self._parse_user_name(self.user.name)\n        rname = template.format(\n            userid=self.user.id,\n            username=safe,\n            unescaped_username=name,\n            legacy_escape_username=legacy,\n            servername=servername\n            )[:63]\n        return rname\n\n\n###################################################\n# JupyterHub Options\n###################################################\nc.JupyterHub.ip = '0.0.0.0'\nc.JupyterHub.hub_ip = '0.0.0.0'\n# Don't try to cleanup servers on exit - since in general for k8s, we want\n# the hub to be able to restart without losing user containers\nc.JupyterHub.cleanup_servers = False\n###################################################\n\n###################################################\n# Spawner Options\n###################################################\ncloud = os.environ.get('CLOUD_NAME')\nregistry = os.environ.get('REGISTRY')\nrepoName = os.environ.get('REPO_NAME')\nc.JupyterHub.spawner_class = KubeFormSpawner\n# Set both singleuser_image_spec and image_spec because\n# singleuser_image_spec has been deprecated in a future release\nc.KubeSpawner.singleuser_image_spec = '{0}/{1}/tensorflow-notebook'.format(registry, repoName)\nc.KubeSpawner.image_spec = '{0}/{1}/tensorflow-notebook'.format(registry, repoName)\n\nc.KubeSpawner.cmd = 'start-singleuser.sh'\nc.KubeSpawner.args = ['--allow-root']\n# gpu images are very large ~15GB. need a large timeout.\nc.KubeSpawner.start_timeout = 60 * 30\n# Increase timeout to 5 minutes to avoid HTTP 500 errors on JupyterHub\nc.KubeSpawner.http_timeout = 60 * 5\n\n# Volume setup\nc.KubeSpawner.singleuser_uid = 1000\nc.KubeSpawner.singleuser_fs_gid = 100\nc.KubeSpawner.singleuser_working_dir = '/home/jovyan'\nvolumes = []\nvolume_mounts = []\n\n# Allow environment vars to override uid and gid.\n# This allows local host path mounts to be read/writable\nenv_uid = os.environ.get('NOTEBOOK_UID')\nif env_uid:\n    c.KubeSpawner.singleuser_uid = int(env_uid)\nenv_gid = os.environ.get('NOTEBOOK_GID')\nif env_gid:\n    c.KubeSpawner.singleuser_fs_gid = int(env_gid)\naccess_local_fs = os.environ.get('ACCESS_LOCAL_FS')\nif access_local_fs == 'true':\n    def modify_pod_hook(spawner, pod):\n       pod.spec.containers[0].lifecycle = {\n            'postStart' : {\n               'exec' : {\n                   'command' : ['ln', '-s', '/mnt/local-notebooks', '/home/jovyan/local-notebooks' ]\n               }\n            }\n        }\n       return pod\n    c.KubeSpawner.modify_pod_hook = modify_pod_hook\n\n###################################################\n# Persistent volume options\n###################################################\n# Using persistent storage requires a default storage class.\n# TODO(jlewi): Verify this works on minikube.\n# see https://github.com/kubeflow/kubeflow/pull/22#issuecomment-350500944\npvc_mount = os.environ.get('NOTEBOOK_PVC_MOUNT')\nif pvc_mount and pvc_mount != 'null':\n    c.KubeSpawner.user_storage_pvc_ensure = True\n    c.KubeSpawner.storage_pvc_ensure = True\n    # How much disk space do we want?\n    c.KubeSpawner.user_storage_capacity = '10Gi'\n    c.KubeSpawner.storage_capacity = '10Gi'\n    c.KubeSpawner.pvc_name_template = 'claim-{username}{servername}'\n    volumes.append(\n        {\n            'name': 'volume-{username}{servername}',\n            'persistentVolumeClaim': {\n                'claimName': 'claim-{username}{servername}'\n            }\n        }\n    )\n    volume_mounts.append(\n        {\n            'mountPath': pvc_mount,\n            'name': 'volume-{username}{servername}'\n        }\n    )\n\nc.KubeSpawner.volumes = volumes\nc.KubeSpawner.volume_mounts = volume_mounts\n# Set both service_account and singleuser_service_account because\n# singleuser_service_account has been deprecated in a future release\nc.KubeSpawner.service_account = 'jupyter-notebook'\nc.KubeSpawner.singleuser_service_account = 'jupyter-notebook'\n# Authenticator\nif os.environ.get('KF_AUTHENTICATOR') == 'iap':\n    c.JupyterHub.authenticator_class ='jhub_remote_user_authenticator.remote_user_auth.RemoteUserAuthenticator'\n    c.RemoteUserAuthenticator.header_name = 'x-goog-authenticated-user-email'\nelse:\n    c.JupyterHub.authenticator_class = 'dummyauthenticator.DummyAuthenticator'\n\nif os.environ.get('DEFAULT_JUPYTERLAB').lower() == 'true':\n    c.KubeSpawner.default_url = '/lab'\n\n# PVCs\npvcs = os.environ.get('KF_PVC_LIST')\nif pvcs and pvcs != 'null':\n    for pvc in pvcs.split(','):\n        volumes.append({\n            'name': pvc,\n            'persistentVolumeClaim': {\n                'claimName': pvc\n            }\n        })\n        volume_mounts.append({\n            'name': pvc,\n            'mountPath': '/mnt/' + pvc\n        })\n\ngcp_secret_name = os.environ.get('GCP_SECRET_NAME')\nif gcp_secret_name:\n    volumes.append({\n      'name': gcp_secret_name,\n      'secret': {\n        'secretName': gcp_secret_name,\n      }\n    })\n    volume_mounts.append({\n        'name': gcp_secret_name,\n        'mountPath': SERVICE_ACCOUNT_SECRET_MOUNT\n    })\n",
      },
      kind: 'ConfigMap',
      metadata: {
        annotations: {
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': "{\"apiVersion\":\"v1\",\"data\":{\"jupyterhub_config.py\":\"import json\\nimport os\\nimport string\\nimport escapism\\nfrom kubespawner.spawner import KubeSpawner\\nfrom jhub_remote_user_authenticator.remote_user_auth import RemoteUserAuthenticator\\nfrom oauthenticator.github import GitHubOAuthenticator\\n\\nSERVICE_ACCOUNT_SECRET_MOUNT = '/var/run/secrets/sa'\\n\\nclass KubeFormSpawner(KubeSpawner):\\n\\n    # relies on HTML5 for image datalist\\n    def _options_form_default(self):\\n        global registry, repoName\\n        return '''\\n\\n    \\u003ctable style=\\\"width: 100%;\\\"\\u003e\\n    \\u003ctr\\u003e\\n        \\u003ctd style=\\\"width: 30%;\\\"\\u003e\\u003clabel for='image'\\u003eImage\\u003c/label\\u003e\\u003c/td\\u003e\\n        \\u003ctd style=\\\"width: 70%;\\\"\\u003e\\u003cinput value=\\\"\\\" list=\\\"image\\\" name=\\\"image\\\" placeholder='repo/image:tag' style=\\\"width: 100%;\\\"\\u003e\\n        \\u003cdatalist id=\\\"image\\\"\\u003e\\n          \\u003coption value=\\\"{0}/{1}/tensorflow-1.4.1-notebook-cpu:v0.3.0\\\"\\u003e\\n          \\u003coption value=\\\"{0}/{1}/tensorflow-1.4.1-notebook-gpu:v0.3.0\\\"\\u003e\\n          \\u003coption value=\\\"{0}/{1}/tensorflow-1.5.1-notebook-cpu:v0.3.0\\\"\\u003e\\n          \\u003coption value=\\\"{0}/{1}/tensorflow-1.5.1-notebook-gpu:v0.3.0\\\"\\u003e\\n          \\u003coption value=\\\"{0}/{1}/tensorflow-1.6.0-notebook-cpu:v0.3.0\\\"\\u003e\\n          \\u003coption value=\\\"{0}/{1}/tensorflow-1.6.0-notebook-gpu:v0.3.0\\\"\\u003e\\n          \\u003coption value=\\\"{0}/{1}/tensorflow-1.7.0-notebook-cpu:v0.3.0\\\"\\u003e\\n          \\u003coption value=\\\"{0}/{1}/tensorflow-1.7.0-notebook-gpu:v0.3.0\\\"\\u003e\\n          \\u003coption value=\\\"{0}/{1}/tensorflow-1.8.0-notebook-cpu:v0.3.0\\\"\\u003e\\n          \\u003coption value=\\\"{0}/{1}/tensorflow-1.8.0-notebook-gpu:v0.3.0\\\"\\u003e\\n          \\u003coption value=\\\"{0}/{1}/tensorflow-1.9.0-notebook-cpu:v0.3.0\\\"\\u003e\\n          \\u003coption value=\\\"{0}/{1}/tensorflow-1.9.0-notebook-gpu:v0.3.0\\\"\\u003e\\n          \\u003coption value=\\\"{0}/{1}/tensorflow-1.10.1-notebook-cpu:v0.3.0\\\"\\u003e\\n          \\u003coption value=\\\"{0}/{1}/tensorflow-1.10.1-notebook-gpu:v0.3.0\\\"\\u003e\\n        \\u003c/datalist\\u003e\\n        \\u003c/td\\u003e\\n    \\u003c/tr\\u003e\\n    \\u003c/table\\u003e\\n    \\u003cdiv style=\\\"text-align: center; padding: 10px;\\\"\\u003e\\n      \\u003ca id=\\\"toggle_advanced_options\\\" style=\\\"margin: 20%; cursor: pointer; font-weight: bold;\\\"\\u003eAdvanced\\u003c/a\\u003e\\n    \\u003c/div\\u003e\\n    \\u003ctable id=\\\"advanced_fields\\\" style=\\\"display: none; width: 100%; border-spacing: 0px 25px; border-collapse: separate;\\\"\\u003e\\n    \\u003ctr\\u003e\\n        \\u003ctd\\u003e\\u003clabel for='cpu_guarantee'\\u003eCPU\\u003c/label\\u003e\\u003c/td\\u003e\\n        \\u003ctd\\u003e\\u003cinput style=\\\"width: 100%;\\\" name='cpu_guarantee' placeholder='200m, 1.0, 2.5, etc'\\u003e\\u003c/input\\u003e\\u003c/td\\u003e\\n    \\u003c/tr\\u003e\\n    \\u003ctr\\u003e\\n        \\u003ctd\\u003e\\u003clabel for='mem_guarantee'\\u003eMemory\\u003c/label\\u003e\\u003c/td\\u003e\\n        \\u003ctd\\u003e\\u003cinput style=\\\"width: 100%;\\\" name='mem_guarantee' placeholder='100Mi, 1.5Gi'\\u003e\\u003c/input\\u003e\\u003c/td\\u003e\\n    \\u003c/tr\\u003e\\n    \\u003ctr\\u003e\\n        \\u003ctd\\u003e\\u003clabel for='extra_resource_limits'\\u003eExtra Resource Limits\\u003c/label\\u003e\\u003c/td\\u003e\\n        \\u003ctd\\u003e\\u003cinput style=\\\"width: 100%;\\\" name='extra_resource_limits' placeholder='{{\\u0026quot;nvidia.com/gpu\\u0026quot;: 3}}'\\u003e\\u003c/input\\u003e\\u003c/td\\u003e\\n    \\u003c/tr\\u003e\\n    \\u003c/table\\u003e\\n\\n    \\u003cscript type=\\\"text/javascript\\\"\\u003e\\n      $('#toggle_advanced_options').on('click', function(e){{\\n        $('#advanced_fields').toggle();\\n      }});\\n    \\u003c/script\\u003e\\n\\n\\n        '''.format(registry, repoName)\\n\\n    def options_from_form(self, formdata):\\n        options = {}\\n        options['image'] = formdata.get('image', [''])[0].strip()\\n        options['cpu_guarantee'] = formdata.get(\\n            'cpu_guarantee', [''])[0].strip()\\n        options['mem_guarantee'] = formdata.get(\\n            'mem_guarantee', [''])[0].strip()\\n        options['extra_resource_limits'] = formdata.get(\\n            'extra_resource_limits', [''])[0].strip()\\n        return options\\n\\n    @property\\n    def singleuser_image_spec(self):\\n        global cloud\\n        if cloud == 'ack':\\n            image = 'registry.aliyuncs.com/kubeflow-images-public/tensorflow-notebook-cpu:v0.2.1'\\n        else:\\n            image = 'gcr.io/kubeflow-images-public/tensorflow-1.8.0-notebook-cpu:v0.3.0'\\n        if self.user_options.get('image'):\\n            image = self.user_options['image']\\n        return image\\n\\n    image_spec = singleuser_image_spec\\n\\n    @property\\n    def cpu_guarantee(self):\\n        cpu = '500m'\\n        if self.user_options.get('cpu_guarantee'):\\n            cpu = self.user_options['cpu_guarantee']\\n        return cpu\\n\\n    @property\\n    def mem_guarantee(self):\\n        mem = '1Gi'\\n        if self.user_options.get('mem_guarantee'):\\n            mem = self.user_options['mem_guarantee']\\n        return mem\\n\\n    @property\\n    def extra_resource_limits(self):\\n        extra = ''\\n        if self.user_options.get('extra_resource_limits'):\\n            extra = json.loads(self.user_options['extra_resource_limits'])\\n        return extra\\n\\n    def get_env(self):\\n        env = super(KubeFormSpawner, self).get_env()\\n        gcp_secret_name = os.environ.get('GCP_SECRET_NAME')\\n        if gcp_secret_name:\\n            env['GOOGLE_APPLICATION_CREDENTIALS'] = '{}/{}.json'.format(SERVICE_ACCOUNT_SECRET_MOUNT, gcp_secret_name)\\n        return env\\n\\n    # TODO(kkasravi): add unit test\\n    def _parse_user_name(self, username):\\n        safe_chars = set(string.ascii_lowercase + string.digits)\\n        name = username.split(':')[-1]\\n        legacy = ''.join([s if s in safe_chars else '-' for s in name.lower()])\\n        safe = escapism.escape(name, safe=safe_chars, escape_char='-').lower()\\n        return legacy, safe, name\\n\\n    def _expand_user_properties(self, template):\\n        # override KubeSpawner method to remove prefix accounts.google: for iap\\n        # and truncate to 63 characters\\n\\n        # Set servername based on whether named-server initialised\\n        if self.name:\\n            servername = '-{}'.format(self.name)\\n        else:\\n            servername = ''\\n\\n        legacy, safe, name = self._parse_user_name(self.user.name)\\n        rname = template.format(\\n            userid=self.user.id,\\n            username=safe,\\n            unescaped_username=name,\\n            legacy_escape_username=legacy,\\n            servername=servername\\n            )[:63]\\n        return rname\\n\\n\\n###################################################\\n# JupyterHub Options\\n###################################################\\nc.JupyterHub.ip = '0.0.0.0'\\nc.JupyterHub.hub_ip = '0.0.0.0'\\n# Don't try to cleanup servers on exit - since in general for k8s, we want\\n# the hub to be able to restart without losing user containers\\nc.JupyterHub.cleanup_servers = False\\n###################################################\\n\\n###################################################\\n# Spawner Options\\n###################################################\\ncloud = os.environ.get('CLOUD_NAME')\\nregistry = os.environ.get('REGISTRY')\\nrepoName = os.environ.get('REPO_NAME')\\nc.JupyterHub.spawner_class = KubeFormSpawner\\n# Set both singleuser_image_spec and image_spec because\\n# singleuser_image_spec has been deprecated in a future release\\nc.KubeSpawner.singleuser_image_spec = '{0}/{1}/tensorflow-notebook'.format(registry, repoName)\\nc.KubeSpawner.image_spec = '{0}/{1}/tensorflow-notebook'.format(registry, repoName)\\n\\nc.KubeSpawner.cmd = 'start-singleuser.sh'\\nc.KubeSpawner.args = ['--allow-root']\\n# gpu images are very large ~15GB. need a large timeout.\\nc.KubeSpawner.start_timeout = 60 * 30\\n# Increase timeout to 5 minutes to avoid HTTP 500 errors on JupyterHub\\nc.KubeSpawner.http_timeout = 60 * 5\\n\\n# Volume setup\\nc.KubeSpawner.singleuser_uid = 1000\\nc.KubeSpawner.singleuser_fs_gid = 100\\nc.KubeSpawner.singleuser_working_dir = '/home/jovyan'\\nvolumes = []\\nvolume_mounts = []\\n\\n# Allow environment vars to override uid and gid.\\n# This allows local host path mounts to be read/writable\\nenv_uid = os.environ.get('NOTEBOOK_UID')\\nif env_uid:\\n    c.KubeSpawner.singleuser_uid = int(env_uid)\\nenv_gid = os.environ.get('NOTEBOOK_GID')\\nif env_gid:\\n    c.KubeSpawner.singleuser_fs_gid = int(env_gid)\\naccess_local_fs = os.environ.get('ACCESS_LOCAL_FS')\\nif access_local_fs == 'true':\\n    def modify_pod_hook(spawner, pod):\\n       pod.spec.containers[0].lifecycle = {\\n            'postStart' : {\\n               'exec' : {\\n                   'command' : ['ln', '-s', '/mnt/local-notebooks', '/home/jovyan/local-notebooks' ]\\n               }\\n            }\\n        }\\n       return pod\\n    c.KubeSpawner.modify_pod_hook = modify_pod_hook\\n\\n###################################################\\n# Persistent volume options\\n###################################################\\n# Using persistent storage requires a default storage class.\\n# TODO(jlewi): Verify this works on minikube.\\n# see https://github.com/kubeflow/kubeflow/pull/22#issuecomment-350500944\\npvc_mount = os.environ.get('NOTEBOOK_PVC_MOUNT')\\nif pvc_mount and pvc_mount != 'null':\\n    c.KubeSpawner.user_storage_pvc_ensure = True\\n    c.KubeSpawner.storage_pvc_ensure = True\\n    # How much disk space do we want?\\n    c.KubeSpawner.user_storage_capacity = '10Gi'\\n    c.KubeSpawner.storage_capacity = '10Gi'\\n    c.KubeSpawner.pvc_name_template = 'claim-{username}{servername}'\\n    volumes.append(\\n        {\\n            'name': 'volume-{username}{servername}',\\n            'persistentVolumeClaim': {\\n                'claimName': 'claim-{username}{servername}'\\n            }\\n        }\\n    )\\n    volume_mounts.append(\\n        {\\n            'mountPath': pvc_mount,\\n            'name': 'volume-{username}{servername}'\\n        }\\n    )\\n\\nc.KubeSpawner.volumes = volumes\\nc.KubeSpawner.volume_mounts = volume_mounts\\n# Set both service_account and singleuser_service_account because\\n# singleuser_service_account has been deprecated in a future release\\nc.KubeSpawner.service_account = 'jupyter-notebook'\\nc.KubeSpawner.singleuser_service_account = 'jupyter-notebook'\\n# Authenticator\\nif os.environ.get('KF_AUTHENTICATOR') == 'iap':\\n    c.JupyterHub.authenticator_class ='jhub_remote_user_authenticator.remote_user_auth.RemoteUserAuthenticator'\\n    c.RemoteUserAuthenticator.header_name = 'x-goog-authenticated-user-email'\\nelse:\\n    c.JupyterHub.authenticator_class = 'dummyauthenticator.DummyAuthenticator'\\n\\nif os.environ.get('DEFAULT_JUPYTERLAB').lower() == 'true':\\n    c.KubeSpawner.default_url = '/lab'\\n\\n# PVCs\\npvcs = os.environ.get('KF_PVC_LIST')\\nif pvcs and pvcs != 'null':\\n    for pvc in pvcs.split(','):\\n        volumes.append({\\n            'name': pvc,\\n            'persistentVolumeClaim': {\\n                'claimName': pvc\\n            }\\n        })\\n        volume_mounts.append({\\n            'name': pvc,\\n            'mountPath': '/mnt/' + pvc\\n        })\\n\\ngcp_secret_name = os.environ.get('GCP_SECRET_NAME')\\nif gcp_secret_name:\\n    volumes.append({\\n      'name': gcp_secret_name,\\n      'secret': {\\n        'secretName': gcp_secret_name,\\n      }\\n    })\\n    volume_mounts.append({\\n        'name': gcp_secret_name,\\n        'mountPath': SERVICE_ACCOUNT_SECRET_MOUNT\\n    })\\n\"},\"kind\":\"ConfigMap\",\"metadata\":{\"annotations\":{\"kubernetes.io/application\":\"kubeflow-app\"},\"labels\":{\"app\":\"kubeflow-app\",\"component\":\"jupyterhub-config\",\"controller-uid\":\"677a0dba-c8af-11e8-83f2-42010a8a0020\"},\"name\":\"jupyterhub-config\",\"namespace\":\"kf-100-user\"}}",
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'jupyterhub-config',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'jupyterhub-config',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920730',
        selfLink: '/api/v1/namespaces/kf-100-user/configmaps/jupyterhub-config',
        uid: '6de515b1-c8af-11e8-83f2-42010a8a0020',
      },
    },
    'tf-job-operator-config': {
      apiVersion: 'v1',
      data: {
        'controller_config_file.yaml': '{\n    "grpcServerFilePath": "/opt/mlkube/grpc_tensorflow_server/grpc_tensorflow_server.py"\n}',
      },
      kind: 'ConfigMap',
      metadata: {
        annotations: {
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"v1","data":{"controller_config_file.yaml":"{\\n    \\"grpcServerFilePath\\": \\"/opt/mlkube/grpc_tensorflow_server/grpc_tensorflow_server.py\\"\\n}"},"kind":"ConfigMap","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"tf-job-operator-config","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"tf-job-operator-config","namespace":"kf-100-user"}}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'tf-job-operator-config',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'tf-job-operator-config',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920735',
        selfLink: '/api/v1/namespaces/kf-100-user/configmaps/tf-job-operator-config',
        uid: '6de976a9-c8af-11e8-83f2-42010a8a0020',
      },
    },
  },
  'CustomResourceDefinition.apiextensions.k8s.io/v1beta1': {},
  'Deployment.extensions/v1beta1': {
    ambassador: {
      apiVersion: 'extensions/v1beta1',
      kind: 'Deployment',
      metadata: {
        annotations: {
          'deployment.kubernetes.io/revision': '1',
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"extensions/v1beta1","kind":"Deployment","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"ambassador","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"ambassador","namespace":"kf-100-user"},"spec":{"replicas":3,"template":{"metadata":{"labels":{"service":"ambassador"},"namespace":"kf-100-user"},"spec":{"containers":[{"env":[{"name":"AMBASSADOR_NAMESPACE","valueFrom":{"fieldRef":{"fieldPath":"metadata.namespace"}}},{"name":"AMBASSADOR_SINGLE_NAMESPACE","value":"true"}],"image":"quay.io/datawire/ambassador:0.37.0","livenessProbe":{"httpGet":{"path":"/ambassador/v0/check_alive","port":8877},"initialDelaySeconds":30,"periodSeconds":30},"name":"ambassador","readinessProbe":{"httpGet":{"path":"/ambassador/v0/check_ready","port":8877},"initialDelaySeconds":30,"periodSeconds":30},"resources":{"limits":{"cpu":1,"memory":"400Mi"},"requests":{"cpu":"200m","memory":"100Mi"}}},{"image":"quay.io/datawire/statsd:0.37.0","name":"statsd"},{"image":"prom/statsd-exporter:v0.6.0","name":"statsd-sink"}],"restartPolicy":"Always","serviceAccountName":"ambassador"}}}}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        generation: 1,
        labels: {
          app: 'kubeflow-app',
          component: 'ambassador',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'ambassador',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920921',
        selfLink: '/apis/extensions/v1beta1/namespaces/kf-100-user/deployments/ambassador',
        uid: '6ddf20e2-c8af-11e8-83f2-42010a8a0020',
      },
      spec: {
        progressDeadlineSeconds: 600,
        replicas: 3,
        revisionHistoryLimit: 10,
        selector: {
          matchLabels: {
            service: 'ambassador',
          },
        },
        strategy: {
          rollingUpdate: {
            maxSurge: 1,
            maxUnavailable: 1,
          },
          type: 'RollingUpdate',
        },
        template: {
          metadata: {
            creationTimestamp: null,
            labels: {
              service: 'ambassador',
            },
            namespace: 'kf-100-user',
          },
          spec: {
            containers: [
              {
                env: [
                  {
                    name: 'AMBASSADOR_NAMESPACE',
                    valueFrom: {
                      fieldRef: {
                        apiVersion: 'v1',
                        fieldPath: 'metadata.namespace',
                      },
                    },
                  },
                  {
                    name: 'AMBASSADOR_SINGLE_NAMESPACE',
                    value: 'true',
                  },
                ],
                image: 'quay.io/datawire/ambassador:0.37.0',
                imagePullPolicy: 'IfNotPresent',
                livenessProbe: {
                  failureThreshold: 3,
                  httpGet: {
                    path: '/ambassador/v0/check_alive',
                    port: 8877,
                    scheme: 'HTTP',
                  },
                  initialDelaySeconds: 30,
                  periodSeconds: 30,
                  successThreshold: 1,
                  timeoutSeconds: 1,
                },
                name: 'ambassador',
                readinessProbe: {
                  failureThreshold: 3,
                  httpGet: {
                    path: '/ambassador/v0/check_ready',
                    port: 8877,
                    scheme: 'HTTP',
                  },
                  initialDelaySeconds: 30,
                  periodSeconds: 30,
                  successThreshold: 1,
                  timeoutSeconds: 1,
                },
                resources: {
                  limits: {
                    cpu: '1',
                    memory: '400Mi',
                  },
                  requests: {
                    cpu: '200m',
                    memory: '100Mi',
                  },
                },
                terminationMessagePath: '/dev/termination-log',
                terminationMessagePolicy: 'File',
              },
              {
                image: 'quay.io/datawire/statsd:0.37.0',
                imagePullPolicy: 'IfNotPresent',
                name: 'statsd',
                resources: {},
                terminationMessagePath: '/dev/termination-log',
                terminationMessagePolicy: 'File',
              },
              {
                image: 'prom/statsd-exporter:v0.6.0',
                imagePullPolicy: 'IfNotPresent',
                name: 'statsd-sink',
                resources: {},
                terminationMessagePath: '/dev/termination-log',
                terminationMessagePolicy: 'File',
              },
            ],
            dnsPolicy: 'ClusterFirst',
            restartPolicy: 'Always',
            schedulerName: 'default-scheduler',
            securityContext: {},
            serviceAccount: 'ambassador',
            serviceAccountName: 'ambassador',
            terminationGracePeriodSeconds: 30,
          },
        },
      },
      status: {
        availableReplicas: 3,
        conditions: [
          {
            lastTransitionTime: '2018-10-05T15:01:22.000Z',
            lastUpdateTime: '2018-10-05T15:01:22.000Z',
            message: 'Deployment has minimum availability.',
            reason: 'MinimumReplicasAvailable',
            status: 'True',
            type: 'Available',
          },
          {
            lastTransitionTime: '2018-10-05T15:00:42.000Z',
            lastUpdateTime: '2018-10-05T15:01:26.000Z',
            message: 'ReplicaSet "ambassador-6fdbdc6df7" has successfully progressed.',
            reason: 'NewReplicaSetAvailable',
            status: 'True',
            type: 'Progressing',
          },
        ],
        observedGeneration: 1,
        readyReplicas: 3,
        replicas: 3,
        updatedReplicas: 3,
      },
    },
    centraldashboard: {
      apiVersion: 'extensions/v1beta1',
      kind: 'Deployment',
      metadata: {
        annotations: {
          'deployment.kubernetes.io/revision': '1',
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"extensions/v1beta1","kind":"Deployment","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"centraldashboard","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"centraldashboard","namespace":"kf-100-user"},"spec":{"template":{"metadata":{"labels":{"app":"centraldashboard"}},"spec":{"containers":[{"image":"gcr.io/kubeflow-images-public/centraldashboard:v0.3.0","name":"centraldashboard","ports":[{"containerPort":8082}]}],"serviceAccountName":"centraldashboard"}}}}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        generation: 1,
        labels: {
          app: 'kubeflow-app',
          component: 'centraldashboard',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'centraldashboard',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920796',
        selfLink: '/apis/extensions/v1beta1/namespaces/kf-100-user/deployments/centraldashboard',
        uid: '6ddffbbb-c8af-11e8-83f2-42010a8a0020',
      },
      spec: {
        progressDeadlineSeconds: 600,
        replicas: 1,
        revisionHistoryLimit: 10,
        selector: {
          matchLabels: {
            app: 'centraldashboard',
          },
        },
        strategy: {
          rollingUpdate: {
            maxSurge: 1,
            maxUnavailable: 1,
          },
          type: 'RollingUpdate',
        },
        template: {
          metadata: {
            creationTimestamp: null,
            labels: {
              app: 'centraldashboard',
            },
          },
          spec: {
            containers: [
              {
                image: 'gcr.io/kubeflow-images-public/centraldashboard:v0.3.0',
                imagePullPolicy: 'IfNotPresent',
                name: 'centraldashboard',
                ports: [
                  {
                    containerPort: 8082,
                    protocol: 'TCP',
                  },
                ],
                resources: {},
                terminationMessagePath: '/dev/termination-log',
                terminationMessagePolicy: 'File',
              },
            ],
            dnsPolicy: 'ClusterFirst',
            restartPolicy: 'Always',
            schedulerName: 'default-scheduler',
            securityContext: {},
            serviceAccount: 'centraldashboard',
            serviceAccountName: 'centraldashboard',
            terminationGracePeriodSeconds: 30,
          },
        },
      },
      status: {
        availableReplicas: 1,
        conditions: [
          {
            lastTransitionTime: '2018-10-05T15:00:42.000Z',
            lastUpdateTime: '2018-10-05T15:00:42.000Z',
            message: 'Deployment has minimum availability.',
            reason: 'MinimumReplicasAvailable',
            status: 'True',
            type: 'Available',
          },
          {
            lastTransitionTime: '2018-10-05T15:00:42.000Z',
            lastUpdateTime: '2018-10-05T15:00:45.000Z',
            message: 'ReplicaSet "centraldashboard-f8d7d97fb" has successfully progressed.',
            reason: 'NewReplicaSetAvailable',
            status: 'True',
            type: 'Progressing',
          },
        ],
        observedGeneration: 1,
        readyReplicas: 1,
        replicas: 1,
        updatedReplicas: 1,
      },
    },
    'tf-job-dashboard': {
      apiVersion: 'extensions/v1beta1',
      kind: 'Deployment',
      metadata: {
        annotations: {
          'deployment.kubernetes.io/revision': '1',
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"extensions/v1beta1","kind":"Deployment","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"tf-job-dashboard","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"tf-job-dashboard","namespace":"kf-100-user"},"spec":{"template":{"metadata":{"labels":{"name":"tf-job-dashboard"}},"spec":{"containers":[{"command":["/opt/tensorflow_k8s/dashboard/backend"],"env":[{"name":"KUBEFLOW_NAMESPACE","valueFrom":{"fieldRef":{"fieldPath":"metadata.namespace"}}}],"image":"gcr.io/kubeflow-images-public/tf_operator:v0.3.0","name":"tf-job-dashboard","ports":[{"containerPort":8080}]}],"serviceAccountName":"tf-job-dashboard"}}}}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        generation: 1,
        labels: {
          app: 'kubeflow-app',
          component: 'tf-job-dashboard',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'tf-job-dashboard',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920791',
        selfLink: '/apis/extensions/v1beta1/namespaces/kf-100-user/deployments/tf-job-dashboard',
        uid: '6de28b76-c8af-11e8-83f2-42010a8a0020',
      },
      spec: {
        progressDeadlineSeconds: 600,
        replicas: 1,
        revisionHistoryLimit: 10,
        selector: {
          matchLabels: {
            name: 'tf-job-dashboard',
          },
        },
        strategy: {
          rollingUpdate: {
            maxSurge: 1,
            maxUnavailable: 1,
          },
          type: 'RollingUpdate',
        },
        template: {
          metadata: {
            creationTimestamp: null,
            labels: {
              name: 'tf-job-dashboard',
            },
          },
          spec: {
            containers: [
              {
                command: [
                  '/opt/tensorflow_k8s/dashboard/backend',
                ],
                env: [
                  {
                    name: 'KUBEFLOW_NAMESPACE',
                    valueFrom: {
                      fieldRef: {
                        apiVersion: 'v1',
                        fieldPath: 'metadata.namespace',
                      },
                    },
                  },
                ],
                image: 'gcr.io/kubeflow-images-public/tf_operator:v0.3.0',
                imagePullPolicy: 'IfNotPresent',
                name: 'tf-job-dashboard',
                ports: [
                  {
                    containerPort: 8080,
                    protocol: 'TCP',
                  },
                ],
                resources: {},
                terminationMessagePath: '/dev/termination-log',
                terminationMessagePolicy: 'File',
              },
            ],
            dnsPolicy: 'ClusterFirst',
            restartPolicy: 'Always',
            schedulerName: 'default-scheduler',
            securityContext: {},
            serviceAccount: 'tf-job-dashboard',
            serviceAccountName: 'tf-job-dashboard',
            terminationGracePeriodSeconds: 30,
          },
        },
      },
      status: {
        availableReplicas: 1,
        conditions: [
          {
            lastTransitionTime: '2018-10-05T15:00:42.000Z',
            lastUpdateTime: '2018-10-05T15:00:42.000Z',
            message: 'Deployment has minimum availability.',
            reason: 'MinimumReplicasAvailable',
            status: 'True',
            type: 'Available',
          },
          {
            lastTransitionTime: '2018-10-05T15:00:42.000Z',
            lastUpdateTime: '2018-10-05T15:00:45.000Z',
            message: 'ReplicaSet "tf-job-dashboard-7cddcdf9c4" has successfully progressed.',
            reason: 'NewReplicaSetAvailable',
            status: 'True',
            type: 'Progressing',
          },
        ],
        observedGeneration: 1,
        readyReplicas: 1,
        replicas: 1,
        updatedReplicas: 1,
      },
    },
    'tf-job-operator-v1alpha2': {
      apiVersion: 'extensions/v1beta1',
      kind: 'Deployment',
      metadata: {
        annotations: {
          'deployment.kubernetes.io/revision': '1',
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"extensions/v1beta1","kind":"Deployment","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"tf-job-operator-v1alpha2","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"tf-job-operator-v1alpha2","namespace":"kf-100-user"},"spec":{"replicas":1,"template":{"metadata":{"labels":{"name":"tf-job-operator"}},"spec":{"containers":[{"command":["/opt/kubeflow/tf-operator.v2","--alsologtostderr","-v=1","--namespace=kf-100-user"],"env":[{"name":"MY_POD_NAMESPACE","valueFrom":{"fieldRef":{"fieldPath":"metadata.namespace"}}},{"name":"MY_POD_NAME","valueFrom":{"fieldRef":{"fieldPath":"metadata.name"}}},{"name":"KUBEFLOW_NAMESPACE","valueFrom":{"fieldRef":{"fieldPath":"metadata.namespace"}}}],"image":"gcr.io/kubeflow-images-public/tf_operator:v0.3.0","name":"tf-job-operator","volumeMounts":[{"mountPath":"/etc/config","name":"config-volume"}]}],"serviceAccountName":"tf-job-operator","volumes":[{"configMap":{"name":"tf-job-operator-config"},"name":"config-volume"}]}}}}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        generation: 1,
        labels: {
          app: 'kubeflow-app',
          component: 'tf-job-operator-v1alpha2',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'tf-job-operator-v1alpha2',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920785',
        selfLink: '/apis/extensions/v1beta1/namespaces/kf-100-user/deployments/tf-job-operator-v1alpha2',
        uid: '6de0fa97-c8af-11e8-83f2-42010a8a0020',
      },
      spec: {
        progressDeadlineSeconds: 600,
        replicas: 1,
        revisionHistoryLimit: 10,
        selector: {
          matchLabels: {
            name: 'tf-job-operator',
          },
        },
        strategy: {
          rollingUpdate: {
            maxSurge: 1,
            maxUnavailable: 1,
          },
          type: 'RollingUpdate',
        },
        template: {
          metadata: {
            creationTimestamp: null,
            labels: {
              name: 'tf-job-operator',
            },
          },
          spec: {
            containers: [
              {
                command: [
                  '/opt/kubeflow/tf-operator.v2',
                  '--alsologtostderr',
                  '-v=1',
                  '--namespace=kf-100-user',
                ],
                env: [
                  {
                    name: 'MY_POD_NAMESPACE',
                    valueFrom: {
                      fieldRef: {
                        apiVersion: 'v1',
                        fieldPath: 'metadata.namespace',
                      },
                    },
                  },
                  {
                    name: 'MY_POD_NAME',
                    valueFrom: {
                      fieldRef: {
                        apiVersion: 'v1',
                        fieldPath: 'metadata.name',
                      },
                    },
                  },
                  {
                    name: 'KUBEFLOW_NAMESPACE',
                    valueFrom: {
                      fieldRef: {
                        apiVersion: 'v1',
                        fieldPath: 'metadata.namespace',
                      },
                    },
                  },
                ],
                image: 'gcr.io/kubeflow-images-public/tf_operator:v0.3.0',
                imagePullPolicy: 'IfNotPresent',
                name: 'tf-job-operator',
                resources: {},
                terminationMessagePath: '/dev/termination-log',
                terminationMessagePolicy: 'File',
                volumeMounts: [
                  {
                    mountPath: '/etc/config',
                    name: 'config-volume',
                  },
                ],
              },
            ],
            dnsPolicy: 'ClusterFirst',
            restartPolicy: 'Always',
            schedulerName: 'default-scheduler',
            securityContext: {},
            serviceAccount: 'tf-job-operator',
            serviceAccountName: 'tf-job-operator',
            terminationGracePeriodSeconds: 30,
            volumes: [
              {
                configMap: {
                  defaultMode: 420,
                  name: 'tf-job-operator-config',
                },
                name: 'config-volume',
              },
            ],
          },
        },
      },
      status: {
        availableReplicas: 1,
        conditions: [
          {
            lastTransitionTime: '2018-10-05T15:00:42.000Z',
            lastUpdateTime: '2018-10-05T15:00:42.000Z',
            message: 'Deployment has minimum availability.',
            reason: 'MinimumReplicasAvailable',
            status: 'True',
            type: 'Available',
          },
          {
            lastTransitionTime: '2018-10-05T15:00:42.000Z',
            lastUpdateTime: '2018-10-05T15:00:44.000Z',
            message: 'ReplicaSet "tf-job-operator-v1alpha2-7d6bcb8798" has successfully progressed.',
            reason: 'NewReplicaSetAvailable',
            status: 'True',
            type: 'Progressing',
          },
        ],
        observedGeneration: 1,
        readyReplicas: 1,
        replicas: 1,
        updatedReplicas: 1,
      },
    },
  },
  'Role.rbac.authorization.k8s.io/v1beta1': {
    ambassador: {
      apiVersion: 'rbac.authorization.k8s.io/v1beta1',
      kind: 'Role',
      metadata: {
        annotations: {
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"rbac.authorization.k8s.io/v1beta1","kind":"Role","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"ambassador","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"ambassador","namespace":"kf-100-user"},"rules":[{"apiGroups":[""],"resources":["services"],"verbs":["get","list","watch"]},{"apiGroups":[""],"resources":["configmaps"],"verbs":["create","update","patch","get","list","watch"]},{"apiGroups":[""],"resources":["secrets"],"verbs":["get","list","watch"]}]}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'ambassador',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'ambassador',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920691',
        selfLink: '/apis/rbac.authorization.k8s.io/v1beta1/namespaces/kf-100-user/roles/ambassador',
        uid: '6dc6dcf6-c8af-11e8-83f2-42010a8a0020',
      },
      rules: [
        {
          apiGroups: [
            '',
          ],
          resources: [
            'services',
          ],
          verbs: [
            'get',
            'list',
            'watch',
          ],
        },
        {
          apiGroups: [
            '',
          ],
          resources: [
            'configmaps',
          ],
          verbs: [
            'create',
            'update',
            'patch',
            'get',
            'list',
            'watch',
          ],
        },
        {
          apiGroups: [
            '',
          ],
          resources: [
            'secrets',
          ],
          verbs: [
            'get',
            'list',
            'watch',
          ],
        },
      ],
    },
    centraldashboard: {
      apiVersion: 'rbac.authorization.k8s.io/v1beta1',
      kind: 'Role',
      metadata: {
        annotations: {
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"rbac.authorization.k8s.io/v1beta1","kind":"Role","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"centraldashboard","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"centraldashboard","namespace":"kf-100-user"},"rules":[{"apiGroups":[""],"resources":["pods","pods/exec","pods/log"],"verbs":["get","list","watch"]},{"apiGroups":[""],"resources":["secrets"],"verbs":["get"]}]}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'centraldashboard',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'centraldashboard',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920694',
        selfLink: '/apis/rbac.authorization.k8s.io/v1beta1/namespaces/kf-100-user/roles/centraldashboard',
        uid: '6dcb7c49-c8af-11e8-83f2-42010a8a0020',
      },
      rules: [
        {
          apiGroups: [
            '',
          ],
          resources: [
            'pods',
            'pods/exec',
            'pods/log',
          ],
          verbs: [
            'get',
            'list',
            'watch',
          ],
        },
        {
          apiGroups: [
            '',
          ],
          resources: [
            'secrets',
          ],
          verbs: [
            'get',
          ],
        },
      ],
    },
    'jupyter-notebook-role': {
      apiVersion: 'rbac.authorization.k8s.io/v1beta1',
      kind: 'Role',
      metadata: {
        annotations: {
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"rbac.authorization.k8s.io/v1beta1","kind":"Role","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"jupyter-notebook-role","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"jupyter-notebook-role","namespace":"kf-100-user"},"rules":[{"apiGroups":[""],"resources":["pods","services"],"verbs":["*"]},{"apiGroups":["","apps","extensions"],"resources":["deployments","replicasets"],"verbs":["*"]},{"apiGroups":["kubeflow.org"],"resources":["*"],"verbs":["*"]},{"apiGroups":["batch"],"resources":["jobs"],"verbs":["*"]}]}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'jupyter-notebook-role',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'jupyter-notebook-role',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920693',
        selfLink: '/apis/rbac.authorization.k8s.io/v1beta1/namespaces/kf-100-user/roles/jupyter-notebook-role',
        uid: '6dc99573-c8af-11e8-83f2-42010a8a0020',
      },
      rules: [
        {
          apiGroups: [
            '',
          ],
          resources: [
            'pods',
            'services',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            '',
            'apps',
            'extensions',
          ],
          resources: [
            'deployments',
            'replicasets',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            'kubeflow.org',
          ],
          resources: [
            '*',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            'batch',
          ],
          resources: [
            'jobs',
          ],
          verbs: [
            '*',
          ],
        },
      ],
    },
    'jupyter-role': {
      apiVersion: 'rbac.authorization.k8s.io/v1beta1',
      kind: 'Role',
      metadata: {
        annotations: {
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"rbac.authorization.k8s.io/v1beta1","kind":"Role","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"jupyter-role","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"jupyter-role","namespace":"kf-100-user"},"rules":[{"apiGroups":[""],"resources":["pods","persistentvolumeclaims"],"verbs":["get","watch","list","create","delete"]},{"apiGroups":[""],"resources":["events"],"verbs":["get","watch","list"]}]}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'jupyter-role',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'jupyter-role',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920692',
        selfLink: '/apis/rbac.authorization.k8s.io/v1beta1/namespaces/kf-100-user/roles/jupyter-role',
        uid: '6dc862f3-c8af-11e8-83f2-42010a8a0020',
      },
      rules: [
        {
          apiGroups: [
            '',
          ],
          resources: [
            'pods',
            'persistentvolumeclaims',
          ],
          verbs: [
            'get',
            'watch',
            'list',
            'create',
            'delete',
          ],
        },
        {
          apiGroups: [
            '',
          ],
          resources: [
            'events',
          ],
          verbs: [
            'get',
            'watch',
            'list',
          ],
        },
      ],
    },
    'tf-job-dashboard': {
      apiVersion: 'rbac.authorization.k8s.io/v1beta1',
      kind: 'Role',
      metadata: {
        annotations: {
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"rbac.authorization.k8s.io/v1beta1","kind":"Role","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"tf-job-dashboard","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"tf-job-dashboard","namespace":"kf-100-user"},"rules":[{"apiGroups":["tensorflow.org","kubeflow.org"],"resources":["tfjobs"],"verbs":["*"]},{"apiGroups":["apiextensions.k8s.io"],"resources":["customresourcedefinitions"],"verbs":["*"]},{"apiGroups":["storage.k8s.io"],"resources":["storageclasses"],"verbs":["*"]},{"apiGroups":["batch"],"resources":["jobs"],"verbs":["*"]},{"apiGroups":[""],"resources":["configmaps","pods","services","endpoints","persistentvolumeclaims","events","pods/log","namespaces"],"verbs":["*"]},{"apiGroups":["apps","extensions"],"resources":["deployments"],"verbs":["*"]}]}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'tf-job-dashboard',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'tf-job-dashboard',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920697',
        selfLink: '/apis/rbac.authorization.k8s.io/v1beta1/namespaces/kf-100-user/roles/tf-job-dashboard',
        uid: '6dcf552f-c8af-11e8-83f2-42010a8a0020',
      },
      rules: [
        {
          apiGroups: [
            'tensorflow.org',
            'kubeflow.org',
          ],
          resources: [
            'tfjobs',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            'apiextensions.k8s.io',
          ],
          resources: [
            'customresourcedefinitions',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            'storage.k8s.io',
          ],
          resources: [
            'storageclasses',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            'batch',
          ],
          resources: [
            'jobs',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            '',
          ],
          resources: [
            'configmaps',
            'pods',
            'services',
            'endpoints',
            'persistentvolumeclaims',
            'events',
            'pods/log',
            'namespaces',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            'apps',
            'extensions',
          ],
          resources: [
            'deployments',
          ],
          verbs: [
            '*',
          ],
        },
      ],
    },
    'tf-job-operator': {
      apiVersion: 'rbac.authorization.k8s.io/v1beta1',
      kind: 'Role',
      metadata: {
        annotations: {
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"rbac.authorization.k8s.io/v1beta1","kind":"Role","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"tf-job-operator","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"tf-job-operator","namespace":"kf-100-user"},"rules":[{"apiGroups":["tensorflow.org","kubeflow.org"],"resources":["tfjobs"],"verbs":["*"]},{"apiGroups":["apiextensions.k8s.io"],"resources":["customresourcedefinitions"],"verbs":["*"]},{"apiGroups":["storage.k8s.io"],"resources":["storageclasses"],"verbs":["*"]},{"apiGroups":["batch"],"resources":["jobs"],"verbs":["*"]},{"apiGroups":[""],"resources":["configmaps","pods","services","endpoints","persistentvolumeclaims","events"],"verbs":["*"]},{"apiGroups":["apps","extensions"],"resources":["deployments"],"verbs":["*"]}]}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'tf-job-operator',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'tf-job-operator',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920695',
        selfLink: '/apis/rbac.authorization.k8s.io/v1beta1/namespaces/kf-100-user/roles/tf-job-operator',
        uid: '6dcd3fa1-c8af-11e8-83f2-42010a8a0020',
      },
      rules: [
        {
          apiGroups: [
            'tensorflow.org',
            'kubeflow.org',
          ],
          resources: [
            'tfjobs',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            'apiextensions.k8s.io',
          ],
          resources: [
            'customresourcedefinitions',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            'storage.k8s.io',
          ],
          resources: [
            'storageclasses',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            'batch',
          ],
          resources: [
            'jobs',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            '',
          ],
          resources: [
            'configmaps',
            'pods',
            'services',
            'endpoints',
            'persistentvolumeclaims',
            'events',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            'apps',
            'extensions',
          ],
          resources: [
            'deployments',
          ],
          verbs: [
            '*',
          ],
        },
      ],
    },
  },
  'RoleBinding.rbac.authorization.k8s.io/v1beta1': {
    ambassador: {
      apiVersion: 'rbac.authorization.k8s.io/v1beta1',
      kind: 'RoleBinding',
      metadata: {
        annotations: {
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"rbac.authorization.k8s.io/v1beta1","kind":"RoleBinding","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"ambassador","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"ambassador","namespace":"kf-100-user"},"roleRef":{"apiGroup":"rbac.authorization.k8s.io","kind":"Role","name":"ambassador"},"subjects":[{"kind":"ServiceAccount","name":"ambassador","namespace":"kf-100-user"}]}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'ambassador',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'ambassador',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920721',
        selfLink: '/apis/rbac.authorization.k8s.io/v1beta1/namespaces/kf-100-user/rolebindings/ambassador',
        uid: '6dde900c-c8af-11e8-83f2-42010a8a0020',
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'Role',
        name: 'ambassador',
      },
      subjects: [
        {
          kind: 'ServiceAccount',
          name: 'ambassador',
          namespace: 'kf-100-user',
        },
      ],
    },
    centraldashboard: {
      apiVersion: 'rbac.authorization.k8s.io/v1beta1',
      kind: 'RoleBinding',
      metadata: {
        annotations: {
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"rbac.authorization.k8s.io/v1beta1","kind":"RoleBinding","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"centraldashboard","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"centraldashboard","namespace":"kf-100-user"},"roleRef":{"apiGroup":"rbac.authorization.k8s.io","kind":"Role","name":"centraldashboard"},"subjects":[{"kind":"ServiceAccount","name":"centraldashboard","namespace":"kf-100-user"}]}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'centraldashboard',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'centraldashboard',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920717',
        selfLink: '/apis/rbac.authorization.k8s.io/v1beta1/namespaces/kf-100-user/rolebindings/centraldashboard',
        uid: '6ddbc358-c8af-11e8-83f2-42010a8a0020',
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'Role',
        name: 'centraldashboard',
      },
      subjects: [
        {
          kind: 'ServiceAccount',
          name: 'centraldashboard',
          namespace: 'kf-100-user',
        },
      ],
    },
    'jupyter-notebook-role': {
      apiVersion: 'rbac.authorization.k8s.io/v1beta1',
      kind: 'RoleBinding',
      metadata: {
        annotations: {
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"rbac.authorization.k8s.io/v1beta1","kind":"RoleBinding","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"jupyter-notebook-role","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"jupyter-notebook-role","namespace":"kf-100-user"},"roleRef":{"apiGroup":"rbac.authorization.k8s.io","kind":"Role","name":"jupyter-notebook-role"},"subjects":[{"kind":"ServiceAccount","name":"jupyter-notebook","namespace":"kf-100-user"}]}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'jupyter-notebook-role',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'jupyter-notebook-role',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920714',
        selfLink: '/apis/rbac.authorization.k8s.io/v1beta1/namespaces/kf-100-user/rolebindings/jupyter-notebook-role',
        uid: '6dda4960-c8af-11e8-83f2-42010a8a0020',
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'Role',
        name: 'jupyter-notebook-role',
      },
      subjects: [
        {
          kind: 'ServiceAccount',
          name: 'jupyter-notebook',
          namespace: 'kf-100-user',
        },
      ],
    },
    'jupyter-role': {
      apiVersion: 'rbac.authorization.k8s.io/v1beta1',
      kind: 'RoleBinding',
      metadata: {
        annotations: {
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"rbac.authorization.k8s.io/v1beta1","kind":"RoleBinding","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"jupyter-role","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"jupyter-role","namespace":"kf-100-user"},"roleRef":{"apiGroup":"rbac.authorization.k8s.io","kind":"Role","name":"jupyter-role"},"subjects":[{"kind":"ServiceAccount","name":"jupyterhub","namespace":"kf-100-user"}]}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'jupyter-role',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'jupyter-role',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920711',
        selfLink: '/apis/rbac.authorization.k8s.io/v1beta1/namespaces/kf-100-user/rolebindings/jupyter-role',
        uid: '6dd7d73d-c8af-11e8-83f2-42010a8a0020',
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'Role',
        name: 'jupyter-role',
      },
      subjects: [
        {
          kind: 'ServiceAccount',
          name: 'jupyterhub',
          namespace: 'kf-100-user',
        },
      ],
    },
    'tf-job-dashboard': {
      apiVersion: 'rbac.authorization.k8s.io/v1beta1',
      kind: 'RoleBinding',
      metadata: {
        annotations: {
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"rbac.authorization.k8s.io/v1beta1","kind":"RoleBinding","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"tf-job-dashboard","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"tf-job-dashboard","namespace":"kf-100-user"},"roleRef":{"apiGroup":"rbac.authorization.k8s.io","kind":"Role","name":"tf-job-dashboard"},"subjects":[{"kind":"ServiceAccount","name":"tf-job-operator","namespace":"kf-100-user"}]}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'tf-job-dashboard',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'tf-job-dashboard',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920720',
        selfLink: '/apis/rbac.authorization.k8s.io/v1beta1/namespaces/kf-100-user/rolebindings/tf-job-dashboard',
        uid: '6ddddfb0-c8af-11e8-83f2-42010a8a0020',
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'Role',
        name: 'tf-job-dashboard',
      },
      subjects: [
        {
          kind: 'ServiceAccount',
          name: 'tf-job-operator',
          namespace: 'kf-100-user',
        },
      ],
    },
    'tf-job-operator': {
      apiVersion: 'rbac.authorization.k8s.io/v1beta1',
      kind: 'RoleBinding',
      metadata: {
        annotations: {
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"rbac.authorization.k8s.io/v1beta1","kind":"RoleBinding","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"tf-job-operator","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"tf-job-operator","namespace":"kf-100-user"},"roleRef":{"apiGroup":"rbac.authorization.k8s.io","kind":"Role","name":"tf-job-operator"},"subjects":[{"kind":"ServiceAccount","name":"tf-job-operator","namespace":"kf-100-user"}]}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'tf-job-operator',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'tf-job-operator',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920719',
        selfLink: '/apis/rbac.authorization.k8s.io/v1beta1/namespaces/kf-100-user/rolebindings/tf-job-operator',
        uid: '6ddd46f0-c8af-11e8-83f2-42010a8a0020',
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'Role',
        name: 'tf-job-operator',
      },
      subjects: [
        {
          kind: 'ServiceAccount',
          name: 'tf-job-operator',
          namespace: 'kf-100-user',
        },
      ],
    },
  },
  'Service.v1': {
    ambassador: {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        annotations: {
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"v1","kind":"Service","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"ambassador","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020","service":"ambassador"},"name":"ambassador","namespace":"kf-100-user"},"spec":{"ports":[{"name":"ambassador","port":80,"targetPort":80}],"selector":{"service":"ambassador"},"type":"LoadBalancer"}}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'ambassador',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
          service: 'ambassador',
        },
        name: 'ambassador',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920954',
        selfLink: '/api/v1/namespaces/kf-100-user/services/ambassador',
        uid: '6dc4d307-c8af-11e8-83f2-42010a8a0020',
      },
      spec: {
        clusterIP: '10.67.254.79',
        externalTrafficPolicy: 'Cluster',
        ports: [
          {
            name: 'ambassador',
            nodePort: 30181,
            port: 80,
            protocol: 'TCP',
            targetPort: 80,
          },
        ],
        selector: {
          service: 'ambassador',
        },
        sessionAffinity: 'None',
        type: 'LoadBalancer',
      },
      status: {
        loadBalancer: {
          ingress: [
            {
              ip: '35.230.18.188',
            },
          ],
        },
      },
    },
    'ambassador-admin': {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        annotations: {
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"v1","kind":"Service","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"ambassador-admin","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020","service":"ambassador-admin"},"name":"ambassador-admin","namespace":"kf-100-user"},"spec":{"ports":[{"name":"ambassador-admin","port":8877,"targetPort":8877}],"selector":{"service":"ambassador"},"type":"ClusterIP"}}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'ambassador-admin',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
          service: 'ambassador-admin',
        },
        name: 'ambassador-admin',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920670',
        selfLink: '/api/v1/namespaces/kf-100-user/services/ambassador-admin',
        uid: '6dbbf5d4-c8af-11e8-83f2-42010a8a0020',
      },
      spec: {
        clusterIP: '10.67.255.150',
        ports: [
          {
            name: 'ambassador-admin',
            port: 8877,
            protocol: 'TCP',
            targetPort: 8877,
          },
        ],
        selector: {
          service: 'ambassador',
        },
        sessionAffinity: 'None',
        type: 'ClusterIP',
      },
      status: {
        loadBalancer: {},
      },
    },
    centraldashboard: {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        annotations: {
          'getambassador.io/config': '---\napiVersion: ambassador/v0\nkind:  Mapping\nname: centralui-mapping\nprefix: /\nrewrite: /\nservice: centraldashboard.kf-100-user',
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"v1","kind":"Service","metadata":{"annotations":{"getambassador.io/config":"---\\napiVersion: ambassador/v0\\nkind:  Mapping\\nname: centralui-mapping\\nprefix: /\\nrewrite: /\\nservice: centraldashboard.kf-100-user","kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"centraldashboard","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"centraldashboard","namespace":"kf-100-user"},"spec":{"ports":[{"port":80,"targetPort":8082}],"selector":{"app":"centraldashboard"},"sessionAffinity":"None","type":"ClusterIP"}}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'centraldashboard',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'centraldashboard',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920682',
        selfLink: '/api/v1/namespaces/kf-100-user/services/centraldashboard',
        uid: '6dc1b554-c8af-11e8-83f2-42010a8a0020',
      },
      spec: {
        clusterIP: '10.67.243.99',
        ports: [
          {
            port: 80,
            protocol: 'TCP',
            targetPort: 8082,
          },
        ],
        selector: {
          app: 'centraldashboard',
        },
        sessionAffinity: 'None',
        type: 'ClusterIP',
      },
      status: {
        loadBalancer: {},
      },
    },
    'jupyterhub-0': {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        annotations: {
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"v1","kind":"Service","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app","prometheus.io/scrape":"true"},"labels":{"app":"kubeflow-app","component":"jupyterhub-0","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"jupyterhub-0","namespace":"kf-100-user"},"spec":{"clusterIP":"None","ports":[{"name":"hub","port":8000}],"selector":{"app":"jupyterhub"}}}',
          'prometheus.io/scrape': 'true',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'jupyterhub-0',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'jupyterhub-0',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920676',
        selfLink: '/api/v1/namespaces/kf-100-user/services/jupyterhub-0',
        uid: '6dbf1f27-c8af-11e8-83f2-42010a8a0020',
      },
      spec: {
        clusterIP: 'None',
        ports: [
          {
            name: 'hub',
            port: 8000,
            protocol: 'TCP',
            targetPort: 8000,
          },
        ],
        selector: {
          app: 'jupyterhub',
        },
        sessionAffinity: 'None',
        type: 'ClusterIP',
      },
      status: {
        loadBalancer: {},
      },
    },
    'jupyterhub-lb': {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        annotations: {
          'getambassador.io/config': '---\napiVersion: ambassador/v0\nkind:  Mapping\nname: jupyterhub-lb-hub-mapping\nprefix: /hub/\nrewrite: /hub/\ntimeout_ms: 300000\nservice: jupyterhub-lb.kf-100-user\nuse_websocket: true\n---\napiVersion: ambassador/v0\nkind:  Mapping\nname: jupyterhub-lb-user-mapping\nprefix: /user/\nrewrite: /user/\ntimeout_ms: 300000\nservice: jupyterhub-lb.kf-100-user\nuse_websocket: true',
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"v1","kind":"Service","metadata":{"annotations":{"getambassador.io/config":"---\\napiVersion: ambassador/v0\\nkind:  Mapping\\nname: jupyterhub-lb-hub-mapping\\nprefix: /hub/\\nrewrite: /hub/\\ntimeout_ms: 300000\\nservice: jupyterhub-lb.kf-100-user\\nuse_websocket: true\\n---\\napiVersion: ambassador/v0\\nkind:  Mapping\\nname: jupyterhub-lb-user-mapping\\nprefix: /user/\\nrewrite: /user/\\ntimeout_ms: 300000\\nservice: jupyterhub-lb.kf-100-user\\nuse_websocket: true","kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"jupyterhub-lb","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"jupyterhub-lb","namespace":"kf-100-user"},"spec":{"ports":[{"name":"hub","port":80,"targetPort":8000}],"selector":{"app":"jupyterhub"},"type":"ClusterIP"}}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'jupyterhub-lb',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'jupyterhub-lb',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920679',
        selfLink: '/api/v1/namespaces/kf-100-user/services/jupyterhub-lb',
        uid: '6dc09288-c8af-11e8-83f2-42010a8a0020',
      },
      spec: {
        clusterIP: '10.67.244.202',
        ports: [
          {
            name: 'hub',
            port: 80,
            protocol: 'TCP',
            targetPort: 8000,
          },
        ],
        selector: {
          app: 'jupyterhub',
        },
        sessionAffinity: 'None',
        type: 'ClusterIP',
      },
      status: {
        loadBalancer: {},
      },
    },
    'k8s-dashboard': {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        annotations: {
          'getambassador.io/config': '---\napiVersion: ambassador/v0\nkind:  Mapping\nname: k8s-dashboard-ui-mapping\nprefix: /k8s/ui/\nrewrite: /\ntls: true\nservice: kubernetes-dashboard.kube-system',
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"v1","kind":"Service","metadata":{"annotations":{"getambassador.io/config":"---\\napiVersion: ambassador/v0\\nkind:  Mapping\\nname: k8s-dashboard-ui-mapping\\nprefix: /k8s/ui/\\nrewrite: /\\ntls: true\\nservice: kubernetes-dashboard.kube-system","kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"k8s-dashboard","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"k8s-dashboard","namespace":"kf-100-user"},"spec":{"ports":[{"port":443,"targetPort":8443}],"selector":{"k8s-app":"kubernetes-dashboard"},"type":"ClusterIP"}}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'k8s-dashboard',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'k8s-dashboard',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920674',
        selfLink: '/api/v1/namespaces/kf-100-user/services/k8s-dashboard',
        uid: '6dbe162a-c8af-11e8-83f2-42010a8a0020',
      },
      spec: {
        clusterIP: '10.67.248.173',
        ports: [
          {
            port: 443,
            protocol: 'TCP',
            targetPort: 8443,
          },
        ],
        selector: {
          'k8s-app': 'kubernetes-dashboard',
        },
        sessionAffinity: 'None',
        type: 'ClusterIP',
      },
      status: {
        loadBalancer: {},
      },
    },
    'statsd-sink': {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        annotations: {
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"v1","kind":"Service","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app","prometheus.io/port":"9102","prometheus.io/scrape":"true"},"labels":{"app":"kubeflow-app","component":"statsd-sink","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020","service":"ambassador"},"name":"statsd-sink","namespace":"kf-100-user"},"spec":{"ports":[{"name":"statsd-sink","port":9102,"protocol":"TCP","targetPort":9102}],"selector":{"service":"ambassador"},"type":"ClusterIP"}}',
          'prometheus.io/port': '9102',
          'prometheus.io/scrape': 'true',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'statsd-sink',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
          service: 'ambassador',
        },
        name: 'statsd-sink',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920668',
        selfLink: '/api/v1/namespaces/kf-100-user/services/statsd-sink',
        uid: '6dba3240-c8af-11e8-83f2-42010a8a0020',
      },
      spec: {
        clusterIP: '10.67.243.37',
        ports: [
          {
            name: 'statsd-sink',
            port: 9102,
            protocol: 'TCP',
            targetPort: 9102,
          },
        ],
        selector: {
          service: 'ambassador',
        },
        sessionAffinity: 'None',
        type: 'ClusterIP',
      },
      status: {
        loadBalancer: {},
      },
    },
    'tf-job-dashboard': {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        annotations: {
          'getambassador.io/config': '---\napiVersion: ambassador/v0\nkind:  Mapping\nname: tfjobs-ui-mapping\nprefix: /tfjobs/\nrewrite: /tfjobs/\nservice: tf-job-dashboard.kf-100-user',
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"v1","kind":"Service","metadata":{"annotations":{"getambassador.io/config":"---\\napiVersion: ambassador/v0\\nkind:  Mapping\\nname: tfjobs-ui-mapping\\nprefix: /tfjobs/\\nrewrite: /tfjobs/\\nservice: tf-job-dashboard.kf-100-user","kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"tf-job-dashboard","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"tf-job-dashboard","namespace":"kf-100-user"},"spec":{"ports":[{"port":80,"targetPort":8080}],"selector":{"name":"tf-job-dashboard"},"type":"ClusterIP"}}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'tf-job-dashboard',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'tf-job-dashboard',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920685',
        selfLink: '/api/v1/namespaces/kf-100-user/services/tf-job-dashboard',
        uid: '6dc2a516-c8af-11e8-83f2-42010a8a0020',
      },
      spec: {
        clusterIP: '10.67.242.216',
        ports: [
          {
            port: 80,
            protocol: 'TCP',
            targetPort: 8080,
          },
        ],
        selector: {
          name: 'tf-job-dashboard',
        },
        sessionAffinity: 'None',
        type: 'ClusterIP',
      },
      status: {
        loadBalancer: {},
      },
    },
  },
  'ServiceAccount.v1': {
    ambassador: {
      apiVersion: 'v1',
      kind: 'ServiceAccount',
      metadata: {
        annotations: {
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"v1","kind":"ServiceAccount","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"ambassador","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"ambassador","namespace":"kf-100-user"}}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'ambassador',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'ambassador',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920707',
        selfLink: '/api/v1/namespaces/kf-100-user/serviceaccounts/ambassador',
        uid: '6dd11ba5-c8af-11e8-83f2-42010a8a0020',
      },
      secrets: [
        {
          name: 'ambassador-token-mlsp8',
        },
      ],
    },
    centraldashboard: {
      apiVersion: 'v1',
      kind: 'ServiceAccount',
      metadata: {
        annotations: {
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"v1","kind":"ServiceAccount","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"centraldashboard","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"centraldashboard","namespace":"kf-100-user"}}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'centraldashboard',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'centraldashboard',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920716',
        selfLink: '/api/v1/namespaces/kf-100-user/serviceaccounts/centraldashboard',
        uid: '6dd535a2-c8af-11e8-83f2-42010a8a0020',
      },
      secrets: [
        {
          name: 'centraldashboard-token-2dkb6',
        },
      ],
    },
    'jupyter-notebook': {
      apiVersion: 'v1',
      kind: 'ServiceAccount',
      metadata: {
        annotations: {
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"v1","kind":"ServiceAccount","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"jupyter-notebook","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"jupyter-notebook","namespace":"kf-100-user"}}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'jupyter-notebook',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'jupyter-notebook',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920713',
        selfLink: '/api/v1/namespaces/kf-100-user/serviceaccounts/jupyter-notebook',
        uid: '6dd33cf6-c8af-11e8-83f2-42010a8a0020',
      },
      secrets: [
        {
          name: 'jupyter-notebook-token-2npgr',
        },
      ],
    },
    jupyterhub: {
      apiVersion: 'v1',
      kind: 'ServiceAccount',
      metadata: {
        annotations: {
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"v1","kind":"ServiceAccount","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"jupyterhub","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"jupyterhub","namespace":"kf-100-user"}}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'jupyterhub',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'jupyterhub',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920708',
        selfLink: '/api/v1/namespaces/kf-100-user/serviceaccounts/jupyterhub',
        uid: '6dd1f257-c8af-11e8-83f2-42010a8a0020',
      },
      secrets: [
        {
          name: 'jupyterhub-token-72zjb',
        },
      ],
    },
    'tf-job-dashboard': {
      apiVersion: 'v1',
      kind: 'ServiceAccount',
      metadata: {
        annotations: {
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"v1","kind":"ServiceAccount","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"tf-job-dashboard","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"tf-job-dashboard","namespace":"kf-100-user"}}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'tf-job-dashboard',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'tf-job-dashboard',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920703',
        selfLink: '/api/v1/namespaces/kf-100-user/serviceaccounts/tf-job-dashboard',
        uid: '6dd05a1a-c8af-11e8-83f2-42010a8a0020',
      },
      secrets: [
        {
          name: 'tf-job-dashboard-token-rjc87',
        },
      ],
    },
    'tf-job-operator': {
      apiVersion: 'v1',
      kind: 'ServiceAccount',
      metadata: {
        annotations: {
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"v1","kind":"ServiceAccount","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"tf-job-operator","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"tf-job-operator","namespace":"kf-100-user"}}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        labels: {
          app: 'kubeflow-app',
          component: 'tf-job-operator',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'tf-job-operator',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920718',
        selfLink: '/api/v1/namespaces/kf-100-user/serviceaccounts/tf-job-operator',
        uid: '6dd70ff0-c8af-11e8-83f2-42010a8a0020',
      },
      secrets: [
        {
          name: 'tf-job-operator-token-h4tk2',
        },
      ],
    },
  },
  'StatefulSet.apps/v1beta1': {
    jupyterhub: {
      apiVersion: 'apps/v1beta1',
      kind: 'StatefulSet',
      metadata: {
        annotations: {
          'kubernetes.io/application': 'kubeflow-app',
          'metacontroller.k8s.io/last-applied-configuration': '{"apiVersion":"apps/v1beta1","kind":"StatefulSet","metadata":{"annotations":{"kubernetes.io/application":"kubeflow-app"},"labels":{"app":"kubeflow-app","component":"jupyterhub","controller-uid":"677a0dba-c8af-11e8-83f2-42010a8a0020"},"name":"jupyterhub","namespace":"kf-100-user"},"spec":{"replicas":1,"serviceName":"","template":{"metadata":{"labels":{"app":"jupyterhub"}},"spec":{"containers":[{"command":["jupyterhub","-f","/etc/config/jupyterhub_config.py"],"env":[{"name":"NOTEBOOK_PVC_MOUNT","value":"/home/jovyan"},{"name":"CLOUD_NAME","value":"null"},{"name":"REGISTRY","value":"gcr.io"},{"name":"REPO_NAME","value":"kubeflow-images-public"},{"name":"KF_AUTHENTICATOR","value":"null"},{"name":"DEFAULT_JUPYTERLAB","value":"false"},{"name":"KF_PVC_LIST","value":"null"}],"image":"gcr.io/kubeflow/jupyterhub-k8s:v20180531-3bb991b1","name":"jupyterhub","ports":[{"containerPort":8000},{"containerPort":8081}],"volumeMounts":[{"mountPath":"/etc/config","name":"config-volume"}]}],"serviceAccountName":"jupyterhub","volumes":[{"configMap":{"name":"jupyterhub-config"},"name":"config-volume"}]}},"updateStrategy":{"type":"RollingUpdate"}}}',
        },
        creationTimestamp: '2018-10-05T15:00:42.000Z',
        generation: 1,
        labels: {
          app: 'kubeflow-app',
          component: 'jupyterhub',
          'controller-uid': '677a0dba-c8af-11e8-83f2-42010a8a0020',
        },
        name: 'jupyterhub',
        namespace: 'kf-100-user',
        ownerReferences: [
          {
            apiVersion: 'app.k8s.io/v1beta1',
            blockOwnerDeletion: true,
            controller: true,
            kind: 'Application',
            name: 'kubeflow-app',
            uid: '677a0dba-c8af-11e8-83f2-42010a8a0020',
          },
        ],
        resourceVersion: '1920799',
        selfLink: '/apis/apps/v1beta1/namespaces/kf-100-user/statefulsets/jupyterhub',
        uid: '6dec9044-c8af-11e8-83f2-42010a8a0020',
      },
      spec: {
        podManagementPolicy: 'OrderedReady',
        replicas: 1,
        revisionHistoryLimit: 10,
        selector: {
          matchLabels: {
            app: 'jupyterhub',
          },
        },
        serviceName: '',
        template: {
          metadata: {
            creationTimestamp: null,
            labels: {
              app: 'jupyterhub',
            },
          },
          spec: {
            containers: [
              {
                command: [
                  'jupyterhub',
                  '-f',
                  '/etc/config/jupyterhub_config.py',
                ],
                env: [
                  {
                    name: 'NOTEBOOK_PVC_MOUNT',
                    value: '/home/jovyan',
                  },
                  {
                    name: 'CLOUD_NAME',
                    value: 'null',
                  },
                  {
                    name: 'REGISTRY',
                    value: 'gcr.io',
                  },
                  {
                    name: 'REPO_NAME',
                    value: 'kubeflow-images-public',
                  },
                  {
                    name: 'KF_AUTHENTICATOR',
                    value: 'null',
                  },
                  {
                    name: 'DEFAULT_JUPYTERLAB',
                    value: 'false',
                  },
                  {
                    name: 'KF_PVC_LIST',
                    value: 'null',
                  },
                ],
                image: 'gcr.io/kubeflow/jupyterhub-k8s:v20180531-3bb991b1',
                imagePullPolicy: 'IfNotPresent',
                name: 'jupyterhub',
                ports: [
                  {
                    containerPort: 8000,
                    protocol: 'TCP',
                  },
                  {
                    containerPort: 8081,
                    protocol: 'TCP',
                  },
                ],
                resources: {},
                terminationMessagePath: '/dev/termination-log',
                terminationMessagePolicy: 'File',
                volumeMounts: [
                  {
                    mountPath: '/etc/config',
                    name: 'config-volume',
                  },
                ],
              },
            ],
            dnsPolicy: 'ClusterFirst',
            restartPolicy: 'Always',
            schedulerName: 'default-scheduler',
            securityContext: {},
            serviceAccount: 'jupyterhub',
            serviceAccountName: 'jupyterhub',
            terminationGracePeriodSeconds: 30,
            volumes: [
              {
                configMap: {
                  defaultMode: 420,
                  name: 'jupyterhub-config',
                },
                name: 'config-volume',
              },
            ],
          },
        },
        updateStrategy: {
          type: 'RollingUpdate',
        },
      },
      status: {
        collisionCount: 0,
        currentReplicas: 1,
        currentRevision: 'jupyterhub-78bccb8bb4',
        observedGeneration: 1,
        readyReplicas: 1,
        replicas: 1,
        updateRevision: 'jupyterhub-78bccb8bb4',
      },
    },
  },
},
  },
  process(request)::  {
          local util = import "kubeflow/core/util.libsonnet",
          local resources = 
{
  'ConfigMap.v1': {
    'jupyterhub-config': {
      apiVersion: 'v1',
      data: {
        'jupyterhub_config.py': "import json\nimport os\nimport string\nimport escapism\nfrom kubespawner.spawner import KubeSpawner\nfrom jhub_remote_user_authenticator.remote_user_auth import RemoteUserAuthenticator\nfrom oauthenticator.github import GitHubOAuthenticator\n\nSERVICE_ACCOUNT_SECRET_MOUNT = '/var/run/secrets/sa'\n\nclass KubeFormSpawner(KubeSpawner):\n\n    # relies on HTML5 for image datalist\n    def _options_form_default(self):\n        global registry, repoName\n        return '''\n\n    <table style=\"width: 100%;\">\n    <tr>\n        <td style=\"width: 30%;\"><label for='image'>Image</label></td>\n        <td style=\"width: 70%;\"><input value=\"\" list=\"image\" name=\"image\" placeholder='repo/image:tag' style=\"width: 100%;\">\n        <datalist id=\"image\">\n          <option value=\"{0}/{1}/tensorflow-1.4.1-notebook-cpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.4.1-notebook-gpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.5.1-notebook-cpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.5.1-notebook-gpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.6.0-notebook-cpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.6.0-notebook-gpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.7.0-notebook-cpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.7.0-notebook-gpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.8.0-notebook-cpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.8.0-notebook-gpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.9.0-notebook-cpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.9.0-notebook-gpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.10.1-notebook-cpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.10.1-notebook-gpu:v0.3.0\">\n        </datalist>\n        </td>\n    </tr>\n    </table>\n    <div style=\"text-align: center; padding: 10px;\">\n      <a id=\"toggle_advanced_options\" style=\"margin: 20%; cursor: pointer; font-weight: bold;\">Advanced</a>\n    </div>\n    <table id=\"advanced_fields\" style=\"display: none; width: 100%; border-spacing: 0px 25px; border-collapse: separate;\">\n    <tr>\n        <td><label for='cpu_guarantee'>CPU</label></td>\n        <td><input style=\"width: 100%;\" name='cpu_guarantee' placeholder='200m, 1.0, 2.5, etc'></input></td>\n    </tr>\n    <tr>\n        <td><label for='mem_guarantee'>Memory</label></td>\n        <td><input style=\"width: 100%;\" name='mem_guarantee' placeholder='100Mi, 1.5Gi'></input></td>\n    </tr>\n    <tr>\n        <td><label for='extra_resource_limits'>Extra Resource Limits</label></td>\n        <td><input style=\"width: 100%;\" name='extra_resource_limits' placeholder='{{&quot;nvidia.com/gpu&quot;: 3}}'></input></td>\n    </tr>\n    </table>\n\n    <script type=\"text/javascript\">\n      $('#toggle_advanced_options').on('click', function(e){{\n        $('#advanced_fields').toggle();\n      }});\n    </script>\n\n\n        '''.format(registry, repoName)\n\n    def options_from_form(self, formdata):\n        options = {}\n        options['image'] = formdata.get('image', [''])[0].strip()\n        options['cpu_guarantee'] = formdata.get(\n            'cpu_guarantee', [''])[0].strip()\n        options['mem_guarantee'] = formdata.get(\n            'mem_guarantee', [''])[0].strip()\n        options['extra_resource_limits'] = formdata.get(\n            'extra_resource_limits', [''])[0].strip()\n        return options\n\n    @property\n    def singleuser_image_spec(self):\n        global cloud\n        if cloud == 'ack':\n            image = 'registry.aliyuncs.com/kubeflow-images-public/tensorflow-notebook-cpu:v0.2.1'\n        else:\n            image = 'gcr.io/kubeflow-images-public/tensorflow-1.8.0-notebook-cpu:v0.3.0'\n        if self.user_options.get('image'):\n            image = self.user_options['image']\n        return image\n\n    image_spec = singleuser_image_spec\n\n    @property\n    def cpu_guarantee(self):\n        cpu = '500m'\n        if self.user_options.get('cpu_guarantee'):\n            cpu = self.user_options['cpu_guarantee']\n        return cpu\n\n    @property\n    def mem_guarantee(self):\n        mem = '1Gi'\n        if self.user_options.get('mem_guarantee'):\n            mem = self.user_options['mem_guarantee']\n        return mem\n\n    @property\n    def extra_resource_limits(self):\n        extra = ''\n        if self.user_options.get('extra_resource_limits'):\n            extra = json.loads(self.user_options['extra_resource_limits'])\n        return extra\n\n    def get_env(self):\n        env = super(KubeFormSpawner, self).get_env()\n        gcp_secret_name = os.environ.get('GCP_SECRET_NAME')\n        if gcp_secret_name:\n            env['GOOGLE_APPLICATION_CREDENTIALS'] = '{}/{}.json'.format(SERVICE_ACCOUNT_SECRET_MOUNT, gcp_secret_name)\n        return env\n\n    # TODO(kkasravi): add unit test\n    def _parse_user_name(self, username):\n        safe_chars = set(string.ascii_lowercase + string.digits)\n        name = username.split(':')[-1]\n        legacy = ''.join([s if s in safe_chars else '-' for s in name.lower()])\n        safe = escapism.escape(name, safe=safe_chars, escape_char='-').lower()\n        return legacy, safe, name\n\n    def _expand_user_properties(self, template):\n        # override KubeSpawner method to remove prefix accounts.google: for iap\n        # and truncate to 63 characters\n\n        # Set servername based on whether named-server initialised\n        if self.name:\n            servername = '-{}'.format(self.name)\n        else:\n            servername = ''\n\n        legacy, safe, name = self._parse_user_name(self.user.name)\n        rname = template.format(\n            userid=self.user.id,\n            username=safe,\n            unescaped_username=name,\n            legacy_escape_username=legacy,\n            servername=servername\n            )[:63]\n        return rname\n\n\n###################################################\n# JupyterHub Options\n###################################################\nc.JupyterHub.ip = '0.0.0.0'\nc.JupyterHub.hub_ip = '0.0.0.0'\n# Don't try to cleanup servers on exit - since in general for k8s, we want\n# the hub to be able to restart without losing user containers\nc.JupyterHub.cleanup_servers = False\n###################################################\n\n###################################################\n# Spawner Options\n###################################################\ncloud = os.environ.get('CLOUD_NAME')\nregistry = os.environ.get('REGISTRY')\nrepoName = os.environ.get('REPO_NAME')\nc.JupyterHub.spawner_class = KubeFormSpawner\n# Set both singleuser_image_spec and image_spec because\n# singleuser_image_spec has been deprecated in a future release\nc.KubeSpawner.singleuser_image_spec = '{0}/{1}/tensorflow-notebook'.format(registry, repoName)\nc.KubeSpawner.image_spec = '{0}/{1}/tensorflow-notebook'.format(registry, repoName)\n\nc.KubeSpawner.cmd = 'start-singleuser.sh'\nc.KubeSpawner.args = ['--allow-root']\n# gpu images are very large ~15GB. need a large timeout.\nc.KubeSpawner.start_timeout = 60 * 30\n# Increase timeout to 5 minutes to avoid HTTP 500 errors on JupyterHub\nc.KubeSpawner.http_timeout = 60 * 5\n\n# Volume setup\nc.KubeSpawner.singleuser_uid = 1000\nc.KubeSpawner.singleuser_fs_gid = 100\nc.KubeSpawner.singleuser_working_dir = '/home/jovyan'\nvolumes = []\nvolume_mounts = []\n\n# Allow environment vars to override uid and gid.\n# This allows local host path mounts to be read/writable\nenv_uid = os.environ.get('NOTEBOOK_UID')\nif env_uid:\n    c.KubeSpawner.singleuser_uid = int(env_uid)\nenv_gid = os.environ.get('NOTEBOOK_GID')\nif env_gid:\n    c.KubeSpawner.singleuser_fs_gid = int(env_gid)\naccess_local_fs = os.environ.get('ACCESS_LOCAL_FS')\nif access_local_fs == 'true':\n    def modify_pod_hook(spawner, pod):\n       pod.spec.containers[0].lifecycle = {\n            'postStart' : {\n               'exec' : {\n                   'command' : ['ln', '-s', '/mnt/local-notebooks', '/home/jovyan/local-notebooks' ]\n               }\n            }\n        }\n       return pod\n    c.KubeSpawner.modify_pod_hook = modify_pod_hook\n\n###################################################\n# Persistent volume options\n###################################################\n# Using persistent storage requires a default storage class.\n# TODO(jlewi): Verify this works on minikube.\n# see https://github.com/kubeflow/kubeflow/pull/22#issuecomment-350500944\npvc_mount = os.environ.get('NOTEBOOK_PVC_MOUNT')\nif pvc_mount and pvc_mount != 'null':\n    c.KubeSpawner.user_storage_pvc_ensure = True\n    c.KubeSpawner.storage_pvc_ensure = True\n    # How much disk space do we want?\n    c.KubeSpawner.user_storage_capacity = '10Gi'\n    c.KubeSpawner.storage_capacity = '10Gi'\n    c.KubeSpawner.pvc_name_template = 'claim-{username}{servername}'\n    volumes.append(\n        {\n            'name': 'volume-{username}{servername}',\n            'persistentVolumeClaim': {\n                'claimName': 'claim-{username}{servername}'\n            }\n        }\n    )\n    volume_mounts.append(\n        {\n            'mountPath': pvc_mount,\n            'name': 'volume-{username}{servername}'\n        }\n    )\n\nc.KubeSpawner.volumes = volumes\nc.KubeSpawner.volume_mounts = volume_mounts\n# Set both service_account and singleuser_service_account because\n# singleuser_service_account has been deprecated in a future release\nc.KubeSpawner.service_account = 'jupyter-notebook'\nc.KubeSpawner.singleuser_service_account = 'jupyter-notebook'\n# Authenticator\nif os.environ.get('KF_AUTHENTICATOR') == 'iap':\n    c.JupyterHub.authenticator_class ='jhub_remote_user_authenticator.remote_user_auth.RemoteUserAuthenticator'\n    c.RemoteUserAuthenticator.header_name = 'x-goog-authenticated-user-email'\nelse:\n    c.JupyterHub.authenticator_class = 'dummyauthenticator.DummyAuthenticator'\n\nif os.environ.get('DEFAULT_JUPYTERLAB').lower() == 'true':\n    c.KubeSpawner.default_url = '/lab'\n\n# PVCs\npvcs = os.environ.get('KF_PVC_LIST')\nif pvcs and pvcs != 'null':\n    for pvc in pvcs.split(','):\n        volumes.append({\n            'name': pvc,\n            'persistentVolumeClaim': {\n                'claimName': pvc\n            }\n        })\n        volume_mounts.append({\n            'name': pvc,\n            'mountPath': '/mnt/' + pvc\n        })\n\ngcp_secret_name = os.environ.get('GCP_SECRET_NAME')\nif gcp_secret_name:\n    volumes.append({\n      'name': gcp_secret_name,\n      'secret': {\n        'secretName': gcp_secret_name,\n      }\n    })\n    volume_mounts.append({\n        'name': gcp_secret_name,\n        'mountPath': SERVICE_ACCOUNT_SECRET_MOUNT\n    })\n",
      },
      kind: 'ConfigMap',
      metadata: {
        name: 'jupyterhub-config',
        namespace: 'kf-100-user',
      },
    },
    'tf-job-operator-config': {
      apiVersion: 'v1',
      data: {
        'controller_config_file.yaml': '{\n    "grpcServerFilePath": "/opt/mlkube/grpc_tensorflow_server/grpc_tensorflow_server.py"\n}',
      },
      kind: 'ConfigMap',
      metadata: {
        name: 'tf-job-operator-config',
        namespace: 'kf-100-user',
      },
    },
  },
  'CustomResourceDefinition.apiextensions.k8s.io/v1beta1': {
    'tfjobs.kubeflow.org': {
      apiVersion: 'apiextensions.k8s.io/v1beta1',
      kind: 'CustomResourceDefinition',
      metadata: {
        name: 'tfjobs.kubeflow.org',
      },
      spec: {
        group: 'kubeflow.org',
        names: {
          kind: 'TFJob',
          plural: 'tfjobs',
          singular: 'tfjob',
        },
        scope: 'Namespaced',
        validation: {
          openAPIV3Schema: {
            properties: {
              spec: {
                properties: {
                  tfReplicaSpecs: {
                    properties: {
                      Chief: {
                        properties: {
                          replicas: {
                            maximum: 1,
                            minimum: 1,
                            type: 'integer',
                          },
                        },
                      },
                      PS: {
                        properties: {
                          replicas: {
                            minimum: 1,
                            type: 'integer',
                          },
                        },
                      },
                      Worker: {
                        properties: {
                          replicas: {
                            minimum: 1,
                            type: 'integer',
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
        version: 'v1alpha2',
      },
    },
  },
  'Deployment.extensions/v1beta1': {
    ambassador: {
      apiVersion: 'extensions/v1beta1',
      kind: 'Deployment',
      metadata: {
        name: 'ambassador',
        namespace: 'kf-100-user',
      },
      spec: {
        replicas: 3,
        template: {
          metadata: {
            labels: {
              service: 'ambassador',
            },
            namespace: 'kf-100-user',
          },
          spec: {
            containers: [
              {
                env: [
                  {
                    name: 'AMBASSADOR_NAMESPACE',
                    valueFrom: {
                      fieldRef: {
                        fieldPath: 'metadata.namespace',
                      },
                    },
                  },
                  {
                    name: 'AMBASSADOR_SINGLE_NAMESPACE',
                    value: 'true',
                  },
                ],
                image: 'quay.io/datawire/ambassador:0.37.0',
                livenessProbe: {
                  httpGet: {
                    path: '/ambassador/v0/check_alive',
                    port: 8877,
                  },
                  initialDelaySeconds: 30,
                  periodSeconds: 30,
                },
                name: 'ambassador',
                readinessProbe: {
                  httpGet: {
                    path: '/ambassador/v0/check_ready',
                    port: 8877,
                  },
                  initialDelaySeconds: 30,
                  periodSeconds: 30,
                },
                resources: {
                  limits: {
                    cpu: 1,
                    memory: '400Mi',
                  },
                  requests: {
                    cpu: '200m',
                    memory: '100Mi',
                  },
                },
              },
              {
                image: 'quay.io/datawire/statsd:0.37.0',
                name: 'statsd',
              },
              {
                image: 'prom/statsd-exporter:v0.6.0',
                name: 'statsd-sink',
              },
            ],
            restartPolicy: 'Always',
            serviceAccountName: 'ambassador',
          },
        },
      },
    },
    centraldashboard: {
      apiVersion: 'extensions/v1beta1',
      kind: 'Deployment',
      metadata: {
        labels: {
          app: 'centraldashboard',
        },
        name: 'centraldashboard',
        namespace: 'kf-100-user',
      },
      spec: {
        template: {
          metadata: {
            labels: {
              app: 'centraldashboard',
            },
          },
          spec: {
            containers: [
              {
                image: 'gcr.io/kubeflow-images-public/centraldashboard:v0.3.0',
                name: 'centraldashboard',
                ports: [
                  {
                    containerPort: 8082,
                  },
                ],
              },
            ],
            serviceAccountName: 'centraldashboard',
          },
        },
      },
    },
    'tf-job-dashboard': {
      apiVersion: 'extensions/v1beta1',
      kind: 'Deployment',
      metadata: {
        name: 'tf-job-dashboard',
        namespace: 'kf-100-user',
      },
      spec: {
        template: {
          metadata: {
            labels: {
              name: 'tf-job-dashboard',
            },
          },
          spec: {
            containers: [
              {
                command: [
                  '/opt/tensorflow_k8s/dashboard/backend',
                ],
                env: [
                  {
                    name: 'KUBEFLOW_NAMESPACE',
                    valueFrom: {
                      fieldRef: {
                        fieldPath: 'metadata.namespace',
                      },
                    },
                  },
                ],
                image: 'gcr.io/kubeflow-images-public/tf_operator:v0.3.0',
                name: 'tf-job-dashboard',
                ports: [
                  {
                    containerPort: 8080,
                  },
                ],
              },
            ],
            serviceAccountName: 'tf-job-dashboard',
          },
        },
      },
    },
    'tf-job-operator-v1alpha2': {
      apiVersion: 'extensions/v1beta1',
      kind: 'Deployment',
      metadata: {
        name: 'tf-job-operator-v1alpha2',
        namespace: 'kf-100-user',
      },
      spec: {
        replicas: 1,
        template: {
          metadata: {
            labels: {
              name: 'tf-job-operator',
            },
          },
          spec: {
            containers: [
              {
                command: [
                  '/opt/kubeflow/tf-operator.v2',
                  '--alsologtostderr',
                  '-v=1',
                  '--namespace=kf-100-user',
                ],
                env: [
                  {
                    name: 'MY_POD_NAMESPACE',
                    valueFrom: {
                      fieldRef: {
                        fieldPath: 'metadata.namespace',
                      },
                    },
                  },
                  {
                    name: 'MY_POD_NAME',
                    valueFrom: {
                      fieldRef: {
                        fieldPath: 'metadata.name',
                      },
                    },
                  },
                  {
                    name: 'KUBEFLOW_NAMESPACE',
                    valueFrom: {
                      fieldRef: {
                        fieldPath: 'metadata.namespace',
                      },
                    },
                  },
                ],
                image: 'gcr.io/kubeflow-images-public/tf_operator:v0.3.0',
                name: 'tf-job-operator',
                volumeMounts: [
                  {
                    mountPath: '/etc/config',
                    name: 'config-volume',
                  },
                ],
              },
            ],
            serviceAccountName: 'tf-job-operator',
            volumes: [
              {
                configMap: {
                  name: 'tf-job-operator-config',
                },
                name: 'config-volume',
              },
            ],
          },
        },
      },
    },
  },
  'Role.rbac.authorization.k8s.io/v1beta1': {
    ambassador: {
      apiVersion: 'rbac.authorization.k8s.io/v1beta1',
      kind: 'Role',
      metadata: {
        name: 'ambassador',
        namespace: 'kf-100-user',
      },
      rules: [
        {
          apiGroups: [
            '',
          ],
          resources: [
            'services',
          ],
          verbs: [
            'get',
            'list',
            'watch',
          ],
        },
        {
          apiGroups: [
            '',
          ],
          resources: [
            'configmaps',
          ],
          verbs: [
            'create',
            'update',
            'patch',
            'get',
            'list',
            'watch',
          ],
        },
        {
          apiGroups: [
            '',
          ],
          resources: [
            'secrets',
          ],
          verbs: [
            'get',
            'list',
            'watch',
          ],
        },
      ],
    },
    centraldashboard: {
      apiVersion: 'rbac.authorization.k8s.io/v1beta1',
      kind: 'Role',
      metadata: {
        labels: {
          app: 'centraldashboard',
        },
        name: 'centraldashboard',
        namespace: 'kf-100-user',
      },
      rules: [
        {
          apiGroups: [
            '',
          ],
          resources: [
            'pods',
            'pods/exec',
            'pods/log',
          ],
          verbs: [
            'get',
            'list',
            'watch',
          ],
        },
        {
          apiGroups: [
            '',
          ],
          resources: [
            'secrets',
          ],
          verbs: [
            'get',
          ],
        },
      ],
    },
    'jupyter-notebook-role': {
      apiVersion: 'rbac.authorization.k8s.io/v1beta1',
      kind: 'Role',
      metadata: {
        name: 'jupyter-notebook-role',
        namespace: 'kf-100-user',
      },
      rules: [
        {
          apiGroups: [
            '',
          ],
          resources: [
            'pods',
            'services',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            '',
            'apps',
            'extensions',
          ],
          resources: [
            'deployments',
            'replicasets',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            'kubeflow.org',
          ],
          resources: [
            '*',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            'batch',
          ],
          resources: [
            'jobs',
          ],
          verbs: [
            '*',
          ],
        },
      ],
    },
    'jupyter-role': {
      apiVersion: 'rbac.authorization.k8s.io/v1beta1',
      kind: 'Role',
      metadata: {
        name: 'jupyter-role',
        namespace: 'kf-100-user',
      },
      rules: [
        {
          apiGroups: [
            '',
          ],
          resources: [
            'pods',
            'persistentvolumeclaims',
          ],
          verbs: [
            'get',
            'watch',
            'list',
            'create',
            'delete',
          ],
        },
        {
          apiGroups: [
            '',
          ],
          resources: [
            'events',
          ],
          verbs: [
            'get',
            'watch',
            'list',
          ],
        },
      ],
    },
    'tf-job-dashboard': {
      apiVersion: 'rbac.authorization.k8s.io/v1beta1',
      kind: 'Role',
      metadata: {
        labels: {
          app: 'tf-job-dashboard',
        },
        name: 'tf-job-dashboard',
        namespace: 'kf-100-user',
      },
      rules: [
        {
          apiGroups: [
            'tensorflow.org',
            'kubeflow.org',
          ],
          resources: [
            'tfjobs',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            'apiextensions.k8s.io',
          ],
          resources: [
            'customresourcedefinitions',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            'storage.k8s.io',
          ],
          resources: [
            'storageclasses',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            'batch',
          ],
          resources: [
            'jobs',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            '',
          ],
          resources: [
            'configmaps',
            'pods',
            'services',
            'endpoints',
            'persistentvolumeclaims',
            'events',
            'pods/log',
            'namespaces',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            'apps',
            'extensions',
          ],
          resources: [
            'deployments',
          ],
          verbs: [
            '*',
          ],
        },
      ],
    },
    'tf-job-operator': {
      apiVersion: 'rbac.authorization.k8s.io/v1beta1',
      kind: 'Role',
      metadata: {
        labels: {
          app: 'tf-job-operator',
        },
        name: 'tf-job-operator',
        namespace: 'kf-100-user',
      },
      rules: [
        {
          apiGroups: [
            'tensorflow.org',
            'kubeflow.org',
          ],
          resources: [
            'tfjobs',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            'apiextensions.k8s.io',
          ],
          resources: [
            'customresourcedefinitions',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            'storage.k8s.io',
          ],
          resources: [
            'storageclasses',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            'batch',
          ],
          resources: [
            'jobs',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            '',
          ],
          resources: [
            'configmaps',
            'pods',
            'services',
            'endpoints',
            'persistentvolumeclaims',
            'events',
          ],
          verbs: [
            '*',
          ],
        },
        {
          apiGroups: [
            'apps',
            'extensions',
          ],
          resources: [
            'deployments',
          ],
          verbs: [
            '*',
          ],
        },
      ],
    },
  },
  'RoleBinding.rbac.authorization.k8s.io/v1beta1': {
    ambassador: {
      apiVersion: 'rbac.authorization.k8s.io/v1beta1',
      kind: 'RoleBinding',
      metadata: {
        name: 'ambassador',
        namespace: 'kf-100-user',
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'Role',
        name: 'ambassador',
      },
      subjects: [
        {
          kind: 'ServiceAccount',
          name: 'ambassador',
          namespace: 'kf-100-user',
        },
      ],
    },
    centraldashboard: {
      apiVersion: 'rbac.authorization.k8s.io/v1beta1',
      kind: 'RoleBinding',
      metadata: {
        labels: {
          app: 'centraldashboard',
        },
        name: 'centraldashboard',
        namespace: 'kf-100-user',
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'Role',
        name: 'centraldashboard',
      },
      subjects: [
        {
          kind: 'ServiceAccount',
          name: 'centraldashboard',
          namespace: 'kf-100-user',
        },
      ],
    },
    'jupyter-notebook-role': {
      apiVersion: 'rbac.authorization.k8s.io/v1beta1',
      kind: 'RoleBinding',
      metadata: {
        name: 'jupyter-notebook-role',
        namespace: 'kf-100-user',
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'Role',
        name: 'jupyter-notebook-role',
      },
      subjects: [
        {
          kind: 'ServiceAccount',
          name: 'jupyter-notebook',
          namespace: 'kf-100-user',
        },
      ],
    },
    'jupyter-role': {
      apiVersion: 'rbac.authorization.k8s.io/v1beta1',
      kind: 'RoleBinding',
      metadata: {
        name: 'jupyter-role',
        namespace: 'kf-100-user',
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'Role',
        name: 'jupyter-role',
      },
      subjects: [
        {
          kind: 'ServiceAccount',
          name: 'jupyterhub',
          namespace: 'kf-100-user',
        },
      ],
    },
    'tf-job-dashboard': {
      apiVersion: 'rbac.authorization.k8s.io/v1beta1',
      kind: 'RoleBinding',
      metadata: {
        labels: {
          app: 'tf-job-dashboard',
        },
        name: 'tf-job-dashboard',
        namespace: 'kf-100-user',
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'Role',
        name: 'tf-job-dashboard',
      },
      subjects: [
        {
          kind: 'ServiceAccount',
          name: 'tf-job-operator',
          namespace: 'kf-100-user',
        },
      ],
    },
    'tf-job-operator': {
      apiVersion: 'rbac.authorization.k8s.io/v1beta1',
      kind: 'RoleBinding',
      metadata: {
        labels: {
          app: 'tf-job-operator',
        },
        name: 'tf-job-operator',
        namespace: 'kf-100-user',
      },
      roleRef: {
        apiGroup: 'rbac.authorization.k8s.io',
        kind: 'Role',
        name: 'tf-job-operator',
      },
      subjects: [
        {
          kind: 'ServiceAccount',
          name: 'tf-job-operator',
          namespace: 'kf-100-user',
        },
      ],
    },
  },
  'Service.v1': {
    ambassador: {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        labels: {
          service: 'ambassador',
        },
        name: 'ambassador',
        namespace: 'kf-100-user',
      },
      spec: {
        ports: [
          {
            name: 'ambassador',
            port: 80,
            targetPort: 80,
          },
        ],
        selector: {
          service: 'ambassador',
        },
        type: 'LoadBalancer',
      },
    },
    'ambassador-admin': {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        labels: {
          service: 'ambassador-admin',
        },
        name: 'ambassador-admin',
        namespace: 'kf-100-user',
      },
      spec: {
        ports: [
          {
            name: 'ambassador-admin',
            port: 8877,
            targetPort: 8877,
          },
        ],
        selector: {
          service: 'ambassador',
        },
        type: 'ClusterIP',
      },
    },
    centraldashboard: {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        annotations: {
          'getambassador.io/config': '---\napiVersion: ambassador/v0\nkind:  Mapping\nname: centralui-mapping\nprefix: /\nrewrite: /\nservice: centraldashboard.kf-100-user',
        },
        labels: {
          app: 'centraldashboard',
        },
        name: 'centraldashboard',
        namespace: 'kf-100-user',
      },
      spec: {
        ports: [
          {
            port: 80,
            targetPort: 8082,
          },
        ],
        selector: {
          app: 'centraldashboard',
        },
        sessionAffinity: 'None',
        type: 'ClusterIP',
      },
    },
    'jupyterhub-0': {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        annotations: {
          'prometheus.io/scrape': 'true',
        },
        labels: {
          app: 'jupyterhub',
        },
        name: 'jupyterhub-0',
        namespace: 'kf-100-user',
      },
      spec: {
        clusterIP: 'None',
        ports: [
          {
            name: 'hub',
            port: 8000,
          },
        ],
        selector: {
          app: 'jupyterhub',
        },
      },
    },
    'jupyterhub-lb': {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        annotations: {
          'getambassador.io/config': '---\napiVersion: ambassador/v0\nkind:  Mapping\nname: jupyterhub-lb-hub-mapping\nprefix: /hub/\nrewrite: /hub/\ntimeout_ms: 300000\nservice: jupyterhub-lb.kf-100-user\nuse_websocket: true\n---\napiVersion: ambassador/v0\nkind:  Mapping\nname: jupyterhub-lb-user-mapping\nprefix: /user/\nrewrite: /user/\ntimeout_ms: 300000\nservice: jupyterhub-lb.kf-100-user\nuse_websocket: true',
        },
        labels: {
          app: 'jupyterhub-lb',
        },
        name: 'jupyterhub-lb',
        namespace: 'kf-100-user',
      },
      spec: {
        ports: [
          {
            name: 'hub',
            port: 80,
            targetPort: 8000,
          },
        ],
        selector: {
          app: 'jupyterhub',
        },
        type: 'ClusterIP',
      },
    },
    'k8s-dashboard': {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        annotations: {
          'getambassador.io/config': '---\napiVersion: ambassador/v0\nkind:  Mapping\nname: k8s-dashboard-ui-mapping\nprefix: /k8s/ui/\nrewrite: /\ntls: true\nservice: kubernetes-dashboard.kube-system',
        },
        name: 'k8s-dashboard',
        namespace: 'kf-100-user',
      },
      spec: {
        ports: [
          {
            port: 443,
            targetPort: 8443,
          },
        ],
        selector: {
          'k8s-app': 'kubernetes-dashboard',
        },
        type: 'ClusterIP',
      },
    },
    'statsd-sink': {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        annotations: {
          'prometheus.io/port': '9102',
          'prometheus.io/scrape': 'true',
        },
        labels: {
          service: 'ambassador',
        },
        name: 'statsd-sink',
        namespace: 'kf-100-user',
      },
      spec: {
        ports: [
          {
            name: 'statsd-sink',
            port: 9102,
            protocol: 'TCP',
            targetPort: 9102,
          },
        ],
        selector: {
          service: 'ambassador',
        },
        type: 'ClusterIP',
      },
    },
    'tf-job-dashboard': {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        annotations: {
          'getambassador.io/config': '---\napiVersion: ambassador/v0\nkind:  Mapping\nname: tfjobs-ui-mapping\nprefix: /tfjobs/\nrewrite: /tfjobs/\nservice: tf-job-dashboard.kf-100-user',
        },
        name: 'tf-job-dashboard',
        namespace: 'kf-100-user',
      },
      spec: {
        ports: [
          {
            port: 80,
            targetPort: 8080,
          },
        ],
        selector: {
          name: 'tf-job-dashboard',
        },
        type: 'ClusterIP',
      },
    },
  },
  'ServiceAccount.v1': {
    ambassador: {
      apiVersion: 'v1',
      kind: 'ServiceAccount',
      metadata: {
        name: 'ambassador',
        namespace: 'kf-100-user',
      },
    },
    centraldashboard: {
      apiVersion: 'v1',
      kind: 'ServiceAccount',
      metadata: {
        name: 'centraldashboard',
        namespace: 'kf-100-user',
      },
    },
    'jupyter-notebook': {
      apiVersion: 'v1',
      kind: 'ServiceAccount',
      metadata: {
        name: 'jupyter-notebook',
        namespace: 'kf-100-user',
      },
    },
    jupyterhub: {
      apiVersion: 'v1',
      kind: 'ServiceAccount',
      metadata: {
        labels: {
          app: 'jupyterhub',
        },
        name: 'jupyterhub',
        namespace: 'kf-100-user',
      },
    },
    'tf-job-dashboard': {
      apiVersion: 'v1',
      kind: 'ServiceAccount',
      metadata: {
        labels: {
          app: 'tf-job-dashboard',
        },
        name: 'tf-job-dashboard',
        namespace: 'kf-100-user',
      },
    },
    'tf-job-operator': {
      apiVersion: 'v1',
      kind: 'ServiceAccount',
      metadata: {
        labels: {
          app: 'tf-job-operator',
        },
        name: 'tf-job-operator',
        namespace: 'kf-100-user',
      },
    },
  },
  'StatefulSet.apps/v1beta1': {
    jupyterhub: {
      apiVersion: 'apps/v1beta1',
      kind: 'StatefulSet',
      metadata: {
        name: 'jupyterhub',
        namespace: 'kf-100-user',
      },
      spec: {
        replicas: 1,
        serviceName: '',
        template: {
          metadata: {
            labels: {
              app: 'jupyterhub',
            },
          },
          spec: {
            containers: [
              {
                command: [
                  'jupyterhub',
                  '-f',
                  '/etc/config/jupyterhub_config.py',
                ],
                env: [
                  {
                    name: 'NOTEBOOK_PVC_MOUNT',
                    value: '/home/jovyan',
                  },
                  {
                    name: 'CLOUD_NAME',
                    value: 'null',
                  },
                  {
                    name: 'REGISTRY',
                    value: 'gcr.io',
                  },
                  {
                    name: 'REPO_NAME',
                    value: 'kubeflow-images-public',
                  },
                  {
                    name: 'KF_AUTHENTICATOR',
                    value: 'null',
                  },
                  {
                    name: 'DEFAULT_JUPYTERLAB',
                    value: 'false',
                  },
                  {
                    name: 'KF_PVC_LIST',
                    value: 'null',
                  },
                ],
                image: 'gcr.io/kubeflow/jupyterhub-k8s:v20180531-3bb991b1',
                name: 'jupyterhub',
                ports: [
                  {
                    containerPort: 8000,
                  },
                  {
                    containerPort: 8081,
                  },
                ],
                volumeMounts: [
                  {
                    mountPath: '/etc/config',
                    name: 'config-volume',
                  },
                ],
              },
            ],
            serviceAccountName: 'jupyterhub',
            volumes: [
              {
                configMap: {
                  name: 'jupyterhub-config',
                },
                name: 'config-volume',
              },
            ],
          },
        },
        updateStrategy: {
          type: 'RollingUpdate',
        },
      },
    },
  },
},
          local components = 
[
  {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'ambassador',
        service: 'ambassador',
      },
      name: 'ambassador',
      namespace: 'kf-100-user',
    },
    spec: {
      ports: [
        {
          name: 'ambassador',
          port: 80,
          targetPort: 80,
        },
      ],
      selector: {
        service: 'ambassador',
      },
      type: 'LoadBalancer',
    },
  },
  {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
        'prometheus.io/port': '9102',
        'prometheus.io/scrape': 'true',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'statsd-sink',
        service: 'ambassador',
      },
      name: 'statsd-sink',
      namespace: 'kf-100-user',
    },
    spec: {
      ports: [
        {
          name: 'statsd-sink',
          port: 9102,
          protocol: 'TCP',
          targetPort: 9102,
        },
      ],
      selector: {
        service: 'ambassador',
      },
      type: 'ClusterIP',
    },
  },
  {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'ambassador-admin',
        service: 'ambassador-admin',
      },
      name: 'ambassador-admin',
      namespace: 'kf-100-user',
    },
    spec: {
      ports: [
        {
          name: 'ambassador-admin',
          port: 8877,
          targetPort: 8877,
        },
      ],
      selector: {
        service: 'ambassador',
      },
      type: 'ClusterIP',
    },
  },
  {
    apiVersion: 'rbac.authorization.k8s.io/v1beta1',
    kind: 'Role',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'ambassador',
      },
      name: 'ambassador',
      namespace: 'kf-100-user',
    },
    rules: [
      {
        apiGroups: [
          '',
        ],
        resources: [
          'services',
        ],
        verbs: [
          'get',
          'list',
          'watch',
        ],
      },
      {
        apiGroups: [
          '',
        ],
        resources: [
          'configmaps',
        ],
        verbs: [
          'create',
          'update',
          'patch',
          'get',
          'list',
          'watch',
        ],
      },
      {
        apiGroups: [
          '',
        ],
        resources: [
          'secrets',
        ],
        verbs: [
          'get',
          'list',
          'watch',
        ],
      },
    ],
  },
  {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'ambassador',
      },
      name: 'ambassador',
      namespace: 'kf-100-user',
    },
  },
  {
    apiVersion: 'rbac.authorization.k8s.io/v1beta1',
    kind: 'RoleBinding',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'ambassador',
      },
      name: 'ambassador',
      namespace: 'kf-100-user',
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'Role',
      name: 'ambassador',
    },
    subjects: [
      {
        kind: 'ServiceAccount',
        name: 'ambassador',
        namespace: 'kf-100-user',
      },
    ],
  },
  {
    apiVersion: 'extensions/v1beta1',
    kind: 'Deployment',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'ambassador',
      },
      name: 'ambassador',
      namespace: 'kf-100-user',
    },
    spec: {
      replicas: 3,
      template: {
        metadata: {
          labels: {
            service: 'ambassador',
          },
          namespace: 'kf-100-user',
        },
        spec: {
          containers: [
            {
              env: [
                {
                  name: 'AMBASSADOR_NAMESPACE',
                  valueFrom: {
                    fieldRef: {
                      fieldPath: 'metadata.namespace',
                    },
                  },
                },
                {
                  name: 'AMBASSADOR_SINGLE_NAMESPACE',
                  value: 'true',
                },
              ],
              image: 'quay.io/datawire/ambassador:0.37.0',
              livenessProbe: {
                httpGet: {
                  path: '/ambassador/v0/check_alive',
                  port: 8877,
                },
                initialDelaySeconds: 30,
                periodSeconds: 30,
              },
              name: 'ambassador',
              readinessProbe: {
                httpGet: {
                  path: '/ambassador/v0/check_ready',
                  port: 8877,
                },
                initialDelaySeconds: 30,
                periodSeconds: 30,
              },
              resources: {
                limits: {
                  cpu: 1,
                  memory: '400Mi',
                },
                requests: {
                  cpu: '200m',
                  memory: '100Mi',
                },
              },
            },
            {
              image: 'quay.io/datawire/statsd:0.37.0',
              name: 'statsd',
            },
            {
              image: 'prom/statsd-exporter:v0.6.0',
              name: 'statsd-sink',
            },
          ],
          restartPolicy: 'Always',
          serviceAccountName: 'ambassador',
        },
      },
    },
  },
  {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      annotations: {
        'getambassador.io/config': '---\napiVersion: ambassador/v0\nkind:  Mapping\nname: k8s-dashboard-ui-mapping\nprefix: /k8s/ui/\nrewrite: /\ntls: true\nservice: kubernetes-dashboard.kube-system',
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'k8s-dashboard',
      },
      name: 'k8s-dashboard',
      namespace: 'kf-100-user',
    },
    spec: {
      ports: [
        {
          port: 443,
          targetPort: 8443,
        },
      ],
      selector: {
        'k8s-app': 'kubernetes-dashboard',
      },
      type: 'ClusterIP',
    },
  },
  {
    apiVersion: 'v1',
    data: {
      'jupyterhub_config.py': "import json\nimport os\nimport string\nimport escapism\nfrom kubespawner.spawner import KubeSpawner\nfrom jhub_remote_user_authenticator.remote_user_auth import RemoteUserAuthenticator\nfrom oauthenticator.github import GitHubOAuthenticator\n\nSERVICE_ACCOUNT_SECRET_MOUNT = '/var/run/secrets/sa'\n\nclass KubeFormSpawner(KubeSpawner):\n\n    # relies on HTML5 for image datalist\n    def _options_form_default(self):\n        global registry, repoName\n        return '''\n\n    <table style=\"width: 100%;\">\n    <tr>\n        <td style=\"width: 30%;\"><label for='image'>Image</label></td>\n        <td style=\"width: 70%;\"><input value=\"\" list=\"image\" name=\"image\" placeholder='repo/image:tag' style=\"width: 100%;\">\n        <datalist id=\"image\">\n          <option value=\"{0}/{1}/tensorflow-1.4.1-notebook-cpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.4.1-notebook-gpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.5.1-notebook-cpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.5.1-notebook-gpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.6.0-notebook-cpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.6.0-notebook-gpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.7.0-notebook-cpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.7.0-notebook-gpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.8.0-notebook-cpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.8.0-notebook-gpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.9.0-notebook-cpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.9.0-notebook-gpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.10.1-notebook-cpu:v0.3.0\">\n          <option value=\"{0}/{1}/tensorflow-1.10.1-notebook-gpu:v0.3.0\">\n        </datalist>\n        </td>\n    </tr>\n    </table>\n    <div style=\"text-align: center; padding: 10px;\">\n      <a id=\"toggle_advanced_options\" style=\"margin: 20%; cursor: pointer; font-weight: bold;\">Advanced</a>\n    </div>\n    <table id=\"advanced_fields\" style=\"display: none; width: 100%; border-spacing: 0px 25px; border-collapse: separate;\">\n    <tr>\n        <td><label for='cpu_guarantee'>CPU</label></td>\n        <td><input style=\"width: 100%;\" name='cpu_guarantee' placeholder='200m, 1.0, 2.5, etc'></input></td>\n    </tr>\n    <tr>\n        <td><label for='mem_guarantee'>Memory</label></td>\n        <td><input style=\"width: 100%;\" name='mem_guarantee' placeholder='100Mi, 1.5Gi'></input></td>\n    </tr>\n    <tr>\n        <td><label for='extra_resource_limits'>Extra Resource Limits</label></td>\n        <td><input style=\"width: 100%;\" name='extra_resource_limits' placeholder='{{&quot;nvidia.com/gpu&quot;: 3}}'></input></td>\n    </tr>\n    </table>\n\n    <script type=\"text/javascript\">\n      $('#toggle_advanced_options').on('click', function(e){{\n        $('#advanced_fields').toggle();\n      }});\n    </script>\n\n\n        '''.format(registry, repoName)\n\n    def options_from_form(self, formdata):\n        options = {}\n        options['image'] = formdata.get('image', [''])[0].strip()\n        options['cpu_guarantee'] = formdata.get(\n            'cpu_guarantee', [''])[0].strip()\n        options['mem_guarantee'] = formdata.get(\n            'mem_guarantee', [''])[0].strip()\n        options['extra_resource_limits'] = formdata.get(\n            'extra_resource_limits', [''])[0].strip()\n        return options\n\n    @property\n    def singleuser_image_spec(self):\n        global cloud\n        if cloud == 'ack':\n            image = 'registry.aliyuncs.com/kubeflow-images-public/tensorflow-notebook-cpu:v0.2.1'\n        else:\n            image = 'gcr.io/kubeflow-images-public/tensorflow-1.8.0-notebook-cpu:v0.3.0'\n        if self.user_options.get('image'):\n            image = self.user_options['image']\n        return image\n\n    image_spec = singleuser_image_spec\n\n    @property\n    def cpu_guarantee(self):\n        cpu = '500m'\n        if self.user_options.get('cpu_guarantee'):\n            cpu = self.user_options['cpu_guarantee']\n        return cpu\n\n    @property\n    def mem_guarantee(self):\n        mem = '1Gi'\n        if self.user_options.get('mem_guarantee'):\n            mem = self.user_options['mem_guarantee']\n        return mem\n\n    @property\n    def extra_resource_limits(self):\n        extra = ''\n        if self.user_options.get('extra_resource_limits'):\n            extra = json.loads(self.user_options['extra_resource_limits'])\n        return extra\n\n    def get_env(self):\n        env = super(KubeFormSpawner, self).get_env()\n        gcp_secret_name = os.environ.get('GCP_SECRET_NAME')\n        if gcp_secret_name:\n            env['GOOGLE_APPLICATION_CREDENTIALS'] = '{}/{}.json'.format(SERVICE_ACCOUNT_SECRET_MOUNT, gcp_secret_name)\n        return env\n\n    # TODO(kkasravi): add unit test\n    def _parse_user_name(self, username):\n        safe_chars = set(string.ascii_lowercase + string.digits)\n        name = username.split(':')[-1]\n        legacy = ''.join([s if s in safe_chars else '-' for s in name.lower()])\n        safe = escapism.escape(name, safe=safe_chars, escape_char='-').lower()\n        return legacy, safe, name\n\n    def _expand_user_properties(self, template):\n        # override KubeSpawner method to remove prefix accounts.google: for iap\n        # and truncate to 63 characters\n\n        # Set servername based on whether named-server initialised\n        if self.name:\n            servername = '-{}'.format(self.name)\n        else:\n            servername = ''\n\n        legacy, safe, name = self._parse_user_name(self.user.name)\n        rname = template.format(\n            userid=self.user.id,\n            username=safe,\n            unescaped_username=name,\n            legacy_escape_username=legacy,\n            servername=servername\n            )[:63]\n        return rname\n\n\n###################################################\n# JupyterHub Options\n###################################################\nc.JupyterHub.ip = '0.0.0.0'\nc.JupyterHub.hub_ip = '0.0.0.0'\n# Don't try to cleanup servers on exit - since in general for k8s, we want\n# the hub to be able to restart without losing user containers\nc.JupyterHub.cleanup_servers = False\n###################################################\n\n###################################################\n# Spawner Options\n###################################################\ncloud = os.environ.get('CLOUD_NAME')\nregistry = os.environ.get('REGISTRY')\nrepoName = os.environ.get('REPO_NAME')\nc.JupyterHub.spawner_class = KubeFormSpawner\n# Set both singleuser_image_spec and image_spec because\n# singleuser_image_spec has been deprecated in a future release\nc.KubeSpawner.singleuser_image_spec = '{0}/{1}/tensorflow-notebook'.format(registry, repoName)\nc.KubeSpawner.image_spec = '{0}/{1}/tensorflow-notebook'.format(registry, repoName)\n\nc.KubeSpawner.cmd = 'start-singleuser.sh'\nc.KubeSpawner.args = ['--allow-root']\n# gpu images are very large ~15GB. need a large timeout.\nc.KubeSpawner.start_timeout = 60 * 30\n# Increase timeout to 5 minutes to avoid HTTP 500 errors on JupyterHub\nc.KubeSpawner.http_timeout = 60 * 5\n\n# Volume setup\nc.KubeSpawner.singleuser_uid = 1000\nc.KubeSpawner.singleuser_fs_gid = 100\nc.KubeSpawner.singleuser_working_dir = '/home/jovyan'\nvolumes = []\nvolume_mounts = []\n\n# Allow environment vars to override uid and gid.\n# This allows local host path mounts to be read/writable\nenv_uid = os.environ.get('NOTEBOOK_UID')\nif env_uid:\n    c.KubeSpawner.singleuser_uid = int(env_uid)\nenv_gid = os.environ.get('NOTEBOOK_GID')\nif env_gid:\n    c.KubeSpawner.singleuser_fs_gid = int(env_gid)\naccess_local_fs = os.environ.get('ACCESS_LOCAL_FS')\nif access_local_fs == 'true':\n    def modify_pod_hook(spawner, pod):\n       pod.spec.containers[0].lifecycle = {\n            'postStart' : {\n               'exec' : {\n                   'command' : ['ln', '-s', '/mnt/local-notebooks', '/home/jovyan/local-notebooks' ]\n               }\n            }\n        }\n       return pod\n    c.KubeSpawner.modify_pod_hook = modify_pod_hook\n\n###################################################\n# Persistent volume options\n###################################################\n# Using persistent storage requires a default storage class.\n# TODO(jlewi): Verify this works on minikube.\n# see https://github.com/kubeflow/kubeflow/pull/22#issuecomment-350500944\npvc_mount = os.environ.get('NOTEBOOK_PVC_MOUNT')\nif pvc_mount and pvc_mount != 'null':\n    c.KubeSpawner.user_storage_pvc_ensure = True\n    c.KubeSpawner.storage_pvc_ensure = True\n    # How much disk space do we want?\n    c.KubeSpawner.user_storage_capacity = '10Gi'\n    c.KubeSpawner.storage_capacity = '10Gi'\n    c.KubeSpawner.pvc_name_template = 'claim-{username}{servername}'\n    volumes.append(\n        {\n            'name': 'volume-{username}{servername}',\n            'persistentVolumeClaim': {\n                'claimName': 'claim-{username}{servername}'\n            }\n        }\n    )\n    volume_mounts.append(\n        {\n            'mountPath': pvc_mount,\n            'name': 'volume-{username}{servername}'\n        }\n    )\n\nc.KubeSpawner.volumes = volumes\nc.KubeSpawner.volume_mounts = volume_mounts\n# Set both service_account and singleuser_service_account because\n# singleuser_service_account has been deprecated in a future release\nc.KubeSpawner.service_account = 'jupyter-notebook'\nc.KubeSpawner.singleuser_service_account = 'jupyter-notebook'\n# Authenticator\nif os.environ.get('KF_AUTHENTICATOR') == 'iap':\n    c.JupyterHub.authenticator_class ='jhub_remote_user_authenticator.remote_user_auth.RemoteUserAuthenticator'\n    c.RemoteUserAuthenticator.header_name = 'x-goog-authenticated-user-email'\nelse:\n    c.JupyterHub.authenticator_class = 'dummyauthenticator.DummyAuthenticator'\n\nif os.environ.get('DEFAULT_JUPYTERLAB').lower() == 'true':\n    c.KubeSpawner.default_url = '/lab'\n\n# PVCs\npvcs = os.environ.get('KF_PVC_LIST')\nif pvcs and pvcs != 'null':\n    for pvc in pvcs.split(','):\n        volumes.append({\n            'name': pvc,\n            'persistentVolumeClaim': {\n                'claimName': pvc\n            }\n        })\n        volume_mounts.append({\n            'name': pvc,\n            'mountPath': '/mnt/' + pvc\n        })\n\ngcp_secret_name = os.environ.get('GCP_SECRET_NAME')\nif gcp_secret_name:\n    volumes.append({\n      'name': gcp_secret_name,\n      'secret': {\n        'secretName': gcp_secret_name,\n      }\n    })\n    volume_mounts.append({\n        'name': gcp_secret_name,\n        'mountPath': SERVICE_ACCOUNT_SECRET_MOUNT\n    })\n",
    },
    kind: 'ConfigMap',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'jupyterhub-config',
      },
      name: 'jupyterhub-config',
      namespace: 'kf-100-user',
    },
  },
  {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
        'prometheus.io/scrape': 'true',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'jupyterhub-0',
      },
      name: 'jupyterhub-0',
      namespace: 'kf-100-user',
    },
    spec: {
      clusterIP: 'None',
      ports: [
        {
          name: 'hub',
          port: 8000,
        },
      ],
      selector: {
        app: 'jupyterhub',
      },
    },
  },
  {
    apiVersion: 'apps/v1beta1',
    kind: 'StatefulSet',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'jupyterhub',
      },
      name: 'jupyterhub',
      namespace: 'kf-100-user',
    },
    spec: {
      replicas: 1,
      serviceName: '',
      template: {
        metadata: {
          labels: {
            app: 'jupyterhub',
          },
        },
        spec: {
          containers: [
            {
              command: [
                'jupyterhub',
                '-f',
                '/etc/config/jupyterhub_config.py',
              ],
              env: [
                {
                  name: 'NOTEBOOK_PVC_MOUNT',
                  value: '/home/jovyan',
                },
                {
                  name: 'CLOUD_NAME',
                  value: 'null',
                },
                {
                  name: 'REGISTRY',
                  value: 'gcr.io',
                },
                {
                  name: 'REPO_NAME',
                  value: 'kubeflow-images-public',
                },
                {
                  name: 'KF_AUTHENTICATOR',
                  value: 'null',
                },
                {
                  name: 'DEFAULT_JUPYTERLAB',
                  value: 'false',
                },
                {
                  name: 'KF_PVC_LIST',
                  value: 'null',
                },
              ],
              image: 'gcr.io/kubeflow/jupyterhub-k8s:v20180531-3bb991b1',
              name: 'jupyterhub',
              ports: [
                {
                  containerPort: 8000,
                },
                {
                  containerPort: 8081,
                },
              ],
              volumeMounts: [
                {
                  mountPath: '/etc/config',
                  name: 'config-volume',
                },
              ],
            },
          ],
          serviceAccountName: 'jupyterhub',
          volumes: [
            {
              configMap: {
                name: 'jupyterhub-config',
              },
              name: 'config-volume',
            },
          ],
        },
      },
      updateStrategy: {
        type: 'RollingUpdate',
      },
    },
  },
  {
    apiVersion: 'rbac.authorization.k8s.io/v1beta1',
    kind: 'Role',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'jupyter-role',
      },
      name: 'jupyter-role',
      namespace: 'kf-100-user',
    },
    rules: [
      {
        apiGroups: [
          '',
        ],
        resources: [
          'pods',
          'persistentvolumeclaims',
        ],
        verbs: [
          'get',
          'watch',
          'list',
          'create',
          'delete',
        ],
      },
      {
        apiGroups: [
          '',
        ],
        resources: [
          'events',
        ],
        verbs: [
          'get',
          'watch',
          'list',
        ],
      },
    ],
  },
  {
    apiVersion: 'rbac.authorization.k8s.io/v1beta1',
    kind: 'Role',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'jupyter-notebook-role',
      },
      name: 'jupyter-notebook-role',
      namespace: 'kf-100-user',
    },
    rules: [
      {
        apiGroups: [
          '',
        ],
        resources: [
          'pods',
          'services',
        ],
        verbs: [
          '*',
        ],
      },
      {
        apiGroups: [
          '',
          'apps',
          'extensions',
        ],
        resources: [
          'deployments',
          'replicasets',
        ],
        verbs: [
          '*',
        ],
      },
      {
        apiGroups: [
          'kubeflow.org',
        ],
        resources: [
          '*',
        ],
        verbs: [
          '*',
        ],
      },
      {
        apiGroups: [
          'batch',
        ],
        resources: [
          'jobs',
        ],
        verbs: [
          '*',
        ],
      },
    ],
  },
  {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      annotations: {
        'getambassador.io/config': '---\napiVersion: ambassador/v0\nkind:  Mapping\nname: jupyterhub-lb-hub-mapping\nprefix: /hub/\nrewrite: /hub/\ntimeout_ms: 300000\nservice: jupyterhub-lb.kf-100-user\nuse_websocket: true\n---\napiVersion: ambassador/v0\nkind:  Mapping\nname: jupyterhub-lb-user-mapping\nprefix: /user/\nrewrite: /user/\ntimeout_ms: 300000\nservice: jupyterhub-lb.kf-100-user\nuse_websocket: true',
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'jupyterhub-lb',
      },
      name: 'jupyterhub-lb',
      namespace: 'kf-100-user',
    },
    spec: {
      ports: [
        {
          name: 'hub',
          port: 80,
          targetPort: 8000,
        },
      ],
      selector: {
        app: 'jupyterhub',
      },
      type: 'ClusterIP',
    },
  },
  {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'jupyterhub',
      },
      name: 'jupyterhub',
      namespace: 'kf-100-user',
    },
  },
  {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'jupyter-notebook',
      },
      name: 'jupyter-notebook',
      namespace: 'kf-100-user',
    },
  },
  {
    apiVersion: 'rbac.authorization.k8s.io/v1beta1',
    kind: 'RoleBinding',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'jupyter-role',
      },
      name: 'jupyter-role',
      namespace: 'kf-100-user',
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'Role',
      name: 'jupyter-role',
    },
    subjects: [
      {
        kind: 'ServiceAccount',
        name: 'jupyterhub',
        namespace: 'kf-100-user',
      },
    ],
  },
  {
    apiVersion: 'rbac.authorization.k8s.io/v1beta1',
    kind: 'RoleBinding',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'jupyter-notebook-role',
      },
      name: 'jupyter-notebook-role',
      namespace: 'kf-100-user',
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'Role',
      name: 'jupyter-notebook-role',
    },
    subjects: [
      {
        kind: 'ServiceAccount',
        name: 'jupyter-notebook',
        namespace: 'kf-100-user',
      },
    ],
  },
  {
    apiVersion: 'extensions/v1beta1',
    kind: 'Deployment',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'centraldashboard',
      },
      name: 'centraldashboard',
      namespace: 'kf-100-user',
    },
    spec: {
      template: {
        metadata: {
          labels: {
            app: 'centraldashboard',
          },
        },
        spec: {
          containers: [
            {
              image: 'gcr.io/kubeflow-images-public/centraldashboard:v0.3.0',
              name: 'centraldashboard',
              ports: [
                {
                  containerPort: 8082,
                },
              ],
            },
          ],
          serviceAccountName: 'centraldashboard',
        },
      },
    },
  },
  {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      annotations: {
        'getambassador.io/config': '---\napiVersion: ambassador/v0\nkind:  Mapping\nname: centralui-mapping\nprefix: /\nrewrite: /\nservice: centraldashboard.kf-100-user',
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'centraldashboard',
      },
      name: 'centraldashboard',
      namespace: 'kf-100-user',
    },
    spec: {
      ports: [
        {
          port: 80,
          targetPort: 8082,
        },
      ],
      selector: {
        app: 'centraldashboard',
      },
      sessionAffinity: 'None',
      type: 'ClusterIP',
    },
  },
  {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'centraldashboard',
      },
      name: 'centraldashboard',
      namespace: 'kf-100-user',
    },
  },
  {
    apiVersion: 'rbac.authorization.k8s.io/v1beta1',
    kind: 'Role',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'centraldashboard',
      },
      name: 'centraldashboard',
      namespace: 'kf-100-user',
    },
    rules: [
      {
        apiGroups: [
          '',
        ],
        resources: [
          'pods',
          'pods/exec',
          'pods/log',
        ],
        verbs: [
          'get',
          'list',
          'watch',
        ],
      },
      {
        apiGroups: [
          '',
        ],
        resources: [
          'secrets',
        ],
        verbs: [
          'get',
        ],
      },
    ],
  },
  {
    apiVersion: 'rbac.authorization.k8s.io/v1beta1',
    kind: 'RoleBinding',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'centraldashboard',
      },
      name: 'centraldashboard',
      namespace: 'kf-100-user',
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'Role',
      name: 'centraldashboard',
    },
    subjects: [
      {
        kind: 'ServiceAccount',
        name: 'centraldashboard',
        namespace: 'kf-100-user',
      },
    ],
  },
  {
    apiVersion: 'apiextensions.k8s.io/v1beta1',
    kind: 'CustomResourceDefinition',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'tfjobs.kubeflow.org',
      },
      name: 'tfjobs.kubeflow.org',
    },
    spec: {
      group: 'kubeflow.org',
      names: {
        kind: 'TFJob',
        plural: 'tfjobs',
        singular: 'tfjob',
      },
      scope: 'Namespaced',
      validation: {
        openAPIV3Schema: {
          properties: {
            spec: {
              properties: {
                tfReplicaSpecs: {
                  properties: {
                    Chief: {
                      properties: {
                        replicas: {
                          maximum: 1,
                          minimum: 1,
                          type: 'integer',
                        },
                      },
                    },
                    PS: {
                      properties: {
                        replicas: {
                          minimum: 1,
                          type: 'integer',
                        },
                      },
                    },
                    Worker: {
                      properties: {
                        replicas: {
                          minimum: 1,
                          type: 'integer',
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      },
      version: 'v1alpha2',
    },
  },
  {
    apiVersion: 'extensions/v1beta1',
    kind: 'Deployment',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'tf-job-operator-v1alpha2',
      },
      name: 'tf-job-operator-v1alpha2',
      namespace: 'kf-100-user',
    },
    spec: {
      replicas: 1,
      template: {
        metadata: {
          labels: {
            name: 'tf-job-operator',
          },
        },
        spec: {
          containers: [
            {
              command: [
                '/opt/kubeflow/tf-operator.v2',
                '--alsologtostderr',
                '-v=1',
                '--namespace=kf-100-user',
              ],
              env: [
                {
                  name: 'MY_POD_NAMESPACE',
                  valueFrom: {
                    fieldRef: {
                      fieldPath: 'metadata.namespace',
                    },
                  },
                },
                {
                  name: 'MY_POD_NAME',
                  valueFrom: {
                    fieldRef: {
                      fieldPath: 'metadata.name',
                    },
                  },
                },
                {
                  name: 'KUBEFLOW_NAMESPACE',
                  valueFrom: {
                    fieldRef: {
                      fieldPath: 'metadata.namespace',
                    },
                  },
                },
              ],
              image: 'gcr.io/kubeflow-images-public/tf_operator:v0.3.0',
              name: 'tf-job-operator',
              volumeMounts: [
                {
                  mountPath: '/etc/config',
                  name: 'config-volume',
                },
              ],
            },
          ],
          serviceAccountName: 'tf-job-operator',
          volumes: [
            {
              configMap: {
                name: 'tf-job-operator-config',
              },
              name: 'config-volume',
            },
          ],
        },
      },
    },
  },
  {
    apiVersion: 'v1',
    data: {
      'controller_config_file.yaml': '{\n    "grpcServerFilePath": "/opt/mlkube/grpc_tensorflow_server/grpc_tensorflow_server.py"\n}',
    },
    kind: 'ConfigMap',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'tf-job-operator-config',
      },
      name: 'tf-job-operator-config',
      namespace: 'kf-100-user',
    },
  },
  {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'tf-job-operator',
      },
      name: 'tf-job-operator',
      namespace: 'kf-100-user',
    },
  },
  {
    apiVersion: 'rbac.authorization.k8s.io/v1beta1',
    kind: 'Role',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'tf-job-operator',
      },
      name: 'tf-job-operator',
      namespace: 'kf-100-user',
    },
    rules: [
      {
        apiGroups: [
          'tensorflow.org',
          'kubeflow.org',
        ],
        resources: [
          'tfjobs',
        ],
        verbs: [
          '*',
        ],
      },
      {
        apiGroups: [
          'apiextensions.k8s.io',
        ],
        resources: [
          'customresourcedefinitions',
        ],
        verbs: [
          '*',
        ],
      },
      {
        apiGroups: [
          'storage.k8s.io',
        ],
        resources: [
          'storageclasses',
        ],
        verbs: [
          '*',
        ],
      },
      {
        apiGroups: [
          'batch',
        ],
        resources: [
          'jobs',
        ],
        verbs: [
          '*',
        ],
      },
      {
        apiGroups: [
          '',
        ],
        resources: [
          'configmaps',
          'pods',
          'services',
          'endpoints',
          'persistentvolumeclaims',
          'events',
        ],
        verbs: [
          '*',
        ],
      },
      {
        apiGroups: [
          'apps',
          'extensions',
        ],
        resources: [
          'deployments',
        ],
        verbs: [
          '*',
        ],
      },
    ],
  },
  {
    apiVersion: 'rbac.authorization.k8s.io/v1beta1',
    kind: 'RoleBinding',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'tf-job-operator',
      },
      name: 'tf-job-operator',
      namespace: 'kf-100-user',
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'Role',
      name: 'tf-job-operator',
    },
    subjects: [
      {
        kind: 'ServiceAccount',
        name: 'tf-job-operator',
        namespace: 'kf-100-user',
      },
    ],
  },
  {
    apiVersion: 'v1',
    kind: 'Service',
    metadata: {
      annotations: {
        'getambassador.io/config': '---\napiVersion: ambassador/v0\nkind:  Mapping\nname: tfjobs-ui-mapping\nprefix: /tfjobs/\nrewrite: /tfjobs/\nservice: tf-job-dashboard.kf-100-user',
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'tf-job-dashboard',
      },
      name: 'tf-job-dashboard',
      namespace: 'kf-100-user',
    },
    spec: {
      ports: [
        {
          port: 80,
          targetPort: 8080,
        },
      ],
      selector: {
        name: 'tf-job-dashboard',
      },
      type: 'ClusterIP',
    },
  },
  {
    apiVersion: 'v1',
    kind: 'ServiceAccount',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'tf-job-dashboard',
      },
      name: 'tf-job-dashboard',
      namespace: 'kf-100-user',
    },
  },
  {
    apiVersion: 'extensions/v1beta1',
    kind: 'Deployment',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'tf-job-dashboard',
      },
      name: 'tf-job-dashboard',
      namespace: 'kf-100-user',
    },
    spec: {
      template: {
        metadata: {
          labels: {
            name: 'tf-job-dashboard',
          },
        },
        spec: {
          containers: [
            {
              command: [
                '/opt/tensorflow_k8s/dashboard/backend',
              ],
              env: [
                {
                  name: 'KUBEFLOW_NAMESPACE',
                  valueFrom: {
                    fieldRef: {
                      fieldPath: 'metadata.namespace',
                    },
                  },
                },
              ],
              image: 'gcr.io/kubeflow-images-public/tf_operator:v0.3.0',
              name: 'tf-job-dashboard',
              ports: [
                {
                  containerPort: 8080,
                },
              ],
            },
          ],
          serviceAccountName: 'tf-job-dashboard',
        },
      },
    },
  },
  {
    apiVersion: 'rbac.authorization.k8s.io/v1beta1',
    kind: 'Role',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'tf-job-dashboard',
      },
      name: 'tf-job-dashboard',
      namespace: 'kf-100-user',
    },
    rules: [
      {
        apiGroups: [
          'tensorflow.org',
          'kubeflow.org',
        ],
        resources: [
          'tfjobs',
        ],
        verbs: [
          '*',
        ],
      },
      {
        apiGroups: [
          'apiextensions.k8s.io',
        ],
        resources: [
          'customresourcedefinitions',
        ],
        verbs: [
          '*',
        ],
      },
      {
        apiGroups: [
          'storage.k8s.io',
        ],
        resources: [
          'storageclasses',
        ],
        verbs: [
          '*',
        ],
      },
      {
        apiGroups: [
          'batch',
        ],
        resources: [
          'jobs',
        ],
        verbs: [
          '*',
        ],
      },
      {
        apiGroups: [
          '',
        ],
        resources: [
          'configmaps',
          'pods',
          'services',
          'endpoints',
          'persistentvolumeclaims',
          'events',
          'pods/log',
          'namespaces',
        ],
        verbs: [
          '*',
        ],
      },
      {
        apiGroups: [
          'apps',
          'extensions',
        ],
        resources: [
          'deployments',
        ],
        verbs: [
          '*',
        ],
      },
    ],
  },
  {
    apiVersion: 'rbac.authorization.k8s.io/v1beta1',
    kind: 'RoleBinding',
    metadata: {
      annotations: {
        'kubernetes.io/application': 'kubeflow-app',
      },
      labels: {
        app: 'kubeflow-app',
        component: 'tf-job-dashboard',
      },
      name: 'tf-job-dashboard',
      namespace: 'kf-100-user',
    },
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'Role',
      name: 'tf-job-dashboard',
    },
    subjects: [
      {
        kind: 'ServiceAccount',
        name: 'tf-job-operator',
        namespace: 'kf-100-user',
      },
    ],
  },
],
          local filteredComponents = std.filter(validateResource, components),
          local validateResource(resource) = {
            return::
              if std.type(resource) == "object" &&
              std.objectHas(resource, 'kind') &&
              std.objectHas(resource, 'apiVersion') &&
              std.objectHas(resource, 'metadata') &&
              std.objectHas(resource.metadata, 'name') &&
              std.objectHas(resource.metadata, 'namespace') &&
              resource.metadata.namespace == request.parent.metadata.namespace then
                true
              else
                false
          }.return,
          local existingGroups(obj) =
            if std.type(obj) == "object" then
              [ obj[key] for key in std.objectFields(obj) ]
            else
              [],
          local existingResources(group) =
            if std.type(group) == "object" then
              [ group[key] for key in std.objectFields(group) ]
            else
              [],
          local continuation(resources) = {
            local existingResource(resource) = {
              local resourceExists(kindAndResource, name) = {
                return::
                  if std.objectHas(resources, kindAndResource) &&
                  std.objectHas(resources[kindAndResource], name) then
                    true
                  else
                    false,
              }.return,
              return::
                if validateResource(resource) then 
                  resourceExists(resource.kind + "." + resource.apiVersion, resource.metadata.name)
                else
                  false,
            }.return,
            return:: existingResource,
          }.return,
          local foundChildren = 
            std.filter(continuation(resources), 
              std.flattenArrays(std.map(existingResources, existingGroups(request.children)))),
          local comparator(a, b) = {
            return::
              if a.metadata.name == b.metadata.name then
                0
              else if a.metadata.name < b.metadata.name then
                -1
              else
                1,
          }.return,
          local missingChildren = {
            return::
              if std.type(filteredComponents) == "array" &&
              std.type(foundChildren) == "array" then
                util.setDiff(util.sort(filteredComponents, comparator), 
                  util.sort(foundChildren, comparator), comparator)
              else
                [],
          }.return,
          local initialized = {
            return::
              if std.objectHas(request.parent, "status") &&
                 std.objectHas(request.parent.status, "created") &&
                 request.parent.status.created == true then
                true
              else
                false,
          }.return,
          local desired =
            if std.length(foundChildren) == 0 then
              if initialized == false then
                components
              else
                []
            else
              foundChildren,
          local assemblyPhase = {
            return::
              if std.length(foundChildren) == std.length(filteredComponents) then
                "Success"
              else
                "Pending",
          }.return,
          local installedName(resource) = {
            return::
             util.lower(resource.kind) + "s" + "/" + resource.metadata.name,
          }.return,
          children: desired,
          status: {
            observedGeneration: '1',
            assemblyPhase: assemblyPhase,
            installed: std.map(installedName, foundChildren),
            ready: true,
            created: true,

            request_children: request.children,
            found_children_length: std.length(foundChildren),
            components_length: std.length(components),
            filtered_components_length: std.length(filteredComponents),
            missing_children_length: std.length(missingChildren),
            missing_children: missingChildren,
          },
        },
};
test.process(test.request)
